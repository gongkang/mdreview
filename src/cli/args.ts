export type CliOptions =
  | { action: "open"; path: string; newWindow: boolean }
  | { action: "help" }
  | { action: "version" };

export const HELP_TEXT = "用法：mdreview <文件或目录> [--new-window]\n\n选项：\n  --new-window  在新窗口中打开目录或文件\n  --help        显示帮助\n  --version     显示版本";
export const VERSION = "0.1.0";

const removedFlags = new Set(["--port", "--no-open"]);

export function parseArgs(argv: string[]): CliOptions {
  if (argv.includes("--help")) return { action: "help" };
  if (argv.includes("--version")) return { action: "version" };

  let inputPath: string | undefined;
  let newWindow = false;

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (removedFlags.has(arg)) throw new Error(`不再支持参数：${arg}`);
    if (arg === "--new-window") {
      newWindow = true;
      continue;
    }
    if (!arg.startsWith("-") && !inputPath) {
      inputPath = arg;
      continue;
    }
    throw new Error(`未知参数：${arg}`);
  }

  if (!inputPath) throw new Error("用法：mdreview <文件或目录>");
  return { action: "open", path: inputPath, newWindow };
}
