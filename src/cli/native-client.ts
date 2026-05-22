import net from "node:net";

export type NativeOpenRequest = {
  kind: "openFile" | "openDirectory";
  path: string;
  newWindow: boolean;
};

export type NativeOpenResponse = {
  accepted: boolean;
  action: "opened" | "focused" | "rejected";
  message: string;
};

export function defaultSocketPath(env = process.env): string {
  const base = env.TMPDIR ?? "/tmp/";
  const trimmed = base.endsWith("/") ? base.slice(0, -1) : base;
  return `${trimmed}/mdreview-${process.getuid?.() ?? 0}.sock`;
}

export async function sendOpenRequest(socketPath: string, request: NativeOpenRequest, timeoutMs: number): Promise<NativeOpenResponse> {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection(socketPath);
    const timer = setTimeout(() => {
      socket.destroy();
      reject(new Error("等待 mdreview App 响应超时"));
    }, timeoutMs);

    let buffer = "";
    socket.on("connect", () => {
      socket.write(JSON.stringify(request) + "\n");
    });
    socket.on("data", (chunk) => {
      buffer += chunk.toString("utf8");
      if (!buffer.includes("\n")) return;
      clearTimeout(timer);
      socket.end();
      resolve(JSON.parse(buffer.trim()) as NativeOpenResponse);
    });
    socket.on("error", (error) => {
      clearTimeout(timer);
      reject(error);
    });
  });
}
