export type PreviewMode = "file" | "directory";

export type FileNode = {
  type: "file" | "directory";
  name: string;
  path: string;
  children?: FileNode[];
};

export type SessionResponse = {
  mode: PreviewMode;
  rootName: string;
  defaultDocument: string | null;
};

export type DocumentResponse = {
  path: string;
  name: string;
  mtime: number;
  content: string;
};

export type ApiErrorCode =
  | "BAD_REQUEST"
  | "UNAUTHORIZED"
  | "FORBIDDEN"
  | "NOT_FOUND"
  | "FILE_NOT_FOUND"
  | "READ_FAILED"
  | "PORT_IN_USE";

export type ApiErrorBody = {
  error: {
    code: ApiErrorCode;
    message: string;
  };
};

export type FileChangedEvent = {
  type: "document:changed";
  path: string;
  mtime: number;
};
