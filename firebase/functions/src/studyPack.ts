import * as admin from "firebase-admin";

import type { ResponsesAPIResponse, StudyPack } from "./types";
import { openAIErrorMessage } from "./utils";

export async function saveStudyPack(
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
      summaryNote: studyPack.summaryNote,
      keyPoints: studyPack.keyPoints,
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

// summaryNote and keyPoints are Markdown rendered by the iOS app (1.4+), which supports
// headings (#, ##, ###), bullet and numbered lists (nested with two spaces),
// horizontal rules (---), **bold** and *italic*. Keep the prompt within that subset.
// summaryLong stays plain text because app versions before 1.4 display it verbatim.
const STUDY_PACK_INSTRUCTIONS = [
  "You create study materials for lecture content.",
  "Write every field in the same language as the transcript.",
  "Return valid JSON only.",
  "",
  "title: a short, specific title for the lecture.",
  "summaryShort: one or two plain-text sentences without Markdown.",
  "summaryLong: a detailed summary of one to three paragraphs in plain text. Do not use any Markdown symbols (#, *, -, ---); separate paragraphs with a blank line.",
  "",
  "summaryNote: a well-structured study note in Markdown:",
  "- Start with a level-1 heading (#) with the lecture title.",
  "- Then a horizontal rule (---).",
  "- Then an introduction of 2-4 sentences explaining what the lecture covers and its main argument.",
  "- Then 3-6 sections, each starting with a level-2 heading (##).",
  "- Inside sections use bullet lists; nest supporting details under a bullet with two spaces of indentation.",
  "- Put **bold** on key terms, names, dates and definitions, a few per section, not whole sentences.",
  "- Do not use tables, code blocks, links or images.",
  "",
  "keyPoints: the most important takeaways in Markdown:",
  "- Group them under 2-4 level-2 headings (##).",
  "- Each takeaway is one bullet that starts with a short **bold label:** followed by one or two sentences.",
  "- 6-12 bullets in total.",
  "",
  "flashcards: at least 10 question-answer pairs in plain text.",
  "quiz: at least 10 multiple-choice questions with exactly 4 plain-text options.",
].join("\n");

export async function generateStudyPack(
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
      instructions: STUDY_PACK_INSTRUCTIONS,
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
              summaryNote: { type: "string" },
              keyPoints: { type: "string" },
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
              "summaryNote",
              "keyPoints",
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
    summaryNote: studyPack.summaryNote?.trim() ?? "",
    keyPoints: studyPack.keyPoints?.trim() ?? "",
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
      question: "Which statement best matches the lecture content?",
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
