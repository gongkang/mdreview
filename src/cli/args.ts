export type CliOptions =
  | {
      action: "serve";
      path: string;
      port?: number;
      openBrowser: boolean;
    }
  | {
      action: "help";
    }
  | {
      action: "version";
    };

export const HELP_TEXT = "Usage: mdreview <file-or-directory> [--port <number>] [--no-open]";
export const VERSION = "0.1.0";

export function parseArgs(argv: string[]): CliOptions {
  if (argv.includes("--help")) {
    return { action: "help" };
  }
  if (argv.includes("--version")) {
    return { action: "version" };
  }

  let inputPath: string | undefined;
  let port: number | undefined;
  let openBrowser = true;

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--no-open") {
      openBrowser = false;
      continue;
    }
    if (arg === "--port") {
      const value = argv[index + 1];
      if (!value || Number.isNaN(Number(value))) throw new Error("--port requires a number");
      port = Number(value);
      index += 1;
      continue;
    }
    if (!arg.startsWith("-") && !inputPath) {
      inputPath = arg;
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  if (!inputPath) throw new Error("Usage: mdreview <file-or-directory>");
  return { action: "serve", path: inputPath, port, openBrowser };
}
