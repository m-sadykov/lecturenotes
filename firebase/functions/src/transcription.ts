import { basename } from "node:path";
import { readFile } from "node:fs/promises";

import type { TranscriptResponse } from "./types";
import { openAIErrorMessage } from "./utils";

export async function transcribeLecture(
  filePath: string,
  apiKey: string,
): Promise<TranscriptResponse> {
  const audioBytes = await readFile(filePath);
  const mimeType = mimeTypeForAudioFile(filePath);
  const fileName = basename(filePath);
  return createTranscription({
    audioBytes,
    mimeType,
    fileName,
    apiKey,
    model: "gpt-4o-mini-transcribe",
  });
}

async function createTranscription({
  audioBytes,
  mimeType,
  fileName,
  apiKey,
  model,
}: {
  audioBytes: Buffer;
  mimeType: string;
  fileName: string;
  apiKey: string;
  model: string;
}): Promise<TranscriptResponse> {
  const formData = new FormData();
  const audioBlob = new Blob([new Uint8Array(audioBytes)], { type: mimeType });

  formData.append("file", audioBlob, fileName);
  formData.append("model", model);
  formData.append("response_format", "json");

  const response = await fetch("https://api.openai.com/v1/audio/transcriptions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
    },
    body: formData,
  });

  if (!response.ok) {
    throw new Error(await openAIErrorMessage(response));
  }

  const payload = (await response.json()) as TranscriptResponse;

  if (!payload.text?.trim()) {
    throw new Error("Transcription returned empty text.");
  }

  return payload;
}

function mimeTypeForAudioFile(filePath: string): string {
  const fileName = basename(filePath).toLowerCase();

  if (fileName.endsWith(".mp3") || fileName.endsWith(".mpeg")) {
    return "audio/mpeg";
  }

  if (fileName.endsWith(".wav")) {
    return "audio/wav";
  }

  if (fileName.endsWith(".mp4") || fileName.endsWith(".m4a")) {
    return "audio/mp4";
  }

  return "application/octet-stream";
}
