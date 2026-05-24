# mdreview Hover Drawer and Outline Navigation Design

## Scope

Replace the divider-centered sidebar collapse controls with a lighter navigation model:

- The file directory becomes a left-edge hover drawer by default.
- The file directory can be pinned into a persistent, resizable pane when the user wants a workspace-style view.
- The outline becomes document navigation, visually grouped with the reading content instead of treated as a second heavy sidebar.
- The outline is shown or hidden with a small content-area directory icon.
- The outline and document are separated by a short, subtle vertical rule rather than a full-height split divider.

This design supersedes the prior divider-centered collapse-button interaction from `2026-05-24-mdreview-sidebar-collapse-design.md`. It does not change Markdown rendering, file scanning, tab behavior, command-line arguments, native menus, settings persistence, or the existing command-line entry.

## Current Problem

The current file-directory and outline controls are both tied to split dividers. That makes the UI feel like three equal structural panes:

1. File directory
2. Outline
3. Document

This is technically clear, but visually too heavy for a GitBook-like reader. It also creates interaction ambiguity because divider areas now serve two roles: dragging width and clicking collapse controls.

The improved design should make the roles explicit:

- File directory is for switching files and should stay out of the reading flow unless needed.
- Outline is for navigating the current document and should feel connected to the document.
- Split dragging and visibility toggles should not compete for the same target.

## Design Principles

- Default to reading, not file management.
- Keep file switching fast without permanently spending horizontal space.
- Keep the outline close to the document because it describes the current document.
- Use quiet native controls and minimal separators.
- Preserve optional power-user behavior: pinned file directory and draggable widths.

## Folder Mode

Folder mode has three logical areas:

1. File directory drawer
2. Outline navigation
3. Document content

The default state is:

- File directory is collapsed into a narrow left-edge trigger area.
- Outline navigation is visible beside the document.
- Document content receives the remaining width.

The left-edge trigger area should be narrow enough to read as an affordance, not a full pane. A practical target is `44-56px`.

## File Directory Drawer

The file directory is no longer a normal expanded split pane by default.

### Collapsed Default

When the file directory is not pinned:

- The app shows a narrow left-edge trigger area.
- The trigger area contains a quiet file/directory icon.
- Moving the mouse into the trigger area opens the file directory drawer.
- The drawer overlays the left side of the window instead of pushing the document layout.
- Moving the mouse away closes the drawer if it is not pinned.

This avoids content reflow during quick file switching.

### Hover Drawer

When opened by hover:

- The drawer appears over the left side of the window.
- It contains the file tree and the current file selection.
- It has a header labeled `文件`.
- The header exposes compact icon buttons for:
  - `固定`: convert the temporary drawer into a persistent, resizable file pane.
  - `展开`: open the file drawer from the edge trigger or widen a compact drawer to its normal drawer width.
  - `收起`: close the temporary drawer; if the pane is pinned, return it to the left-edge collapsed state.

The hover drawer should use a light shadow and a one-pixel right border so it reads as temporary overlay UI.

### Pinned File Pane

When the user pins or expands the file directory:

- The file directory becomes a persistent left pane.
- The pane participates in the layout and can be resized by dragging its right edge.
- The pinned width is remembered for the current window session.
- Unpinning returns the file directory to the left-edge hover drawer.
- The header continues to show `固定`, `展开`, and `收起`, but the active state should be visually clear through tooltip text and icon state.

Pinned mode is for workspace browsing. The default collapsed mode is for reading.

## Outline Navigation

The outline is treated as document navigation, not as a second file-management sidebar.

When visible:

- It sits immediately to the left of the document content.
- It is visually grouped with the document area.
- It has a compact label such as `目录导航` or just `目录`.
- It uses subdued text and active-state emphasis similar to GitBook navigation.
- It is separated from the document by a short, subtle vertical rule, not a full-height divider strip.

The short vertical rule should start near the top of the document reading area and cover only the visually relevant navigation range. It should not imply a draggable split divider by itself.

## Outline Visibility Control

The outline is shown or hidden with a small directory/list icon in the content area.

Placement:

- In the document content top-left blank area.
- Near the outline/document boundary when the outline is visible.
- Still visible at the document top-left when the outline is hidden.

Behavior:

- Clicking the icon hides the outline if visible.
- Clicking the icon shows the outline if hidden.
- The icon should have a Chinese accessibility label and tooltip, such as `显示目录` or `隐藏目录`.

This follows the user's intended interpretation: the icon controls whether document navigation is visible.

## Single-File Mode

When opening a single Markdown file directly:

- The file directory is not shown.
- No file-directory hover trigger is shown.
- The outline navigation can still be shown or hidden with the content-area directory icon.
- The default can keep the outline visible when the file has headings.
- If the file has no headings, the outline area may remain hidden while the directory icon stays available.

Single-file mode must not reveal the file directory because there is no workspace tree to browse.

## Menu Behavior

Native app menus remain Chinese.

Existing menu commands should map to the new model:

- `显示/隐藏文件列表` toggles between pinned file pane and left-edge drawer in folder mode.
- In single-file mode, the file-list command is disabled or no-ops because file browsing is not available.
- `显示/隐藏大纲` toggles the outline navigation using the same state as the content-area directory icon.
- `设置` and `退出` remain in the app menu as previously planned.

The menu is a secondary access path. The visible icon controls are the primary interaction.

## Layout and Sizing

Default folder-mode layout:

- File directory: left-edge trigger area, not a full pane.
- Outline navigation: about `18-22%` of window width or an equivalent fixed starting width around `220-260px`.
- Document content: remaining width.

Pinned folder-mode layout:

- File directory: restored from the current window session, or default around `22-26%`.
- Outline navigation: restored from the current window session, or default around `18-22%`.
- Document content: remaining width.

Single-file layout:

- Outline navigation: default around `18-22%` if visible.
- Document content: remaining width.

Expanded panes should remain user-resizable. Do not introduce custom hard min/max limits beyond native split-view behavior unless AppKit requires a small technical floor to prevent invalid frames.

## Architecture

`MainWindowController` remains responsible for high-level layout mode and state transitions:

- Folder mode vs single-file mode
- File directory drawer state: collapsed, hover-open, pinned
- Outline visibility state
- Restoring current-window widths when moving between pinned and unpinned states

`SidebarController` should continue to own file tree and outline rendering, but the visual responsibilities should be separated:

- File directory view for workspace file browsing
- Outline navigation view for current-document navigation

The implementation can still use `NSSplitView` for persistent panes, but the hover drawer should be an overlay view rather than a split arranged subview. This keeps hover-open file browsing from resizing the document.

The renderer remains responsible for producing outline data from Markdown content. Outline item clicks continue to call `renderer.scrollToHeading`.

## State Model

Use explicit state instead of inferring visibility from raw view width:

- `fileDirectoryMode`: `edgeCollapsed`, `hoverOpen`, `pinned`
- `outlineVisible`: `true` or `false`
- `lastPinnedFileWidth`: current-window optional width
- `lastOutlineWidth`: current-window optional width

State is per window and not persisted across app launches for this change.

## Interaction Details

File directory:

- Mouse enter on the left-edge trigger opens the hover drawer.
- Mouse exit from the drawer closes it when not pinned.
- Clicking the file icon can also open or close the drawer for users who prefer clicks over hover.
- Selecting a file opens that file and closes the drawer if it is not pinned.
- Pinning keeps the file directory visible and resizable.
- The `收起` action always returns to the edge-collapsed default.
- The `展开` action never toggles the outline; it only affects file-directory visibility or width.

Outline:

- Clicking the content-area directory icon toggles outline visibility.
- Clicking an outline item scrolls the document.
- Hiding and showing the outline should preserve the current window's outline width when possible.

## Error Handling

If the window is too narrow:

- The file directory should prefer the left-edge drawer mode.
- The outline can be hidden to preserve readable document width.
- The content-area directory icon must remain reachable.

If the outline is empty:

- The icon remains available.
- The outline panel can show the existing empty state or remain hidden by default.

If hover tracking is unreliable during rapid mouse movement:

- The drawer should close on a short delay rather than instantly.
- Pinning should cancel hover-close behavior.

## Testing

Native tests should cover:

- Folder mode starts with file directory in edge-collapsed mode.
- Moving into the left-edge trigger opens the file drawer.
- Moving out closes the drawer when it is not pinned.
- Selecting a file from the hover drawer opens the file and closes the drawer.
- Pinning the file directory makes it persistent and resizable.
- Unpinning returns it to edge-collapsed mode.
- Single-file mode does not show the file-directory trigger or drawer.
- Outline visibility toggles from the content-area icon.
- Outline visibility toggles from the menu use the same state.
- Hiding and showing outline restores the previous outline width.
- Folder and single-file modes do not leak file-directory state into each other.

Manual verification should cover:

- Open `mdreview docs/superpowers --new-window`.
- Confirm the default view has no full file directory pane.
- Move the mouse to the far left and confirm the file drawer appears.
- Move the mouse away and confirm the drawer closes.
- Pin the drawer and confirm it becomes persistent and resizable.
- Unpin it and confirm the edge-trigger behavior returns.
- Toggle the outline using the content-area directory icon.
- Confirm the outline/document separator is only a short subtle line.
- Open `mdreview README.md --new-window` and confirm no file-directory trigger appears.
