import { defineSecret } from "firebase-functions/params";

export const openAIKey = defineSecret("OPENAI_API_KEY");
export const transcriptAPIKey = defineSecret("TRANSCRIPT_API_KEY");
