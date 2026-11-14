import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";

import {
  deleteLectureCascade,
  markLectureFailed,
  startLectureProcessing,
  upsertLecture,
} from "./lectureMutations";
import { processLectureAudio } from "./processLectureAudio";
import { processLectureText } from "./processLectureText";
import { processLectureYouTube } from "./processLectureYouTube";
import { regenerateStudyItems } from "./studyItemsRegeneration";

admin.initializeApp();

setGlobalOptions({ maxInstances: 10 });

export {
  deleteLectureCascade,
  markLectureFailed,
  processLectureAudio,
  processLectureText,
  processLectureYouTube,
  regenerateStudyItems,
  startLectureProcessing,
  upsertLecture,
};
