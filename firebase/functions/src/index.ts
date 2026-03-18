import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";

import { processLectureAudio } from "./processLectureAudio";
import { processLectureText } from "./processLectureText";

admin.initializeApp();

setGlobalOptions({ maxInstances: 10 });

export { processLectureAudio, processLectureText };
