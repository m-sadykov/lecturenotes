import * as admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { openAIKey } from "./config";
import { createProcessingLogger } from "./logging";
import type { ResponsesAPIResponse, StudyPack } from "./types";
import { numberValue, openAIErrorMessage, stringValue } from "./utils";

/** Which part of a lecture's study pack to generate again. */
export type StudyItemsKind = "flashcards" | "quiz";

/** Regenerations allowed per lecture per UTC day, to keep OpenAI costs bounded. */
export const DAILY_REGENERATION_LIMIT = 5;

const PLANS_WITH_REGENERATION = new Set(["premium", "pro"]);

type Flashcard = StudyPack["flashcards"][number];
type QuizQuestion = StudyPack["quiz"][number];

/**
 * Replaces a ready lecture's flashcards or quiz with a freshly generated set.
 * Premium and Pro only, limited per lecture per day. Returns the new items so the
 * app can show them without waiting for the Firestore listener.
 */
export const regenerateStudyItems = onCall(
  {
    timeoutSeconds: 120,
    memory: "256MiB",
    secrets: [openAIKey],
  },
  async request => {
    const userId = request.auth?.uid;
    if (!userId) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const payload = (request.data ?? {}) as Record<string, unknown>;
    const lectureId = stringValue(payload.lectureId).trim();
    const kind = stringValue(payload.kind).trim();
    if (!lectureId) {
      throw new HttpsError("invalid-argument", "lectureId is required.");
    }
    if (kind !== "flashcards" && kind !== "quiz") {
      throw new HttpsError("invalid-argument", "kind must be flashcards or quiz.");
    }

    const lectureLog = createProcessingLogger({
      flow: "regenerate_study_items",
      lectureId,
      kind,
    });

    const firestore = admin.firestore();
    const userReference = firestore.collection("users").doc(userId);
    const lectureReference = userReference.collection("lectures").doc(lectureId);

    const userSnapshot = await userReference.get();
    const plan = stringValue(userSnapshot.data()?.plan);
    if (!PLANS_WITH_REGENERATION.has(plan)) {
      throw new HttpsError(
        "permission-denied",
        "Regenerating study items requires Premium or Pro.",
        { reason: "planRequired" },
      );
    }

    const day = new Date().toISOString().slice(0, 10);
    const reservation = await firestore.runTransaction(async transaction => {
      const snapshot = await transaction.get(lectureReference);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Lecture not found.");
      }

      const data = snapshot.data() ?? {};
      const transcript = stringValue(data.transcript).trim();
      if (stringValue(data.status) !== "ready" || !transcript) {
        throw new HttpsError(
          "failed-precondition",
          "The lecture must finish processing first.",
          { reason: "notReady" },
        );
      }

      const usedToday = regenerationsUsed(data.studyRegenerations, day);
      if (usedToday >= DAILY_REGENERATION_LIMIT) {
        throw new HttpsError(
          "resource-exhausted",
          "Daily regeneration limit reached for this lecture.",
          { reason: "dailyLimit", limit: DAILY_REGENERATION_LIMIT },
        );
      }

      transaction.set(
        lectureReference,
        { studyRegenerations: { day, count: usedToday + 1 } },
        { merge: true },
      );

      return {
        transcript,
        usedToday: usedToday + 1,
        existingQuestions: existingQuestions(data, kind),
      };
    });

    try {
      const apiKey = openAIKey.value();
      const items = kind === "flashcards"
        ? withIDs(await generateFlashcards(
          reservation.transcript,
          reservation.existingQuestions,
          apiKey,
        ))
        : withIDs(await generateQuiz(
          reservation.transcript,
          reservation.existingQuestions,
          apiKey,
        ));

      await lectureReference.set(
        {
          [kind]: items,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      lectureLog.info("Study items regenerated", {
        count: items.length,
        usedToday: reservation.usedToday,
      });

      return {
        kind,
        items,
        remainingToday: Math.max(DAILY_REGENERATION_LIMIT - reservation.usedToday, 0),
      };
    } catch (error) {
      lectureLog.error("Study items regeneration failed", error);
      await releaseReservation(lectureReference, day);
      throw new HttpsError("internal", "Unable to generate new study items.");
    }
  },
);

/** How many regenerations a lecture used on `day`; a stale day counts as zero. */
export function regenerationsUsed(value: unknown, day: string): number {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return 0;
  }

  const record = value as Record<string, unknown>;
  return stringValue(record.day) === day
    ? Math.max(numberValue(record.count), 0)
    : 0;
}

function existingQuestions(data: admin.firestore.DocumentData, kind: StudyItemsKind): string[] {
  const items = Array.isArray(data[kind]) ? data[kind] as unknown[] : [];
  return items
    .map(item => stringValue((item as Record<string, unknown> | null)?.question).trim())
    .filter(Boolean);
}

/** Gives back the slot taken for a request whose generation failed. */
async function releaseReservation(
  lectureReference: admin.firestore.DocumentReference,
  day: string,
): Promise<void> {
  try {
    await admin.firestore().runTransaction(async transaction => {
      const snapshot = await transaction.get(lectureReference);
      const usedToday = regenerationsUsed(snapshot.data()?.studyRegenerations, day);
      if (usedToday > 0) {
        transaction.set(
          lectureReference,
          { studyRegenerations: { day, count: usedToday - 1 } },
          { merge: true },
        );
      }
    });
  } catch {
    // The slot stays used; the limit resets the next day.
  }
}

function withIDs<Item extends object>(items: Item[]): Array<Item & { id: string }> {
  return items.map(item => ({ id: crypto.randomUUID(), ...item }));
}

function avoidList(questions: string[]): string {
  if (!questions.length) {
    return "";
  }

  return [
    "",
    "The learner has already seen these questions. Do not repeat or rephrase them;",
    "cover other facts, concepts and angles from the transcript instead:",
    ...questions.map(question => `- ${question}`),
  ].join("\n");
}

async function generateFlashcards(
  transcript: string,
  previousQuestions: string[],
  apiKey: string,
): Promise<Flashcard[]> {
  const content = await requestJSON(
    [
      "You create flashcards for studying lecture content.",
      "Write every card in the same language as the transcript.",
      "Return valid JSON only.",
      "flashcards: 10-12 question-answer pairs in plain text, each testing one idea.",
      avoidList(previousQuestions),
    ].join("\n"),
    transcript,
    "lecture_flashcards",
    {
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
    },
    apiKey,
  );

  const parsed = JSON.parse(content) as { flashcards?: Flashcard[] };
  const cards = (parsed.flashcards ?? [])
    .map(card => ({ question: card.question.trim(), answer: card.answer.trim() }))
    .filter(card => card.question && card.answer)
    .slice(0, 12);

  if (cards.length < 5) {
    throw new Error("Flashcard generation returned too few cards.");
  }

  return cards;
}

async function generateQuiz(
  transcript: string,
  previousQuestions: string[],
  apiKey: string,
): Promise<QuizQuestion[]> {
  const content = await requestJSON(
    [
      "You create a multiple-choice quiz for studying lecture content.",
      "Write every question and option in the same language as the transcript.",
      "Return valid JSON only.",
      "quiz: 10-12 questions, each with exactly 4 plain-text options and one correct answer.",
      "Vary the position of the correct option.",
      avoidList(previousQuestions),
    ].join("\n"),
    transcript,
    "lecture_quiz",
    {
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
            correctIndex: { type: "integer", minimum: 0, maximum: 3 },
          },
          required: ["question", "options", "correctIndex"],
        },
      },
    },
    apiKey,
  );

  const parsed = JSON.parse(content) as { quiz?: QuizQuestion[] };
  const questions = (parsed.quiz ?? [])
    .map(question => ({
      question: question.question.trim(),
      options: question.options.map(option => option.trim()).filter(Boolean).slice(0, 4),
      correctIndex: Math.min(Math.max(question.correctIndex, 0), 3),
    }))
    .filter(question => question.question && question.options.length === 4)
    .slice(0, 12);

  if (questions.length < 5) {
    throw new Error("Quiz generation returned too few questions.");
  }

  return questions;
}

async function requestJSON(
  instructions: string,
  transcript: string,
  schemaName: string,
  properties: Record<string, unknown>,
  apiKey: string,
): Promise<string> {
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4.1-mini",
      instructions,
      input: `Transcript:\n${transcript}`,
      text: {
        format: {
          type: "json_schema",
          name: schemaName,
          strict: true,
          schema: {
            type: "object",
            additionalProperties: false,
            properties,
            required: Object.keys(properties),
          },
        },
      },
    }),
  });

  if (!response.ok) {
    throw new Error(await openAIErrorMessage(response));
  }

  const payload = (await response.json()) as ResponsesAPIResponse;
  const text = payload.output_text?.trim()
    ? payload.output_text
    : payload.output
      ?.flatMap(item => item.content ?? [])
      .find(content => content.type === "output_text" && typeof content.text === "string")
      ?.text;

  if (!text) {
    throw new Error("Study items generation returned no content.");
  }

  return text;
}
