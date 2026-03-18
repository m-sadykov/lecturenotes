export type YouTubeMetadata = {
  normalizedURL: string;
  videoId: string;
  title?: string;
};

type TranscriptAPISegment = {
  text?: string;
  start?: number;
  duration?: number;
};

type TranscriptAPIResponse = {
  video_id?: string;
  language?: string;
  transcript?: TranscriptAPISegment[] | string;
  metadata?: {
    title?: string;
    author_name?: string;
    author_url?: string;
    thumbnail_url?: string;
  };
};

type TranscriptAPIErrorResponse = {
  error?: string;
  message?: string;
  detail?: string;
};

const transcriptAPIBaseURL = "https://transcriptapi.com/api/v2";
const transcriptAPIRequestTimeoutMs = 20_000;
const youtubeVideoIDPattern =
  /(?:youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/|live\/|shorts\/)|youtu\.be\/)([^"&?/\s]{11})/i;

export function prepareYouTubeMetadata(sourceURL: string): YouTubeMetadata {
  let url: URL;

  try {
    url = new URL(sourceURL);
  } catch {
    throw new YouTubeProcessingError(
      "invalid_youtube_url",
      "Enter a valid YouTube link.",
    );
  }

  const host = url.host.toLowerCase();
  if (!host.includes("youtube.com") && !host.includes("youtu.be")) {
    throw new YouTubeProcessingError(
      "invalid_youtube_url",
      "Enter a valid YouTube link.",
    );
  }

  if (url.pathname.toLowerCase().includes("/shorts/")) {
    throw new YouTubeProcessingError(
      "youtube_short_not_supported",
      "YouTube Shorts are not supported yet.",
    );
  }

  const videoId = extractYouTubeVideoID(sourceURL);
  if (!videoId) {
    throw new YouTubeProcessingError(
      "invalid_youtube_url",
      "Enter a valid YouTube link.",
    );
  }

  return {
    normalizedURL: `https://www.youtube.com/watch?v=${videoId}`,
    videoId,
  };
}

export async function fetchYouTubeTranscript(
  sourceURLOrVideoID: string,
  apiKey: string,
): Promise<YouTubeMetadata & { transcript: string }> {
  const metadata = prepareYouTubeMetadata(
    sourceURLOrVideoID.length == 11 ?
      `https://www.youtube.com/watch?v=${sourceURLOrVideoID}` :
      sourceURLOrVideoID,
  );

  const url = new URL(`${transcriptAPIBaseURL}/youtube/transcript`);
  url.searchParams.set("video_url", metadata.videoId);
  url.searchParams.set("format", "json");
  url.searchParams.set("include_timestamp", "false");
  url.searchParams.set("send_metadata", "true");

  const response = await fetch(url, {
    method: "GET",
    signal: AbortSignal.timeout(transcriptAPIRequestTimeoutMs),
    headers: {
      Authorization: `Bearer ${apiKey}`,
      Accept: "application/json",
    },
  });

  if (!response.ok) {
    throw await transcriptAPIError(response);
  }

  const payload = await response.json() as TranscriptAPIResponse;
  const transcript = normalizeTranscript(payload.transcript);
  if (!transcript) {
    throw new YouTubeProcessingError(
      "youtube_transcript_unavailable",
      "Transcript is unavailable for this video.",
    );
  }

  return {
    normalizedURL: metadata.normalizedURL,
    videoId: payload.video_id?.trim() || metadata.videoId,
    title: payload.metadata?.title?.trim() || undefined,
    transcript,
  };
}

export function mapYouTubeError(error: unknown): YouTubeProcessingError {
  if (error instanceof YouTubeProcessingError) {
    return error;
  }

  if (error instanceof Error) {
    const message = error.message.toLowerCase();

    if (message.includes("shorts")) {
      return new YouTubeProcessingError(
        "youtube_short_not_supported",
        "YouTube Shorts are not supported yet.",
      );
    }

    if (message.includes("live")) {
      return new YouTubeProcessingError(
        "youtube_live_not_supported",
        "Live streams are not supported.",
      );
    }

    if (
      message.includes("private") ||
      message.includes("age-restricted")
    ) {
      return new YouTubeProcessingError(
        "youtube_processing_failed",
        error.message,
      );
    }

    if (
      message.includes("transcript") &&
      (
        message.includes("not available") ||
        message.includes("unavailable") ||
        message.includes("disabled")
      )
    ) {
      return new YouTubeProcessingError(
        "youtube_transcript_unavailable",
        "Transcript is unavailable for this video.",
      );
    }

    if (
      message.includes("video unavailable") ||
      message.includes("not found") ||
      message.includes("unavailable")
    ) {
      return new YouTubeProcessingError(
        "youtube_unavailable",
        "This YouTube video is unavailable.",
      );
    }

    if (message.includes("timeout") || message.includes("aborted")) {
      return new YouTubeProcessingError(
        "youtube_processing_failed",
        "Transcript API timed out. Try again later.",
      );
    }

    if (
      message.includes("too many requests") ||
      message.includes("rate limit") ||
      message.includes("temporarily blocked") ||
      message.includes("forbidden")
    ) {
      return new YouTubeProcessingError(
        "youtube_processing_failed",
        "Transcript API temporarily rejected this request. Try again later.",
      );
    }

    if (
      message.includes("unauthorized") ||
      message.includes("invalid api key") ||
      message.includes("bearer")
    ) {
      return new YouTubeProcessingError(
        "youtube_processing_failed",
        "Transcript API authorization failed.",
      );
    }
  }

  return new YouTubeProcessingError(
    "youtube_processing_failed",
    error instanceof Error ?
      error.message :
      "We couldn't process this YouTube video right now.",
  );
}

function extractYouTubeVideoID(sourceURLOrVideoID: string): string | null {
  if (sourceURLOrVideoID.length == 11) {
    return sourceURLOrVideoID;
  }

  const match = sourceURLOrVideoID.match(youtubeVideoIDPattern);
  return match?.[1] ?? null;
}

function normalizeTranscript(
  transcript: TranscriptAPIResponse["transcript"],
): string {
  if (typeof transcript === "string") {
    return transcript.trim();
  }

  if (!Array.isArray(transcript)) {
    return "";
  }

  return transcript
    .map(segment => segment.text?.trim() ?? "")
    .filter(Boolean)
    .join(" ")
    .trim();
}

async function transcriptAPIError(response: Response): Promise<YouTubeProcessingError> {
  let payload: TranscriptAPIErrorResponse | null = null;

  try {
    payload = await response.json() as TranscriptAPIErrorResponse;
  } catch {
    payload = null;
  }

  const message = (
    payload?.message ||
    payload?.detail ||
    payload?.error ||
    `Transcript API request failed with ${response.status}`
  ).trim();

  if (response.status === 401) {
    return new YouTubeProcessingError(
      "youtube_processing_failed",
      "Transcript API authorization failed.",
    );
  }

  if (response.status === 402) {
    return new YouTubeProcessingError(
      "youtube_processing_failed",
      "Transcript API credits are exhausted.",
    );
  }

  if (response.status === 404) {
    return new YouTubeProcessingError(
      "youtube_unavailable",
      "This YouTube video is unavailable.",
    );
  }

  if (response.status === 429) {
    return new YouTubeProcessingError(
      "youtube_processing_failed",
      "Transcript API rate limit reached. Try again later.",
    );
  }

  return mapYouTubeError(new Error(message));
}

export class YouTubeProcessingError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}
