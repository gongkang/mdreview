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
