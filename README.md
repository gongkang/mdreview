# mdreview

轻量级 macOS 原生 Markdown 预览器，支持从命令行快速打开文件或目录。

## 安装

优先使用常规安装流程：

```bash
npm ci
npm run install:local
```

安装完成后会生成两个本机入口：

- App：`~/Applications/mdreview.app`
- CLI：`mdreview`

如果机器没有完整 Xcode.app，但已经安装 Command Line Tools，可以显式指定 Swift 工具链：

```bash
npm ci
DEVELOPER_DIR=/Library/Developer/CommandLineTools npm run install:local
```

### 兼容安装

如果安装过程中遇到下面这类错误，通常是 macOS 终止了 npm 依赖里的原生二进制，例如 `esbuild`：

```text
Killed: 9
SIGKILL
exit 137
```

可以改用下面的拆分流程。这个流程会跳过 npm postinstall，使用本机 Go 从源码构建 `esbuild`，再按常规顺序完成 web 构建、CLI 构建、Swift 构建、App 打包和本地安装。

```bash
npm ci --ignore-scripts

mkdir -p /tmp/mdreview-bin
GOBIN=/tmp/mdreview-bin go install github.com/evanw/esbuild/cmd/esbuild@v0.27.7

ESBUILD_BINARY_PATH=/tmp/mdreview-bin/esbuild node node_modules/vite/bin/vite.js build
ESBUILD_BINARY_PATH=/tmp/mdreview-bin/esbuild node node_modules/tsup/dist/cli-default.js src/cli/index.ts --format esm --dts --out-dir dist/node

DEVELOPER_DIR=/Library/Developer/CommandLineTools xcrun swift build --package-path native
DEVELOPER_DIR=/Library/Developer/CommandLineTools node scripts/package-macos-app.mjs
node scripts/install-local.mjs
```

兼容流程需要本机可用的 Go 和 Command Line Tools：

```bash
go version
xcrun swift --version
```

## 使用

```bash
npm run build:app
MDREVIEW_APP_PATH="$PWD/native/dist/mdreview.app" node dist/node/index.js README.md
MDREVIEW_APP_PATH="$PWD/native/dist/mdreview.app" node dist/node/index.js docs --new-window
```

本机安装后可以直接使用 `mdreview` 命令：

```bash
mdreview README.md
mdreview docs --new-window
```

CLI 入口负责把打开请求交给原生 App，体验类似 Sublime Text 的 `subl` 命令。安装到 PATH 后可以直接运行：

```bash
mdreview README.md
mdreview docs
mdreview docs --new-window
```

打开单个 Markdown 文件时会隐藏文件目录入口，只保留目录导航和正文；打开目录时文件目录默认收起为左侧边缘入口，鼠标移到左侧或点击入口可临时展开，也可以固定为可拖拽的文件栏。当前文档的目录导航放在正文左侧，支持显示、隐藏和拖拽调整宽度。文件变化会自动刷新当前预览。

App 菜单使用中文，并覆盖命令行可操作的常用能力：打开文件、打开目录、新窗口、关闭标签页、刷新、显示或隐藏文件列表、显示或隐藏目录导航，以及打开设置。

## 开发

```bash
npm run typecheck
npm test
npm run test:native
npm run build:app
```

native 构建脚本默认使用 `/Applications/Xcode.app/Contents/Developer`，避免系统 `xcode-select` 仍指向 Command Line Tools 时找不到 `XCTest`。
