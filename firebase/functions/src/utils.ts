export function numberValue(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }

  return 0;
}

export function stringValue(value: unknown): string {
  if (typeof value === "string") {
    return value;
  }

  return "";
}

export function stringMapValue(value: unknown): Record<string, string> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }

  const entries = Object.entries(value as Record<string, unknown>)
    .filter(([, entryValue]) => typeof entryValue === "string")
    .map(([entryKey, entryValue]) => [entryKey, entryValue as string]);

  return Object.fromEntries(entries);
}

export async function openAIErrorMessage(response: Response): Promise<string> {
  try {
    const payload = (await response.json()) as {
      error?: {
        message?: string;
      };
    };
    return (
      payload.error?.message ?? `OpenAI request failed with ${response.status}`
    );
  } catch {
    return `OpenAI request failed with ${response.status}`;
  }
}
