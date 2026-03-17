/* eslint-disable quotes */
import { tmpdir } from "node:os";
import { basename, join } from "node:path";
import { readFile, unlink } from "node:fs/promises";

import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import * as logger from "firebase-functions/logger";
import { defineSecret } from "firebase-functions/params";
import { onObjectFinalized } from "firebase-functions/v2/storage";

admin.initializeApp();

setGlobalOptions({ maxInstances: 10 });

const openAIKey = defineSecret("OPENAI_API_KEY");
const singleLectureAudioPath = /^audio\/([^/]+)\/([^/.]+)\.(m4a|mp3|wav|mpeg|mp4)$/i;
const chunkLectureAudioPath = /^audio\/([^/]+)\/([^/]+)\/chunk_(\d+)\.m4a$/i;

type TranscriptResponse = {
  text: string;
  language?: string;
};

type StudyPack = {
  title: string;
  summaryShort: string;
  summaryLong: string;
  flashcards: Array<{
    question: string;
    answer: string;
  }>;
  quiz: Array<{
    question: string;
    options: string[];
    correctIndex: number;
  }>;
};

export const processLectureAudio = onObjectFinalized(
  {
    secrets: [openAIKey],
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async event => {
    const object = event.data;
    const filePath = object.name;
    const bucketName = object.bucket;

    if (!filePath || !bucketName) {
      logger.warn("Missing file path or bucket in finalize event", { event });
      return;
    }

    const audioObject = parseAudioObject(filePath);
    if (!audioObject) {
      logger.info("Skipping unrelated storage object", { filePath });
      return;
    }

    const { uid, lectureId } = audioObject;
    const documentReference = admin
      .firestore()
      .collection("users")
      .doc(uid)
      .collection("lectures")
      .doc(lectureId);

    const tempFilePath = join(tmpdir(), basename(filePath));

    try {
      await documentReference.set(
        {
          status: "transcribing",
          errorMessage: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      await admin.storage().bucket(bucketName).file(filePath).download({
        destination: tempFilePath,
      });

      const transcript = await transcribeLecture(tempFilePath, openAIKey.value());

      if (audioObject.kind === "chunk") {
        const mergeResult = await mergeChunkTranscript({
          documentReference,
          chunkIndex: audioObject.chunkIndex,
          transcript: transcript.text,
          language: transcript.language ?? null,
        });

        if (!mergeResult.shouldGenerateStudyPack) {
          logger.info("Chunk transcript saved", {
            uid,
            lectureId,
            chunkIndex: audioObject.chunkIndex,
            completedChunkCount: mergeResult.completedChunkCount,
          });
          return;
        }

        const studyPack = await generateStudyPack(
          mergeResult.mergedTranscript,
          openAIKey.value(),
        );

        await saveStudyPack(documentReference, mergeResult.mergedTranscript, studyPack);
      } else {
        await documentReference.set(
          {
            status: "generating",
            transcript: transcript.text,
            languageDetected: transcript.language ?? null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        const studyPack = await generateStudyPack(
          transcript.text,
          openAIKey.value(),
        );

        await saveStudyPack(documentReference, transcript.text, studyPack);
      }

      logger.info("Lecture processed successfully", { uid, lectureId });
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Unknown processing error";

      logger.error("Lecture processing failed", { uid, lectureId, message });

      await documentReference.set(
        {
          status: "failed",
          errorMessage: message,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    } finally {
      try {
        await unlink(tempFilePath);
      } catch {
        logger.debug("Temporary file cleanup skipped", { tempFilePath });
      }
    }
  },
);

function parseAudioObject(filePath: string):
  | { kind: "single"; uid: string; lectureId: string }
  | { kind: "chunk"; uid: string; lectureId: string; chunkIndex: number }
  | null {
  const chunkMatch = filePath.match(chunkLectureAudioPath);
  if (chunkMatch) {
    return {
      kind: "chunk",
      uid: chunkMatch[1],
      lectureId: chunkMatch[2],
      chunkIndex: Number(chunkMatch[3]),
    };
  }

  const singleMatch = filePath.match(singleLectureAudioPath);
  if (singleMatch) {
    return {
      kind: "single",
      uid: singleMatch[1],
      lectureId: singleMatch[2],
    };
  }

  return null;
}

async function transcribeLecture(
  filePath: string,
  apiKey: string,
): Promise<TranscriptResponse> {
  const audioBytes = await readFile(filePath);
  const mimeType = mimeTypeForAudioFile(filePath);
  const fileName = basename(filePath);
  return createTranscription({
    audioBytes,
    mimeType,
    fileName,
    apiKey,
    model: "gpt-4o-mini-transcribe",
  });
}

async function createTranscription({
  audioBytes,
  mimeType,
  fileName,
  apiKey,
  model,
}: {
  audioBytes: Buffer;
  mimeType: string;
  fileName: string;
  apiKey: string;
  model: string;
}): Promise<TranscriptResponse> {
  const formData = new FormData();
  const audioBlob = new Blob([new Uint8Array(audioBytes)], { type: mimeType });

  formData.append("file", audioBlob, fileName);
  formData.append("model", model);
  formData.append("response_format", "json");

  const response = await fetch("https://api.openai.com/v1/audio/transcriptions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
    },
    body: formData,
  });

  if (!response.ok) {
    throw new Error(await openAIErrorMessage(response));
  }

  const payload = (await response.json()) as TranscriptResponse;

  if (!payload.text?.trim()) {
    throw new Error("Transcription returned empty text.");
  }

  return payload;
}

function mimeTypeForAudioFile(filePath: string): string {
  const fileName = basename(filePath).toLowerCase();

  if (fileName.endsWith(".mp3") || fileName.endsWith(".mpeg")) {
    return "audio/mpeg";
  }

  if (fileName.endsWith(".wav")) {
    return "audio/wav";
  }

  if (fileName.endsWith(".mp4") || fileName.endsWith(".m4a")) {
    return "audio/mp4";
  }

  return "application/octet-stream";
}

async function mergeChunkTranscript({
  documentReference,
  chunkIndex,
  transcript,
  language,
}: {
  documentReference: admin.firestore.DocumentReference;
  chunkIndex: number;
  transcript: string;
  language: string | null;
}): Promise<{
  completedChunkCount: number;
  mergedTranscript: string;
  shouldGenerateStudyPack: boolean;
}> {
  return admin.firestore().runTransaction(async transaction => {
    const snapshot = await transaction.get(documentReference);
    const data = snapshot.data() ?? {};
    const chunkCount = numberValue(data.chunkCount);
    const existingChunkTranscripts = stringMapValue(data.chunkTranscripts);
    const chunkKey = String(chunkIndex);

    existingChunkTranscripts[chunkKey] = transcript;

    const sortedChunkIndexes = Object.keys(existingChunkTranscripts)
      .map(value => Number(value))
      .filter(value => Number.isFinite(value))
      .sort((lhs, rhs) => lhs - rhs);

    const mergedTranscript = sortedChunkIndexes
      .map(index => existingChunkTranscripts[String(index)] ?? "")
      .filter(value => value.trim().length > 0)
      .join("\n\n")
      .trim();

    const completedChunkCount = sortedChunkIndexes.length;
    const shouldGenerateStudyPack =
      chunkCount > 0 &&
      completedChunkCount >= chunkCount &&
      data.status !== "generating" &&
      data.status !== "ready";

    transaction.set(
      documentReference,
      {
        status: shouldGenerateStudyPack ? "generating" : "transcribing",
        transcript: mergedTranscript,
        languageDetected: language ?? data.languageDetected ?? null,
        chunkTranscripts: existingChunkTranscripts,
        completedChunkCount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        errorMessage: admin.firestore.FieldValue.delete(),
      },
      { merge: true },
    );

    return {
      completedChunkCount,
      mergedTranscript,
      shouldGenerateStudyPack,
    };
  });
}

async function saveStudyPack(
  documentReference: admin.firestore.DocumentReference,
  transcript: string,
  studyPack: StudyPack,
): Promise<void> {
  await documentReference.set(
    {
      status: "ready",
      transcript,
      title: studyPack.title,
      summaryShort: studyPack.summaryShort,
      summaryLong: studyPack.summaryLong,
      flashcards: studyPack.flashcards.map(card => ({
        id: crypto.randomUUID(),
        question: card.question,
        answer: card.answer,
      })),
      quiz: studyPack.quiz.map(question => ({
        id: crypto.randomUUID(),
        question: question.question,
        options: question.options,
        correctIndex: question.correctIndex,
      })),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      errorMessage: admin.firestore.FieldValue.delete(),
    },
    { merge: true },
  );
}

function numberValue(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }

  return 0;
}

function stringMapValue(value: unknown): Record<string, string> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }

  const entries = Object.entries(value as Record<string, unknown>)
    .filter(([, entryValue]) => typeof entryValue === "string")
    .map(([entryKey, entryValue]) => [entryKey, entryValue as string]);

  return Object.fromEntries(entries);
}

async function generateStudyPack(
  transcript: string,
  apiKey: string,
): Promise<StudyPack> {
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4.1-mini",
      instructions:
        "You create concise study materials for lecture recordings. " +
        "Return valid JSON only with a helpful title, a short summary, a detailed summary, at least 10 flashcards, and at least 10 quiz questions.",
      input: `Transcript:\n${transcript}`,
      text: {
        format: {
          type: "json_schema",
          name: "lecture_study_pack",
          strict: true,
          schema: {
            type: "object",
            additionalProperties: false,
            properties: {
              title: { type: "string" },
              summaryShort: { type: "string" },
              summaryLong: { type: "string" },
              flashcards: {
                type: "array",
                minItems: 10,
                items: {
                  type: "object",
                  additionalProperties: false,
                  properties: {
                    question: { type: "string" },
                    answer: { type: "string" },
                  },
                  required: ["question", "answer"],
                },
              },
              quiz: {
                type: "array",
                minItems: 10,
                items: {
                  type: "object",
                  additionalProperties: false,
                  properties: {
                    question: { type: "string" },
                    options: {
                      type: "array",
                      minItems: 4,
                      maxItems: 4,
                      items: { type: "string" },
                    },
                    correctIndex: {
                      type: "integer",
                      minimum: 0,
                      maximum: 3,
                    },
                  },
                  required: ["question", "options", "correctIndex"],
                },
              },
            },
            required: [
              "title",
              "summaryShort",
              "summaryLong",
              "flashcards",
              "quiz",
            ],
          },
        },
      },
    }),
  });

  if (!response.ok) {
    throw new Error(await openAIErrorMessage(response));
  }

  const payload = (await response.json()) as ResponsesAPIResponse;
  const content = extractResponseText(payload);
  if (!content) {
    throw new Error("Study pack generation returned no content.");
  }

  const parsed = JSON.parse(content) as StudyPack;
  return normalizeStudyPack(parsed, transcript);
}

type ResponsesAPIResponse = {
  output?: Array<{
    content?: Array<{
      type?: string;
      text?: string;
    }>;
  }>;
  output_text?: string;
};

function extractResponseText(payload: ResponsesAPIResponse): string | null {
  if (typeof payload.output_text === "string" && payload.output_text.trim()) {
    return payload.output_text;
  }

  for (const item of payload.output ?? []) {
    for (const content of item.content ?? []) {
      if (content.type === "output_text" && typeof content.text === "string") {
        return content.text;
      }
    }
  }

  return null;
}

function normalizeStudyPack(
  studyPack: StudyPack,
  transcript: string,
): StudyPack {
  const cleanedFlashcards = studyPack.flashcards
    .map(card => ({
      question: card.question.trim(),
      answer: card.answer.trim(),
    }))
    .filter(card => card.question && card.answer);

  const cleanedQuiz = studyPack.quiz
    .map(question => ({
      question: question.question.trim(),
      options: question.options
        .map(option => option.trim())
        .filter(Boolean)
        .slice(0, 4),
      correctIndex: Math.min(Math.max(question.correctIndex, 0), 3),
    }))
    .filter(question => question.question && question.options.length === 4);

  return {
    title: studyPack.title.trim() || fallbackTitle(transcript),
    summaryShort:
      studyPack.summaryShort.trim() || fallbackSummary(transcript, 180),
    summaryLong:
      studyPack.summaryLong.trim() || fallbackSummary(transcript, 600),
    flashcards: ensureMinimumFlashcards(cleanedFlashcards, transcript),
    quiz: ensureMinimumQuiz(cleanedQuiz, transcript),
  };
}

function ensureMinimumFlashcards(
  flashcards: StudyPack["flashcards"],
  transcript: string,
): StudyPack["flashcards"] {
  const items = [...flashcards];

  while (items.length < 10) {
    items.push({
      question: `Key idea ${items.length + 1}`,
      answer: fallbackSummary(transcript, 120),
    });
  }

  return items.slice(0, 12);
}

function ensureMinimumQuiz(
  quiz: StudyPack["quiz"],
  transcript: string,
): StudyPack["quiz"] {
  const items = [...quiz];

  while (items.length < 10) {
    const summary = fallbackSummary(transcript, 120);
    items.push({
      question: `Which statement best matches the lecture content?`,
      options: [
        summary,
        "The lecture focused on an unrelated topic.",
        "No practical concepts were discussed.",
        "The speaker provided no key takeaways.",
      ],
      correctIndex: 0,
    });
  }

  return items.slice(0, 12);
}

function fallbackTitle(transcript: string): string {
  const trimmed = transcript.trim();
  if (!trimmed) {
    return "New Recording";
  }

  return trimmed.split(/\s+/).slice(0, 6).join(" ");
}

function fallbackSummary(transcript: string, maxLength: number): string {
  const trimmed = transcript.trim();
  if (!trimmed) {
    return "Summary is unavailable.";
  }

  return trimmed.length > maxLength
    ? `${trimmed.slice(0, maxLength).trimEnd()}...`
    : trimmed;
}

async function openAIErrorMessage(response: Response): Promise<string> {
  try {
    const payload = (await response.json()) as {
      error?: {
        message?: string;
      };
    };
    return (
      payload.error?.message ?? `OpenAI request failed with ${response.status}`
    );
  } catch {
    return `OpenAI request failed with ${response.status}`;
  }
}
