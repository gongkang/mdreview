#!/usr/bin/env node
import { cp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { constants } from "node:fs";
import { access, chmod } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const scriptPath = fileURLToPath(import.meta.url);

async function assertExists(target, message) {
  try {
    await access(target, constants.R_OK);
  } catch {
    throw new Error(message);
  }
}

function swiftBinPath(root, nativeDir) {
  const env = {
    ...process.env,
    DEVELOPER_DIR: process.env.DEVELOPER_DIR ?? "/Applications/Xcode.app/Contents/Developer"
  };
  return execFileSync("xcrun", ["swift", "build", "--package-path", nativeDir, "--show-bin-path"], {
    cwd: root,
    env,
    encoding: "utf8"
  }).trim();
}

function rewriteEntryAssetPaths(source) {
  return source.replace(/(["'])\.\/(?!assets\/)([^"']+\.js)\1/g, "$1./assets/$2$1");
}

function rewriteInlineCssAssetPaths(source) {
  return source.replace(/url\((["']?)\.\/(?!assets\/)([^)"']+)\1\)/g, "url($1./assets/$2$1)");
}

export async function inlineRendererHtml(html, readAsset) {
  const scriptMatch = /<script\b(?=[^>]*\btype=["']module["'])(?=[^>]*\bsrc=["'](\.\/assets\/[^"']+\.js)["'])[^>]*><\/script>/i.exec(html);
  const styleMatch = /<link\b(?=[^>]*\brel=["']stylesheet["'])(?=[^>]*\bhref=["'](\.\/assets\/[^"']+\.css)["'])[^>]*>/i.exec(html);
  if (!scriptMatch || !styleMatch) {
    throw new Error("无法识别 renderer 入口资源");
  }

  const scriptPath = scriptMatch[1].replace(/^\.\//, "");
  const stylePath = styleMatch[1].replace(/^\.\//, "");
  const script = rewriteEntryAssetPaths(await readAsset(scriptPath));
  const style = rewriteInlineCssAssetPaths(await readAsset(stylePath));

  return html
    .replace(scriptMatch[0], () => `<script type="module">\n${script}\n</script>`)
    .replace(styleMatch[0], () => `<style>\n${style}\n</style>`);
}

export async function copyBundleIcon({ nativeDir, resourcesDir }) {
  const iconSourcePath = path.join(nativeDir, "AppIcon.icns");
  await assertExists(iconSourcePath, "缺少 native/AppIcon.icns");
  await cp(iconSourcePath, path.join(resourcesDir, "AppIcon.icns"));
}

export async function packageMacosApp({ root = path.resolve(path.dirname(scriptPath), "..") } = {}) {
  const nativeDir = path.join(root, "native");
  const appDir = path.join(nativeDir, "dist", "mdreview.app");
  const contentsDir = path.join(appDir, "Contents");
  const macOSDir = path.join(contentsDir, "MacOS");
  const resourcesDir = path.join(contentsDir, "Resources");
  const rendererSourceDir = path.join(root, "dist", "client");
  const rendererTargetDir = path.join(resourcesDir, "renderer");
  const infoPlistPath = path.join(nativeDir, "Info.plist");

  await assertExists(rendererSourceDir, "缺少前端构建产物：请先运行 npm run build:web");
  await assertExists(infoPlistPath, "缺少 native/Info.plist");

  const executableSource = path.join(swiftBinPath(root, nativeDir), "mdreview-app");
  await assertExists(executableSource, "缺少 native 可执行文件：请先运行 npm run build:native");

  await rm(appDir, { recursive: true, force: true });
  await mkdir(macOSDir, { recursive: true });
  await mkdir(resourcesDir, { recursive: true });

  await cp(infoPlistPath, path.join(contentsDir, "Info.plist"));
  await copyBundleIcon({ nativeDir, resourcesDir });
  await writeFile(path.join(contentsDir, "PkgInfo"), "APPL????");
  await cp(executableSource, path.join(macOSDir, "mdreview-app"));
  await chmod(path.join(macOSDir, "mdreview-app"), 0o755);
  await cp(rendererSourceDir, rendererTargetDir, { recursive: true });

  const rendererIndexPath = path.join(rendererTargetDir, "index.html");
  const rendererIndex = await readFile(rendererIndexPath, "utf8");
  const inlinedRendererIndex = await inlineRendererHtml(rendererIndex, (relativePath) => readFile(path.join(rendererTargetDir, relativePath), "utf8"));
  await writeFile(rendererIndexPath, inlinedRendererIndex);

  console.log(`Created ${path.relative(root, appDir)}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await packageMacosApp();
}
