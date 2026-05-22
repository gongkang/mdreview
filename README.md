# mdreview

轻量级 macOS 原生 Markdown 预览器，支持从命令行快速打开文件或目录。

## 使用

```bash
npm run build:app
MDREVIEW_APP_PATH="$PWD/native/dist/mdreview.app" node dist/node/index.js README.md
MDREVIEW_APP_PATH="$PWD/native/dist/mdreview.app" node dist/node/index.js docs --new-window
```

CLI 入口负责把打开请求交给原生 App，体验类似 Sublime Text 的 `subl` 命令。安装到 PATH 后可以直接运行：

```bash
mdreview README.md
mdreview docs
mdreview docs --new-window
```

打开单个 Markdown 文件时会隐藏左侧文件目录；打开目录时左侧显示两层导航：`Files` 文件列表和 `Outline` 大纲。文件变化会自动刷新当前预览。

App 菜单使用中文，并覆盖命令行可操作的常用能力：打开文件、打开目录、新窗口、关闭标签页、刷新、显示或隐藏文件列表、显示或隐藏大纲，以及打开设置。

## 开发

```bash
npm run typecheck
npm test
npm run test:native
npm run build:app
```

native 构建脚本默认使用 `/Applications/Xcode.app/Contents/Developer`，避免系统 `xcode-select` 仍指向 Command Line Tools 时找不到 `XCTest`。
