import { tmpdir } from "node:os";
import { basename, join } from "node:path";
import { unlink } from "node:fs/promises";

import * as admin from "firebase-admin";
import { onObjectFinalized } from "firebase-functions/v2/storage";

import { openAIKey } from "./config";
import { parseAudioObject, mergeChunkTranscript } from "./audioProcessing";
import { createProcessingLogger } from "./logging";
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
    const log = createProcessingLogger({
      functionName: "processLectureAudio",
      eventId: event.id,
      eventType: event.type,
      bucketName,
      filePath,
      contentType: object.contentType,
      size: object.size,
    });

    if (!filePath || !bucketName) {
      log.warn("Skipping storage event with missing file path or bucket");
      return;
    }

    const audioObject = parseAudioObject(filePath);
    if (!audioObject) {
      log.debug("Skipping unrelated storage object");
      return;
    }

    const { uid, lectureId } = audioObject;
    const lectureLog = createProcessingLogger({
      functionName: "processLectureAudio",
      eventId: event.id,
      eventType: event.type,
      uid,
      lectureId,
      bucketName,
      filePath,
      audioKind: audioObject.kind,
      chunkIndex: audioObject.kind === "chunk" ? audioObject.chunkIndex : null,
    });
    const documentReference = admin
      .firestore()
      .collection("users")
      .doc(uid)
      .collection("lectures")
      .doc(lectureId);

    const tempFilePath = join(tmpdir(), basename(filePath));

    try {
      lectureLog.info("Audio lecture processing started");

      await documentReference.set(
        {
          status: "transcribing",
          errorMessage: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      lectureLog.info("Lecture status updated", { status: "transcribing" });

      lectureLog.info("Downloading audio file from Cloud Storage", {
        tempFilePath,
      });
      await admin.storage().bucket(bucketName).file(filePath).download({
        destination: tempFilePath,
      });
      lectureLog.info("Audio file downloaded", { tempFilePath });

      lectureLog.info("Starting audio transcription");
      const transcript = await transcribeLecture(tempFilePath, openAIKey.value());
      lectureLog.info("Audio transcription completed", {
        languageDetected: transcript.language ?? null,
        transcriptLength: transcript.text.length,
      });

      if (audioObject.kind === "chunk") {
        lectureLog.info("Merging chunk transcript", {
          chunkIndex: audioObject.chunkIndex,
        });
        const mergeResult = await mergeChunkTranscript({
          documentReference,
          chunkIndex: audioObject.chunkIndex,
          transcript: transcript.text,
          language: transcript.language ?? null,
        });

        if (!mergeResult.shouldGenerateStudyPack) {
          lectureLog.info("Chunk transcript saved", {
            chunkIndex: audioObject.chunkIndex,
            completedChunkCount: mergeResult.completedChunkCount,
          });
          return;
        }

        lectureLog.info("All chunks are ready, generating study pack", {
          completedChunkCount: mergeResult.completedChunkCount,
          mergedTranscriptLength: mergeResult.mergedTranscript.length,
        });
        const studyPack = await generateStudyPack(
          mergeResult.mergedTranscript,
          openAIKey.value(),
        );

        await saveStudyPack(
          documentReference,
          mergeResult.mergedTranscript,
          studyPack,
        );
        lectureLog.info("Study pack saved for merged chunk lecture", {
          flashcardCount: studyPack.flashcards.length,
          quizQuestionCount: studyPack.quiz.length,
        });
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
        lectureLog.info("Lecture status updated", {
          status: "generating",
          languageDetected: transcript.language ?? null,
        });

        lectureLog.info("Generating study pack from transcript", {
          transcriptLength: transcript.text.length,
        });
        const studyPack = await generateStudyPack(
          transcript.text,
          openAIKey.value(),
        );

        await saveStudyPack(documentReference, transcript.text, studyPack);
        lectureLog.info("Study pack saved for audio lecture", {
          flashcardCount: studyPack.flashcards.length,
          quizQuestionCount: studyPack.quiz.length,
        });
      }

      lectureLog.info("Audio lecture processed successfully");
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Unknown processing error";

      lectureLog.error("Audio lecture processing failed", error, { message });

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
        lectureLog.debug("Temporary file cleanup skipped", { tempFilePath });
      }
    }
  },
);
