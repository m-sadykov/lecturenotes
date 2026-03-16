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
const lectureAudioPath = /^audio\/([^/]+)\/([^/.]+)\.(m4a|mp3|wav|mpeg|mp4)$/i;

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

    const match = filePath.match(lectureAudioPath);
    if (!match) {
      logger.info("Skipping unrelated storage object", { filePath });
      return;
    }

    const [, uid, lectureId] = match;
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

      const transcript = await transcribeLecture(
        tempFilePath,
        openAIKey.value(),
      );

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

      await documentReference.set(
        {
          status: "ready",
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

async function transcribeLecture(
  filePath: string,
  apiKey: string,
): Promise<TranscriptResponse> {
  const audioBytes = await readFile(filePath);
  const formData = new FormData();
  const audioBlob = new Blob([audioBytes], { type: "audio/m4a" });

  formData.append("file", audioBlob, basename(filePath));
  formData.append("model", "gpt-4o-mini-transcribe");
  formData.append("response_format", "json");

  const response = await fetch(
    "https://api.openai.com/v1/audio/transcriptions",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
      },
      body: formData,
    },
  );

  if (!response.ok) {
    throw new Error(await openAIErrorMessage(response));
  }

  const payload = (await response.json()) as TranscriptResponse;

  if (!payload.text?.trim()) {
    throw new Error("Transcription returned empty text.");
  }

  return payload;
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
        "Return valid JSON only with a helpful title, a short summary, a detailed summary, at least 10 flashcards, and at least 5 quiz questions.",
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
                minItems: 5,
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

  while (items.length < 5) {
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

  return items.slice(0, 8);
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
