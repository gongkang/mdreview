import { useEffect, useMemo, useState } from "react";
import type { DocumentResponse, FileNode, SessionResponse } from "../shared/types";
import { ApiClient, readTokenFromLocation } from "./api-client";
import { ErrorView } from "./components/ErrorView";
import { FileTree } from "./components/FileTree";
import { Outline, type OutlineItem } from "./components/Outline";

function extractOutline(content: string): OutlineItem[] {
  return content
    .split("\n")
    .map((line) => /^(#{1,6})\s+(.+)$/.exec(line))
    .filter((match): match is RegExpExecArray => Boolean(match))
    .map((match) => ({
      depth: match[1].length,
      text: match[2],
      id: match[2].toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
    }));
}

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

  const outline = extractOutline(document.content);

  return (
    <main className={session.mode === "directory" ? "app-shell directory-mode" : "app-shell file-mode"}>
      {session.mode === "directory" && <FileTree nodes={files} currentPath={document.path} onSelect={selectDocument} />}
      <section className="document-pane">
        <header className="document-header">{session.mode === "directory" ? session.rootName : document.name}</header>
        <article className="markdown-body">{document.content}</article>
      </section>
      <Outline items={outline} />
    </main>
  );
}
