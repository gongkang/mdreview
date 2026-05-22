import { useEffect, useMemo, useState } from "react";
import type { DocumentResponse, FileNode, SessionResponse } from "../shared/types";
import { ApiClient, readTokenFromLocation } from "./api-client";
import { ErrorView } from "./components/ErrorView";
import { FileTree } from "./components/FileTree";
import { MarkdownView } from "./components/MarkdownView";
import { Outline, type OutlineItem } from "./components/Outline";

function firstMarkdownPath(nodes: FileNode[]): string | null {
  for (const node of nodes) {
    if (node.type === "file") return node.path;
    const childPath = firstMarkdownPath(node.children ?? []);
    if (childPath) return childPath;
  }
  return null;
}

export function App() {
  const token = readTokenFromLocation();
  const client = useMemo(() => (token ? new ApiClient(token) : null), [token]);
  const [session, setSession] = useState<SessionResponse | null>(null);
  const [files, setFiles] = useState<FileNode[]>([]);
  const [document, setDocument] = useState<DocumentResponse | null>(null);
  const [outline, setOutline] = useState<OutlineItem[]>([]);
  const [error, setError] = useState<string | null>(token ? null : "Missing preview session token");

  useEffect(() => {
    if (!client) return;
    client
      .session()
      .then(async (nextSession) => {
        setSession(nextSession);
        let loadedFiles: FileNode[] = [];
        if (nextSession.mode === "directory") {
          loadedFiles = await client.files();
          setFiles(loadedFiles);
        }
        const defaultPath = nextSession.defaultDocument ?? firstMarkdownPath(loadedFiles);
        if (defaultPath) setDocument(await client.document(defaultPath));
      })
      .catch((reason) => setError(reason instanceof Error ? reason.message : String(reason)));
  }, [client]);

  async function selectDocument(path: string) {
    if (!client) return;
    setDocument(await client.document(path));
  }

  if (error) return <ErrorView title="Preview session unavailable" detail={error} />;
  if (!session || !document) return <main className="app-shell loading">Loading...</main>;

  return (
    <main className={session.mode === "directory" ? "app-shell directory-mode" : "app-shell file-mode"}>
      {session.mode === "directory" && <FileTree nodes={files} currentPath={document.path} onSelect={selectDocument} />}
      <section className="document-pane">
        <header className="document-header">{session.mode === "directory" ? session.rootName : document.name}</header>
        <article className="markdown-body">
          <MarkdownView content={document.content} onOutline={setOutline} />
        </article>
      </section>
      <Outline items={outline} />
    </main>
  );
}
