export const API_TOKEN_HEADER = "x-mdreview-token";

export function createToken(bytes: Uint8Array): string {
  return Array.from(bytes, (value) => value.toString(16).padStart(2, "0")).join("");
}
