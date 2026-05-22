import { describe, expect, it } from "vitest";
import { apiError, isApiError } from "../../src/shared/errors";

describe("shared API errors", () => {
  it("creates a stable structured error body", () => {
    expect(apiError("FILE_NOT_FOUND", "File not found")).toEqual({
      error: {
        code: "FILE_NOT_FOUND",
        message: "File not found"
      }
    });
  });

  it("recognizes API error payloads", () => {
    expect(isApiError({ error: { code: "UNAUTHORIZED", message: "Bad token" } })).toBe(true);
    expect(isApiError({ code: "UNAUTHORIZED", message: "Bad token" })).toBe(false);
  });
});
