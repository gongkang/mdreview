import type { ApiErrorBody, ApiErrorCode } from "./types";

export function apiError(code: ApiErrorCode, message: string): ApiErrorBody {
  return { error: { code, message } };
}

export function isApiError(value: unknown): value is ApiErrorBody {
  if (!value || typeof value !== "object") return false;
  const maybe = value as { error?: { code?: unknown; message?: unknown } };
  return typeof maybe.error?.code === "string" && typeof maybe.error.message === "string";
}
