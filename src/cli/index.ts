#!/usr/bin/env node
import open from "open";
import { HELP_TEXT, VERSION, parseArgs } from "./args";
import { startPreviewServer } from "../server/http-server";
import { createPreviewSession } from "../server/session";

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
    const session = await createPreviewSession(options.path);
    const server = await startPreviewServer({ session, port: options.port });
    const url = `${server.url}/#token=${session.token}`;
    console.log(`mdreview preview: ${url}`);
    if (options.openBrowser) {
      await open(url).catch(() => {
        console.warn(`Could not open browser automatically. Open this URL manually: ${url}`);
      });
    }
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}

void main();
