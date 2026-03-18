import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

import { openAIKey } from "./config";
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
    const beforeSnapshot = event.data?.before;
    const afterSnapshot = event.data?.after;

    if (!afterSnapshot?.exists) {
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

    if (sourceType !== "text" || !didEnterGenerating || !transcript) {
      return;
    }

    const { uid, lectureId } = event.params;
    const documentReference = afterSnapshot.ref;

    try {
      await documentReference.set(
        {
          errorMessage: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      const studyPack = await generateStudyPack(transcript, openAIKey.value());
      await saveStudyPack(documentReference, transcript, studyPack);

      logger.info("Text lecture processed successfully", { uid, lectureId });
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Unknown processing error";

      logger.error("Text lecture processing failed", { uid, lectureId, message });

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
