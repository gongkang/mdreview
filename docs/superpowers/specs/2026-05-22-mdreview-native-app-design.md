# mdreview Typora-style 原生 App 设计

日期：2026-05-22

## 背景

当前 MVP 已实现 `mdreview <file-or-directory>` CLI、本地 HTTP server、浏览器端 Markdown 预览 UI、目录文件树、右侧大纲、单文件自动刷新、GFM、代码高亮、Mermaid 和数学公式渲染。

用户反馈当前体验“不像一个软件”，核心问题不是 Markdown 渲染能力，而是启动后进入浏览器 tab，整体更像网页工具。新的产品方向是参考 Typora：mdreview 应该是一个 macOS 原生 App，CLI 只是它的命令入口，类似 Sublime Text 的 `subl`。

Typora 的公开资料显示，macOS 版深度集成系统 document-based app 能力，并使用系统 WebView / WKWebView 路线来获得较小包体和较快启动，而不是在 macOS 上优先使用 Chromium 或 Electron。Windows / Linux 版历史上使用 Electron。参考：

- <https://support.typora.io/Typora-on-macOS/>
- <https://support.typora.io/What%27s-New-0.9.73/>
- <https://support.typora.io/What%27s-New-0.9.66/>
- <https://support.typora.io/Launch-Arguments/>

本设计采用同类思路：**原生 macOS App 外壳 + WKWebView Markdown 渲染内核 + CLI open request 入口**。

## 目标

- `mdreview.app` 是主产品形态，具备原生窗口、菜单、tabs、设置和 macOS 生命周期。
- `mdreview <path>` 是命令入口，只负责把打开请求交给 App。
- 默认体验不再打开浏览器 tab。
- 保留当前 Web renderer 的 Markdown 能力，避免首版重写 Mermaid、math、GFM、sanitize 和代码高亮。
- 保持轻量和启动快，避免 Electron 自带 Chromium。
- CLI 能操作的主要行为，在 App 菜单或 Settings 中也能找到对应入口。

## 非目标

- 不做全 Swift 原生 Markdown/Mermaid/math 渲染。
- 不在第一版实现跨平台桌面 App。
- 不保留面向用户的浏览器 URL、`--port`、`--no-open` 作为主要体验。
- 不在第一版实现 Markdown 编辑器。
- 不实现复杂项目配置、全文搜索、导出 PDF/HTML、主题市场。

## 推荐技术路线

### macOS App 层

使用 Swift + AppKit 为主，必要时用 SwiftUI 承载 Settings 页面。

AppKit 更适合第一版处理：

- 多窗口。
- 原生 tab 行为。
- 菜单栏。
- NSOpenPanel。
- window restoration。
- CLI open request 的生命周期协调。
- NSSplitView / sidebar 宽度拖拽。

SwiftUI 可用于设置页，因为设置表单状态简单，维护成本低。

### Markdown 渲染层

继续复用当前 TypeScript / React Markdown renderer，但职责收缩为“文档渲染组件”：

- 输入：Markdown 内容、资源根路径、渲染配置、当前滚动位置。
- 输出：outline、滚动位置变化、链接点击、渲染错误事件。
- 不再负责 session 初始化、文件读取、tabs、workspace、URL token 或本地 API 路由。

渲染层运行在 App 内部 `WKWebView` 中，作为 bundle 内资源加载。文件内容由原生层读取后通过 `WKScriptMessageHandler` 或 `evaluateJavaScript` 传入，而不是让 WebView 直接通过 HTTP API 读取本地文件。

### CLI 层

`mdreview` 是一个轻量 shim：

1. 解析参数和路径。
2. 校验路径是否存在，且是文件或目录。
3. 如果 App 未运行，自动启动 `mdreview.app`。
4. 通过本机 IPC 把 open request 发送给 App。
5. App 确认接收后 CLI 退出。

第一版 IPC 采用本机 Unix domain socket：

- App 启动后在当前用户可访问的 runtime 目录创建 socket。
- CLI 通过 socket 发送 JSON open request。
- App 返回 ack，包含 accepted、focused、opened、error 等结果。
- CLI 收到 ack 后退出。

不选自定义 URL scheme 作为 MVP 主通道，因为它缺少可靠回执，不利于 CLI 给出明确错误。XPC 可作为后续增强，但不是第一版要求。

## CLI 行为

支持：

```bash
mdreview <file-or-directory>
mdreview <file-or-directory> --new-window
mdreview --help
mdreview --version
```

行为规则：

- `mdreview README.md`：在当前活跃窗口打开文件 tab；没有窗口则创建新窗口。
- 如果同一文件已经在任一窗口 tab 中打开，则聚焦对应窗口和已有 tab，不创建重复 tab。
- `mdreview docs`：默认复用当前活跃窗口并替换 workspace；没有窗口则创建新窗口。
- `mdreview docs --new-window`：强制新建 workspace 窗口。
- 路径不存在时，CLI 在终端报错，不唤起 App。
- CLI 发送 open request 失败时，自动启动 App 后重试一次；仍失败则报错。

移除或内部化：

- `--port`：不再作为用户参数，因为用户不直接面对本地 server。
- `--no-open`：不再作为用户参数，因为 App 本身就是打开目标。

## App 菜单和 Settings

CLI 能控制的用户可见行为，需要在 App 里有对应入口。

菜单：

- `File > Open File...`：打开 Markdown 文件为 tab。
- `File > Open Folder...`：打开目录 workspace，默认替换当前窗口。
- `File > Open Folder in New Window...`：对应 `mdreview docs --new-window`。
- `File > Close Tab`
- `File > Close Window`
- `View > Show/Hide Files`
- `View > Show/Hide Outline`
- `View > Reload Current Document`
- `Window`：使用系统标准窗口和 tab 行为。
- `mdreview > Settings...`

Settings MVP 项：

- 打开目录时默认复用当前窗口或新开窗口，默认复用。
- 是否自动刷新单文件 tab，默认开启。
- 是否恢复上次窗口，默认关闭。
- Files 和 Outline 默认宽度。
- 是否显示 Files 层。
- 是否显示 Outline 层。

## 窗口和 UI 模型

窗口采用 Typora / Sublime 之间的折中模型：原生窗口 + tabs + 左侧双层导航 + WKWebView 正文阅读区。

布局：

- 顶部：原生 tab bar。
- 左侧第一层：Files。
- 左侧第二层：Outline。
- 右侧：正文阅读区。

目录 workspace：

- Files 显示当前目录下的 Markdown 文件树，只展示 `.md` 和 `.markdown`，大小写不敏感。
- 默认跳过 `.git`、`node_modules`、`dist`、`build` 等重目录。
- 点击文件树文件：打开新 tab；如果已经打开则聚焦已有 tab。
- `mdreview docs` 默认替换当前窗口 workspace；`--new-window` 新开窗口。

单文件模式：

- 没有 workspace 时隐藏 Files。
- Outline 仍显示当前 active tab 的大纲。
- 如果窗口已有 workspace，单文件打开为该窗口的 tab，不替换 workspace。

宽度：

- Files、Outline、正文之间支持拖拽调整宽度。
- 宽度保存在 App 本地偏好中。
- MVP 需要设置合理最小宽度，避免正文或导航被拖到不可用。

## App 状态模型

App 原生层维护长期状态：

- window id。
- workspace root，可为空。
- tab 列表。
- active tab。
- 每个 tab 的 file path、display name、mtime、dirty/deleted/error 状态。
- 每个 tab 的滚动位置。
- 当前 outline。
- Files / Outline 显示状态和宽度。
- 最近打开的文件和目录。
- watcher 状态。

Tab 去重：

- 使用 canonical realpath 作为 tab identity。
- 同一路径重复打开时聚焦已有 tab。
- 文件不存在或 realpath 失败时按错误路径展示失败，不创建无效 tab。

## 数据流

### CLI 打开文件

1. 用户运行 `mdreview README.md`。
2. CLI 解析并校验路径。
3. CLI 启动或定位正在运行的 App。
4. CLI 发送 `{ kind: "openFile", path, newWindow: false }`。
5. App 先全局查找已打开的同一 realpath tab；存在则聚焦对应窗口和 tab。
6. 如果不存在，App 选择当前活跃窗口；没有窗口则创建窗口。
7. App 创建 tab。
8. App 读取文件内容，发送给 WKWebView renderer。
9. Renderer 返回 outline，App 更新左侧 Outline。

### CLI 打开目录

1. 用户运行 `mdreview docs`。
2. CLI 发送 `{ kind: "openDirectory", path, newWindow: false }`。
3. App 默认复用当前活跃窗口，替换 workspace；没有窗口则创建新窗口。
4. App 扫描 Markdown 文件树。
5. App 选择默认文档：根目录 README 优先，否则按相对路径排序的第一个 Markdown 文件。
6. 默认文档打开为 tab。
7. Files 显示目录树，Outline 显示 active tab 大纲。

### 新窗口打开目录

1. 用户运行 `mdreview docs --new-window` 或菜单 `Open Folder in New Window...`。
2. App 创建新窗口。
3. 新窗口绑定该 workspace。
4. 默认文档打开为 tab。

### 文件刷新

- 单文件 tab 默认监听文件变化。
- 文件变化后，App 重新读取内容。
- App 向 renderer 发送新内容。
- Renderer 尽量恢复滚动位置，并返回新 outline。
- 文件被删除时，tab 保留并显示“文件不存在”状态。

## Renderer Bridge

原生层和 WKWebView 通过明确消息边界通信。

Native -> Renderer：

- `renderDocument`: `{ path, name, content, scrollPosition?, options }`
- `updateTheme`: `{ colorScheme }`
- `scrollToHeading`: `{ id }`

Renderer -> Native：

- `outlineChanged`: `{ items }`
- `scrollChanged`: `{ path, scrollPosition }`
- `linkClicked`: `{ href }`
- `renderError`: `{ path, blockId?, message }`

安全要求：

- Renderer 仍执行 HTML allowlist sanitization。
- Mermaid 仍使用严格安全模式。
- 原生层不允许 WebView 任意读取本地文件。
- 本地图片或资源路径必须经原生层解析和授权。
- 不暴露用户可见的 tokenized browser URL。

## 与现有 MVP 的迁移关系

保留：

- Markdown renderer 的 GFM、sanitize、highlight、Mermaid、math 能力。
- 文件树扫描规则。
- 路径 realpath containment 思路。
- 现有 tests 中与 renderer、文件扫描、安全边界有关的用例。

重构：

- `src/web/App.tsx` 从完整 browser app 收缩为文档 renderer shell。
- `/api/session`、`/api/files`、`/api/document` 不再作为 App 内主数据通道。
- CLI 从“启动本地 HTTP server + open browser”改为“启动 App + 发送 open request”。

移除或弱化：

- 浏览器 URL token 对主体验不再必要。
- `--port`、`--no-open` 不再作为用户参数。
- browser E2E 测试需要替换为 renderer 测试和 App 集成测试。

保留作为开发 fallback：

- 可以保留 `npm run dev` 或一个 internal preview server 供 renderer 开发使用，但不作为用户文档主路径。

## 错误处理

CLI：

- 路径不存在：输出 `Path does not exist: <path>`，退出非零。
- 路径不是文件或目录：输出明确错误，退出非零。
- App 找不到：提示安装 App 或运行开发安装命令。
- IPC 失败：启动 App 后重试一次；仍失败则输出失败原因。

App：

- 文件读取失败：tab 内显示错误状态，保留其他 tabs。
- 目录扫描失败：窗口显示 workspace 错误，不关闭窗口。
- 文件删除：tab 显示“文件不存在”，用户可关闭 tab 或重新定位。
- 渲染块失败：只在对应块显示错误，正文其他部分继续显示。
- 设置保存失败：使用 macOS 标准 alert 或 inline 状态提示。

## 测试策略

CLI 单元测试：

- 参数解析。
- 路径校验。
- `--new-window`。
- App 启动失败。
- open request 发送失败和重试。

原生 App 测试：

- open request 路由。
- 目录默认复用窗口。
- `--new-window` 新建窗口。
- 单文件打开 tab。
- 重复文件聚焦已有 tab。
- workspace 替换。
- Files / Outline 宽度持久化。
- Settings 默认值和更新。

Renderer 测试：

- GFM。
- sanitize。
- code highlight smoke。
- Mermaid smoke。
- math smoke。
- outline extraction。
- render bridge 输入输出。

集成测试：

- 模拟 CLI open request，验证 App window/tab/workspace 状态。
- 从菜单打开文件和目录，验证行为与 CLI 一致。
- 文件变化触发 tab refresh。

手动验收：

- Finder 双击 App 后可用菜单打开文件。
- `mdreview README.md` 自动启动 App 并打开 tab。
- `mdreview docs` 复用当前窗口并替换 workspace。
- `mdreview docs --new-window` 创建新窗口。
- 同一文件重复打开聚焦已有 tab。
- 左侧 Files / Outline 可拖拽调整宽度。

## 阶段切分

### Phase 1: 原生 App 壳和 CLI handoff

- 创建 macOS App 工程。
- App 能启动窗口。
- CLI 能启动 App 并发送 open request。
- 支持打开单文件为 tab。

### Phase 2: WKWebView renderer 内嵌

- 将当前 renderer 打包为 App 内资源。
- Native -> WKWebView 传 Markdown 内容。
- WKWebView -> Native 返回 outline。
- 保留 GFM、sanitize、highlight、Mermaid、math。

### Phase 3: workspace、tabs、双层左侧导航

- 目录 workspace。
- Files 文件树。
- Outline 左侧第二层。
- 文件点击打开 tab。
- 重复 tab 聚焦。
- 可拖拽宽度。

### Phase 4: 菜单、Settings、刷新和验收

- File/View/Window/Settings 菜单。
- Settings 页面。
- 文件 watcher。
- 状态持久化。
- App/CLI/renderer/integration 测试。

## 开放风险

- Swift/AppKit 与 TypeScript renderer 的构建链需要清晰分层，避免开发命令复杂化。
- WKWebView 对本地资源加载、安全策略、字体和 Mermaid 渲染可能有差异，需要早期 spike 验证。
- App 原生测试和 CI 在 macOS 环境下的可执行性需要单独规划。
- 如果 CLI/App IPC 选择过轻，可能影响 request ack 和错误反馈；实现计划中需要先做小型 spike。
