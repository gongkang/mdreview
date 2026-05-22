import { stat } from "node:fs/promises";
import { homedir } from "node:os";
import path from "node:path";

type ResolveAppLaunchArgsOptions = {
  env?: NodeJS.ProcessEnv;
  home?: string;
  pathExists?: (candidate: string) => Promise<boolean>;
};

async function defaultPathExists(candidate: string): Promise<boolean> {
  try {
    const stats = await stat(candidate);
    return stats.isDirectory();
  } catch {
    return false;
  }
}

export function installedAppCandidates(home = homedir()): string[] {
  return [
    path.join(home, "Applications", "mdreview.app"),
    "/Applications/mdreview.app"
  ];
}

export async function resolveAppLaunchArgs(options: ResolveAppLaunchArgsOptions = {}): Promise<string[]> {
  const env = options.env ?? process.env;
  if (env.MDREVIEW_APP_PATH) return [env.MDREVIEW_APP_PATH];

  const pathExists = options.pathExists ?? defaultPathExists;
  for (const candidate of installedAppCandidates(options.home ?? homedir())) {
    if (await pathExists(candidate)) return [candidate];
  }

  return ["-a", "mdreview"];
}
