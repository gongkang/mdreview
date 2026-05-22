import { API_TOKEN_HEADER } from "../shared/security";
import type { DocumentResponse, FileNode, SessionResponse } from "../shared/types";

export function readTokenFromLocation(hash = window.location.hash): string | null {
  const params = new URLSearchParams(hash.replace(/^#/, ""));
  return params.get("token");
}

export class ApiClient {
  constructor(private readonly token: string) {}

  private async getJson<T>(path: string): Promise<T> {
    const response = await fetch(path, { headers: { [API_TOKEN_HEADER]: this.token } });
    if (!response.ok) throw new Error(`Request failed: ${response.status}`);
    return response.json() as Promise<T>;
  }

  session() {
    return this.getJson<SessionResponse>("/api/session");
  }

  files() {
    return this.getJson<FileNode[]>("/api/files");
  }

  document(path: string) {
    return this.getJson<DocumentResponse>(`/api/document?path=${encodeURIComponent(path)}`);
  }
}

export function subscribeToDocumentEvents(token: string, onChange: () => void): () => void {
  const controller = new AbortController();

  void (async () => {
    const response = await fetch("/api/events", {
      headers: { [API_TOKEN_HEADER]: token },
      signal: controller.signal
    });
    if (!response.ok || !response.body) return;

    const reader = response.body.pipeThrough(new TextDecoderStream()).getReader();
    let buffer = "";
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      buffer += value;
      const messages = buffer.split("\n\n");
      buffer = messages.pop() ?? "";
      for (const message of messages) {
        if (message.includes("event: document:changed")) onChange();
      }
    }
  })().catch((error) => {
    if (!controller.signal.aborted) console.error(error);
  });

  return () => controller.abort();
}
