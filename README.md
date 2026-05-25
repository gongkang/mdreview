# mdreview

轻量级 macOS 原生 Markdown 预览器，支持从命令行快速打开文件或目录。

## 使用

```bash
npm run build:app
MDREVIEW_APP_PATH="$PWD/native/dist/mdreview.app" node dist/node/index.js README.md
MDREVIEW_APP_PATH="$PWD/native/dist/mdreview.app" node dist/node/index.js docs --new-window
```

本机安装后可以直接使用 `mdreview` 命令：

```bash
npm run install:local
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
