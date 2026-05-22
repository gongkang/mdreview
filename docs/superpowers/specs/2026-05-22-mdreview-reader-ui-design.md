# mdreview Reader UI 设计

日期：2026-05-22

## 目标

优化 mdreview 原生 App 的阅读体验，但不改变产品模型：它仍然是一个 macOS 原生 Markdown 预览器，并提供类似 Sublime Text `subl` 的命令入口。

当前 App 已经能渲染 Markdown，但视觉上仍像原型：左侧导航直接使用圆角系统按钮，正文区域还保留网页 demo 风格。本轮设计目标是让它更像一个干净的原生阅读器。

## 视觉方向

采用 Typora / Reader 方向：

- 纯白阅读表面。
- 尽量少的界面 chrome。
- 导航保持可用，但视觉上安静。
- 默认使用长文阅读密度。
- 不使用装饰性渐变、大面积彩色底、卡片化布局或厚重背景。

这次明确选择比 GitBook 文档站更安静的方向。用户打开文件时，感受应该接近“打开一篇文档”，而不是“进入一个网页”。

## 窗口布局

保留现有布局模型：

- 顶部：应用内文档标签。
- 左侧：导航区域。
- 右侧：`WKWebView` Markdown 阅读区。

单文件模式：

- 隐藏 Files。
- 左侧只显示 Outline。
- 不显示 Files 标题，也不显示空的文件面板。

目录模式：

- 左侧显示 Files 和 Outline 两层导航。
- 两层导航使用同一套安静的列表样式。

## 侧栏设计

把侧栏从“按钮列表”改为“文本导航列表”。

Files 和 Outline 行样式：

- 不使用 bezel。
- 不使用圆角系统按钮样式。
- 不使用阴影。
- 固定行高约 24px。
- 文本左对齐。
- 使用 macOS 系统字体，字号约 12-13px。
- 默认文本使用柔和灰色。
- 当前行使用更深文字。
- hover 和 active 只使用非常浅的灰色行背景。
- 标题层级通过缩进表达，不通过嵌套按钮表达。

Outline 行为：

- H1 比更深层级略强，但仍保持克制。
- H2-H6 使用缩进和更浅文本区分层级。
- 没有大纲时显示小号弱提示。
- 当前行语义为“最近一次通过鼠标或键盘选择的大纲项”，用于确认用户刚点击的跳转目标。
- 当前行在切换 tab、重新渲染文档或大纲项消失时清空。
- 本轮不实现随正文滚动自动更新的大纲 scrollspy。后续如果需要 scrollspy，再由 renderer 发送 `currentHeadingChanged` 一类事件给原生层。

Files 行为：

- 目录使用弱标签样式。
- Markdown 文件使用可点击文本行。
- 当前文件行和 Outline 当前行使用一致的 active 视觉语言。
- Files 当前行语义为“当前 active tab 对应的文件路径”。

交互和可访问性：

- 侧栏行可以使用自定义 `NSButton`、`NSControl` 或等价原生控件实现，但不能退化成只带手势的静态 `NSTextField`。
- 需要保留 target/action、键盘激活、可聚焦状态和 VoiceOver 可读 label。
- 视觉上隐藏按钮边框，不等于移除控件语义。
- hover 状态使用 AppKit tracking area 或等价机制实现；如果系统辅助功能设置禁用动画，hover 不应依赖动画才能理解。

## 正文区域设计

正文区域默认偏长文阅读。

默认正文样式：

- 纯白背景。
- Markdown 正文最大宽度约 620px。
- 内容居中。
- 顶部留白比现在更大，约 56px。
- 底部留白约 92px。
- 正文字号约 15px。
- 行高约 1.8-1.9。
- 标题使用较强字重和更舒展的上下间距。
- 段落文字使用深中性灰，不用纯黑。

代码样式：

- 行内代码使用轻微背景或只用等宽强调。
- 代码块使用接近白色的浅灰背景、细边框、适中圆角和舒适内边距。
- 代码块不能成为页面里最抢眼的色块。
- 保留已有语法高亮能力，但代码块表面要更安静。

图片和富 Markdown：

- 图片默认适配阅读列宽。
- 表格必要时可以横向滚动。
- Mermaid 和 math 保持现有能力不变。

## 顶部标签栏

保留应用内文档标签模型，但降低视觉重量。

标签样式：

- 避免圆角按钮感。
- 使用轻量文本标签或低存在感 tab row。
- 当前标签可以用轻微下划线或更深文字表示。
- 非当前标签使用弱文本。
- 标签栏不能像一排工具按钮。

键盘行为：

- `Cmd+W` 关闭当前 tab。
- 如果关闭的是最后一个 tab，则退出 App。

## 架构

这是表现层改动。

原生层：

- `SidebarController` 负责原生导航行构建和选择行为。
- `DocumentTabBar` 负责原生标签栏展示。
- `MainWindowController` 保留现有 split view 和布局模式逻辑。

Web 渲染层：

- `src/web/styles.css` 负责 Markdown 正文样式。
- `RendererApp` 继续把 Markdown 内容交给 `MarkdownView`。
- Markdown 解析和渲染行为不变。
- 原生 WKWebView 的 Reader 样式必须加作用域，例如让 `RendererApp` 输出 `.native-reader` / `.reader-renderer` 根节点，并把正文样式限制在该作用域内。
- 旧浏览器 preview 仍可继续使用现有三栏布局，不能因为本轮 Reader UI 改动被意外改成原生 App 样式。
- 如果有样式确实需要两端共享，必须显式写成共享 Markdown typography，而不是通过全局 `.markdown-body` 选择器隐式影响两套入口。

不引入新的 UI 框架，不替换渲染管线。实现范围应限制在 AppKit 样式和 renderer CSS。

## 测试

原生测试需要覆盖：

- 单文件模式仍然隐藏 Files，只显示 Outline。
- Outline 行可见，并有合理尺寸。
- 侧栏行不再渲染成带边框的系统按钮。
- 侧栏行仍然是可交互控件，并保留 accessibility label。
- 点击或键盘选择大纲项后，该大纲项进入 active 状态；切换文档后 active 状态被清空或更新。
- 关闭最后一个 active tab 仍然会移除窗口并走退出 App 的路径。

Renderer 测试需要覆盖：

- CSS 调整后 Markdown 渲染仍然工作。
- Outline 提取仍然会把 heading 发送给原生层。
- 代码块、表格、图片、Mermaid、math 保持现有行为。
- 原生 renderer 使用 scoped root class，Reader 样式不会影响旧浏览器 preview 的 app shell。

手动验证需要覆盖：

- 打开 `mdreview README.md`。
- 确认单文件模式只显示 Outline + 正文。
- 确认 Outline 行看起来像文本导航，而不是按钮。
- 确认正文区域使用长文阅读间距。
- 用截图或 AX 信息确认正文宽度约 620px、顶部留白约 56px，侧栏行高度约 24px。
- 点击大纲项后确认该行有轻量 active 状态，并且 VoiceOver/Accessibility Inspector 能读出可操作 label。
- 确认 `Cmd+W` 可以关闭 tab / app。
- 打开 `mdreview docs`，确认 Files + Outline 都使用同一套安静导航样式。

## 不在本轮范围

- 改 Markdown 解析行为。
- 添加编辑模式。
- 添加主题选择器。
- 替换 WKWebView。
- 重做 App 状态模型或 CLI 语义。
