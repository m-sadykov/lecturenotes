import { tmpdir } from "node:os";
import { basename, join } from "node:path";
import { unlink } from "node:fs/promises";

import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { onObjectFinalized } from "firebase-functions/v2/storage";

import { openAIKey } from "./config";
import { parseAudioObject, mergeChunkTranscript } from "./audioProcessing";
import { generateStudyPack, saveStudyPack } from "./studyPack";
import { transcribeLecture } from "./transcription";

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

        await saveStudyPack(
          documentReference,
          mergeResult.mergedTranscript,
          studyPack,
        );
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
