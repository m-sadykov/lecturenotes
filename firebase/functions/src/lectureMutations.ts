import * as admin from "firebase-admin";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { createProcessingLogger } from "./logging";
import { numberValue, stringValue } from "./utils";

type LectureSourceType = "audio" | "text" | "pdf" | "youtube";

type AudioUploadPayload = {
  isChunked: boolean;
  chunkPaths: string[];
  primaryAudioPath: string | null;
};

function isLectureSourceType(value: string): value is LectureSourceType {
  return ["audio", "text", "pdf", "youtube"].includes(value);
}

function objectValue(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }

  return value as Record<string, unknown>;
}

function nullableStringValue(value: unknown): string | null {
  if (value === null) {
    return null;
  }

  const stringified = stringValue(value).trim();
  return stringified || null;
}

function stringArrayValue(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map(item => stringValue(item).trim())
    .filter(Boolean);
}

function requireUserId(request: { auth?: { uid?: string } | null }): string {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  return userId;
}

function lectureDocumentReference(
  userId: string,
  lectureId: string,
): admin.firestore.DocumentReference {
  return admin
    .firestore()
    .collection("users")
    .doc(userId)
    .collection("lectures")
    .doc(lectureId);
}

async function loadUserConstraints(userId: string): Promise<{
  remainingCount: number;
  isUnlimited: boolean;
  audioImportLimitSec: number;
}> {
  const snapshot = await admin.firestore().collection("users").doc(userId).get();
  const data = snapshot.data() ?? {};

  return {
    remainingCount: Math.max(numberValue(data.processingLimitRemainingCount), 0),
    isUnlimited: Boolean(data.processingLimitIsUnlimited),
    audioImportLimitSec: Math.max(numberValue(data.audioImportLimitSec), 5 * 60),
  };
}

function validatedAudioUploadPayload(value: unknown): AudioUploadPayload {
  const payload = objectValue(value);
  const chunkPaths = stringArrayValue(payload.chunkPaths);
  const isChunked = Boolean(payload.isChunked);
  const primaryAudioPath = nullableStringValue(payload.primaryAudioPath);

  if (!chunkPaths.length) {
    throw new HttpsError(
      "invalid-argument",
      "Audio upload payload must include at least one storage path.",
    );
  }

  return {
    isChunked,
    chunkPaths,
    primaryAudioPath,
  };
}

export const upsertLecture = onCall(
  {
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async request => {
    const userId = requireUserId(request);
    const payload = objectValue(request.data);
    const lectureId = stringValue(payload.lectureId).trim();
    const sourceType = stringValue(payload.sourceType).trim();
    const title = stringValue(payload.title).trim();
    const transcript = stringValue(payload.transcript).trim();
    const durationSec = Math.max(numberValue(payload.durationSec), 0);
    const sourceURL = nullableStringValue(payload.sourceURL);
    const youtubeVideoID = nullableStringValue(payload.youtubeVideoID);
    const folderID = nullableStringValue(payload.folderID);

    if (!lectureId) {
      throw new HttpsError("invalid-argument", "lectureId is required.");
    }

    if (!isLectureSourceType(sourceType)) {
      throw new HttpsError("invalid-argument", "sourceType is invalid.");
    }

    if (!title) {
      throw new HttpsError("invalid-argument", "title is required.");
    }

    if ((sourceType === "text" || sourceType === "pdf") && !transcript) {
      throw new HttpsError(
        "invalid-argument",
        "Imported text lectures must include transcript text.",
      );
    }

    if (sourceType === "youtube" && !sourceURL && !youtubeVideoID) {
      throw new HttpsError(
        "invalid-argument",
        "YouTube lectures must include sourceURL or youtubeVideoID.",
      );
    }

    const documentReference = lectureDocumentReference(userId, lectureId);
    const snapshot = await documentReference.get();
    const log = createProcessingLogger({
      functionName: "upsertLecture",
      uid: userId,
      lectureId,
      sourceType,
      existingLecture: snapshot.exists,
    });

    if (!snapshot.exists) {
      const data: admin.firestore.UpdateData = {
        id: lectureId,
        title,
        sourceType,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        durationSec,
        status: "draft",
        transcript: sourceType === "text" || sourceType === "pdf" ? transcript : "",
        summaryShort: "",
        summaryLong: "",
        flashcards: [],
        quiz: [],
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (sourceURL) {
        data.sourceURL = sourceURL;
      }

      if (youtubeVideoID) {
        data.youtubeVideoID = youtubeVideoID;
      }

      if (folderID) {
        data.folderID = folderID;
      }

      await documentReference.set(data, { merge: true });
      log.info("Lecture created from callable");
      return { lectureId };
    }

    const update: admin.firestore.UpdateData = {
      title,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (folderID) {
      update.folderID = folderID;
    } else {
      update.folderID = admin.firestore.FieldValue.delete();
    }

    await documentReference.set(update, { merge: true });
    log.info("Lecture metadata updated from callable");
    return { lectureId };
  },
);

export const startLectureProcessing = onCall(
  {
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async request => {
    const userId = requireUserId(request);
    const payload = objectValue(request.data);
    const lectureId = stringValue(payload.lectureId).trim();

    if (!lectureId) {
      throw new HttpsError("invalid-argument", "lectureId is required.");
    }

    const documentReference = lectureDocumentReference(userId, lectureId);
    const snapshot = await documentReference.get();
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Lecture document is unavailable.");
    }

    const lecture = snapshot.data() ?? {};
    const sourceType = stringValue(lecture.sourceType);
    const transcript = stringValue(lecture.transcript).trim();
    const sourceURL = stringValue(lecture.sourceURL).trim();
    const durationSec = Math.max(numberValue(lecture.durationSec), 0);

    if (!isLectureSourceType(sourceType)) {
      throw new HttpsError("failed-precondition", "Lecture sourceType is invalid.");
    }

    const constraints = await loadUserConstraints(userId);
    if (!constraints.isUnlimited && constraints.remainingCount < 1) {
      throw new HttpsError(
        "resource-exhausted",
        `Not enough processing attempts left. Remaining: ${constraints.remainingCount}.`,
      );
    }

    if (sourceType === "audio" && durationSec > constraints.audioImportLimitSec) {
      throw new HttpsError(
        "failed-precondition",
        "Audio exceeds the current plan limit.",
      );
    }

    const baseUpdate: admin.firestore.UpdateData = {
      summaryShort: "",
      summaryLong: "",
      flashcards: [],
      quiz: [],
      errorMessage: admin.firestore.FieldValue.delete(),
      processingErrorCode: admin.firestore.FieldValue.delete(),
      processedAt: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      processingStartedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (sourceType === "audio") {
      const audioUpload = validatedAudioUploadPayload(payload.audioUpload);
      await documentReference.set(
        {
          ...baseUpdate,
          status: "uploading",
          transcript: "",
          isChunked: audioUpload.isChunked,
          chunkCount: audioUpload.chunkPaths.length,
          chunkPaths: audioUpload.chunkPaths,
          chunkTranscripts: {},
          audioPath:
            audioUpload.primaryAudioPath ??
            audioUpload.chunkPaths[0] ??
            admin.firestore.FieldValue.delete(),
        },
        { merge: true },
      );
      return { lectureId, status: "uploading" };
    }

    if ((sourceType === "text" || sourceType === "pdf") && !transcript) {
      throw new HttpsError(
        "failed-precondition",
        "Imported content is empty.",
      );
    }

    if (sourceType === "youtube" && !sourceURL) {
      throw new HttpsError(
        "failed-precondition",
        "Source URL is unavailable.",
      );
    }

    const nextStatus = sourceType === "youtube" ? "transcribing" : "generating";
    await documentReference.set(
      {
        ...baseUpdate,
        status: nextStatus,
      },
      { merge: true },
    );

    return { lectureId, status: nextStatus };
  },
);

export const markLectureFailed = onCall(
  {
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async request => {
    const userId = requireUserId(request);
    const payload = objectValue(request.data);
    const lectureId = stringValue(payload.lectureId).trim();
    const message =
      nullableStringValue(payload.message) ?? "Unknown processing error.";

    if (!lectureId) {
      throw new HttpsError("invalid-argument", "lectureId is required.");
    }

    await lectureDocumentReference(userId, lectureId).set(
      {
        status: "failed",
        errorMessage: message,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { lectureId, status: "failed" };
  },
);

export const deleteLectureCascade = onCall(
  {
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async request => {
    const userId = requireUserId(request);
    const payload = objectValue(request.data);
    const lectureId = stringValue(payload.lectureId).trim();

    if (!lectureId) {
      throw new HttpsError("invalid-argument", "lectureId is required.");
    }

    const documentReference = lectureDocumentReference(userId, lectureId);
    const snapshot = await documentReference.get();
    if (!snapshot.exists) {
      return { lectureId, deleted: true };
    }

    const data = snapshot.data() ?? {};
    const storagePaths = new Set<string>();

    for (const path of stringArrayValue(data.chunkPaths)) {
      storagePaths.add(path);
    }

    const audioPath = nullableStringValue(data.audioPath);
    if (audioPath) {
      storagePaths.add(audioPath);
    }

    await Promise.all(
      [...storagePaths].map(async path => {
        try {
          await admin.storage().bucket().file(path).delete();
        } catch {
          return;
        }
      }),
    );

    await documentReference.delete();
    return { lectureId, deleted: true };
  },
);
