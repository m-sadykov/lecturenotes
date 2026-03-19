import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

import { openAIKey, transcriptAPIKey } from "./config";
import { createProcessingLogger } from "./logging";
import { generateStudyPack, saveStudyPack } from "./studyPack";
import {
  finalizeProcessingQuotaForLecture,
  releaseProcessingQuotaForLecture,
  reserveProcessingQuotaForLecture,
} from "./userProfile";
import {
  fetchYouTubeTranscript,
  mapYouTubeError,
  prepareYouTubeMetadata,
} from "./youtubeProcessing";
import { stringValue } from "./utils";

export const processLectureYouTube = onDocumentWritten(
  {
    document: "users/{uid}/lectures/{lectureId}",
    secrets: [openAIKey, transcriptAPIKey],
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async event => {
    const baseLog = createProcessingLogger({
      functionName: "processLectureYouTube",
      eventId: event.id,
      eventType: event.type,
      uid: event.params.uid,
      lectureId: event.params.lectureId,
    });
    const beforeSnapshot = event.data?.before;
    const afterSnapshot = event.data?.after;

    if (!afterSnapshot?.exists) {
      baseLog.debug("Skipping YouTube processing because document was deleted");
      return;
    }

    const previousData = beforeSnapshot?.data() ?? {};
    const data = afterSnapshot.data() ?? {};
    const sourceType = stringValue(data.sourceType);
    const status = stringValue(data.status);
    const previousStatus = stringValue(previousData.status);
    const sourceURL = stringValue(data.sourceURL);
    const storedVideoID = stringValue(data.youtubeVideoID);
    const transcript = stringValue(data.transcript).trim();
    const previousTranscript = stringValue(previousData.transcript).trim();
    const didEnterTranscribing =
      status === "transcribing" && previousStatus !== "transcribing";
    const didEnterGenerating =
      status === "generating" &&
      (previousStatus !== "generating" || previousTranscript !== transcript);

    if (sourceType !== "youtube") {
      baseLog.debug("Skipping non-YouTube lecture update", { sourceType });
      return;
    }

    const { uid, lectureId } = event.params;
    const documentReference = afterSnapshot.ref;
    const log = createProcessingLogger({
      functionName: "processLectureYouTube",
      eventId: event.id,
      eventType: event.type,
      uid,
      lectureId,
      sourceType,
      status,
      sourceURL,
      youtubeVideoID: storedVideoID,
      transcriptLength: transcript.length,
    });

    if (!didEnterTranscribing && !didEnterGenerating) {
      log.debug("Skipping YouTube processing because trigger conditions were not met", {
        previousStatus,
        previousTranscriptLength: previousTranscript.length,
      });
      return;
    }

    let didReserveQuota = false;

    try {
      const metadata = prepareYouTubeMetadata(sourceURL || storedVideoID);

      if (didEnterTranscribing) {
        await reserveProcessingQuotaForLecture(documentReference);
        didReserveQuota = true;
        log.info("Processing quota reserved");

        log.info("YouTube transcript fetch started", metadata);

        const fetchedTranscript = await fetchYouTubeTranscript(
          metadata.videoId,
          transcriptAPIKey.value(),
        );

        await documentReference.set(
          {
            sourceURL: fetchedTranscript.normalizedURL,
            youtubeVideoID: fetchedTranscript.videoId,
            title: fetchedTranscript.title ?? admin.firestore.FieldValue.delete(),
            transcript: fetchedTranscript.transcript,
            status: "generating",
            errorMessage: admin.firestore.FieldValue.delete(),
            processingErrorCode: admin.firestore.FieldValue.delete(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        log.info("YouTube transcript fetched and saved", {
          transcriptLength: fetchedTranscript.transcript.length,
          title: fetchedTranscript.title ?? null,
        });
        return;
      }

      if (!transcript) {
        throw mapYouTubeError(
          new Error("Transcript is unavailable for this video."),
        );
      }

      await documentReference.set(
        {
          sourceURL: metadata.normalizedURL,
          youtubeVideoID: metadata.videoId,
          errorMessage: admin.firestore.FieldValue.delete(),
          processingErrorCode: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      log.info("YouTube study pack generation started");

      const studyPack = await generateStudyPack(transcript, openAIKey.value());
      log.info("YouTube study pack generation completed", {
        flashcardCount: studyPack.flashcards.length,
        quizQuestionCount: studyPack.quiz.length,
      });

      await saveStudyPack(documentReference, transcript, studyPack);
      await finalizeProcessingQuotaForLecture(documentReference);
      log.info("YouTube lecture processed successfully");
    } catch (error) {
      const mappedError = mapYouTubeError(error);

      log.error("YouTube lecture processing failed", error, {
        code: mappedError.code,
        message: mappedError.message,
      });

      if (didReserveQuota || didEnterGenerating) {
        await releaseProcessingQuotaForLecture(documentReference);
      }

      await documentReference.set(
        {
          status: "failed",
          processingErrorCode: mappedError.code,
          errorMessage: mappedError.message,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
  },
);
