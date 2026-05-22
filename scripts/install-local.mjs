#!/usr/bin/env node
import { cp, mkdir, rm, access } from "node:fs/promises";
import { constants } from "node:fs";
import { execFileSync } from "node:child_process";
import { homedir } from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const scriptPath = fileURLToPath(import.meta.url);

export function createInstallPlan({ root, home = homedir() }) {
  return {
    appSource: path.join(root, "native", "dist", "mdreview.app"),
    appTarget: path.join(home, "Applications", "mdreview.app"),
    linkCommand: { command: "npm", args: ["link"], cwd: root }
  };
}

async function assertReadable(target, message) {
  try {
    await access(target, constants.R_OK);
  } catch {
    throw new Error(message);
  }
}

function registerLaunchServices(appTarget) {
  const lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister";
  try {
    execFileSync(lsregister, ["-f", appTarget], { stdio: "ignore" });
  } catch {
    // The CLI can launch the copied app by path, so Launch Services registration is best effort.
  }
}

export async function installLocal({ root = path.resolve(path.dirname(scriptPath), ".."), home = homedir() } = {}) {
  const plan = createInstallPlan({ root, home });
  await assertReadable(plan.appSource, "缺少 App 构建产物：请先运行 npm run build:app");

  await mkdir(path.dirname(plan.appTarget), { recursive: true });
  await rm(plan.appTarget, { recursive: true, force: true });
  await cp(plan.appSource, plan.appTarget, { recursive: true });
  registerLaunchServices(plan.appTarget);

  execFileSync(plan.linkCommand.command, plan.linkCommand.args, {
    cwd: plan.linkCommand.cwd,
    stdio: "inherit"
  });

  console.log(`已安装 App：${plan.appTarget}`);
  console.log("已注册命令：mdreview");
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await installLocal();
}
