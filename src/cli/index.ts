#!/usr/bin/env node
import { spawn } from "node:child_process";
import { rm, stat } from "node:fs/promises";
import path from "node:path";
import { resolveAppLaunchArgs } from "./app-launch";
import { HELP_TEXT, VERSION, parseArgs } from "./args";
import { defaultSocketPath, sendOpenRequest, type NativeOpenRequest } from "./native-client";

async function launchApp() {
  const child = spawn("open", await resolveAppLaunchArgs(), { stdio: "ignore", detached: true });
  child.unref();
}

async function waitForApp(socketPath: string, request: NativeOpenRequest) {
  const started = Date.now();
  let lastError: unknown;
  while (Date.now() - started < 5_000) {
    try {
      return await sendOpenRequest(socketPath, request, 2_000);
    } catch (error) {
      lastError = error;
      await new Promise((resolve) => setTimeout(resolve, 150));
    }
  }
  const detail = lastError instanceof Error ? lastError.message : "未知错误";
  throw new Error(`无法连接 mdreview App，请确认已安装 App 或设置 MDREVIEW_APP_PATH：${detail}`);
}

async function main() {
  try {
    const options = parseArgs(process.argv.slice(2));
    if (options.action === "help") {
      console.log(HELP_TEXT);
      return;
    }
    if (options.action === "version") {
      console.log(VERSION);
      return;
    }

    const absolutePath = path.resolve(options.path);
    const stats = await stat(absolutePath).catch(() => {
      throw new Error(`路径不存在：${options.path}`);
    });
    if (!stats.isFile() && !stats.isDirectory()) {
      throw new Error(`路径不是文件或目录：${options.path}`);
    }

    const request: NativeOpenRequest = {
      kind: stats.isDirectory() ? "openDirectory" : "openFile",
      path: absolutePath,
      newWindow: options.newWindow
    };
    const socketPath = defaultSocketPath();

    let response;
    try {
      response = await sendOpenRequest(socketPath, request, 2_000);
    } catch {
      await rm(socketPath, { force: true }).catch(() => undefined);
      await launchApp();
      response = await waitForApp(socketPath, request);
    }

    if (!response.accepted) {
      throw new Error(response.message);
    }
    console.log(response.message);
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}

void main();
