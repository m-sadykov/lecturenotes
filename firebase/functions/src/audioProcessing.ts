import * as admin from "firebase-admin";

import { numberValue, stringMapValue } from "./utils";

export const singleLectureAudioPath =
  /^audio\/([^/]+)\/([^/.]+)\.(m4a|mp3|wav|mpeg|mp4)$/i;
export const chunkLectureAudioPath = /^audio\/([^/]+)\/([^/]+)\/chunk_(\d+)\.m4a$/i;

export function parseAudioObject(filePath: string):
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

export async function mergeChunkTranscript({
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
