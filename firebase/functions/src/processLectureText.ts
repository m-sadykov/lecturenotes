import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

import { openAIKey } from "./config";
import { createProcessingLogger } from "./logging";
import { generateStudyPack, saveStudyPack } from "./studyPack";
import { stringValue } from "./utils";

export const processLectureText = onDocumentWritten(
  {
    document: "users/{uid}/lectures/{lectureId}",
    secrets: [openAIKey],
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async event => {
    const baseLog = createProcessingLogger({
      functionName: "processLectureText",
      eventId: event.id,
      eventType: event.type,
      uid: event.params.uid,
      lectureId: event.params.lectureId,
    });
    const beforeSnapshot = event.data?.before;
    const afterSnapshot = event.data?.after;

    if (!afterSnapshot?.exists) {
      baseLog.debug("Skipping text processing because document was deleted");
      return;
    }

    const previousData = beforeSnapshot?.data() ?? {};
    const data = afterSnapshot.data() ?? {};
    const sourceType = stringValue(data.sourceType);
    const status = stringValue(data.status);
    const transcript = stringValue(data.transcript).trim();
    const previousStatus = stringValue(previousData.status);
    const previousTranscript = stringValue(previousData.transcript).trim();
    const didEnterGenerating =
      status === "generating" &&
      (previousStatus !== "generating" || previousTranscript !== transcript);

    if (!["text", "pdf"].includes(sourceType) || !didEnterGenerating || !transcript) {
      baseLog.debug("Skipping text processing because trigger conditions were not met", {
        sourceType,
        status,
        previousStatus,
        transcriptLength: transcript.length,
        previousTranscriptLength: previousTranscript.length,
      });
      return;
    }

    const { uid, lectureId } = event.params;
    const documentReference = afterSnapshot.ref;
    const log = createProcessingLogger({
      functionName: "processLectureText",
      eventId: event.id,
      eventType: event.type,
      uid,
      lectureId,
      sourceType,
      status,
      transcriptLength: transcript.length,
    });

    try {
      log.info("Imported lecture processing started");

      await documentReference.set(
        {
          errorMessage: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      log.info("Cleared previous processing error message");

      log.info("Generating study pack from text transcript");
      const studyPack = await generateStudyPack(transcript, openAIKey.value());
      log.info("Study pack generation completed", {
        flashcardCount: studyPack.flashcards.length,
        quizQuestionCount: studyPack.quiz.length,
      });
      await saveStudyPack(documentReference, transcript, studyPack);
      log.info("Study pack saved to Firestore");

      log.info("Imported lecture processed successfully");
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Unknown processing error";

      log.error("Text lecture processing failed", error, { message });

      await documentReference.set(
        {
          status: "failed",
          errorMessage: message,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
  },
);
