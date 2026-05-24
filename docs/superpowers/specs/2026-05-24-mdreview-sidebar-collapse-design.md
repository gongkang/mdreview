# mdreview Sidebar Collapse Design

## Scope

Add native expand and collapse interactions for the left navigation areas:

- In folder mode, the file list and outline columns can each collapse and expand independently.
- In single-file mode, the file list remains hidden by layout mode, and the outline column can collapse and expand.
- Collapsed columns keep a narrow visible rail so the user can restore the column without using the menu.
- Existing View menu actions for file list and outline use the same collapse and expand behavior.

This does not change Markdown rendering, file scanning, tab behavior, command-line arguments, settings persistence, or the default split ratios approved in the split-layout spec.

## Current Problem

The native app already has menu commands labeled "显示/隐藏文件" and "显示/隐藏大纲", but they directly toggle `isHidden` on the underlying scroll views. That makes the area disappear with no visible affordance to restore it from the window itself.

Users also need a local, discoverable way to recover a navigation region after collapsing it. The app should behave like a native document reader with adjustable panes, not like a temporary visibility hack.

## Approved Interaction

Each collapsible navigation column has two states:

- Expanded: the normal file list or outline content is visible and the split divider can be dragged.
- Collapsed: the column becomes a narrow vertical rail, exactly `28px` wide, with a simple expand button.

The rail stays visible and occupies a small stable width. It should look quiet and native:

- No large labels.
- No decorative background.
- Use a simple chevron-style button or equivalent native button.
- The button has an accessibility label such as "展开文件列表" or "展开大纲".

Clicking the rail button expands the column.

## Folder Mode

Folder mode has three logical columns:

1. File list
2. Outline
3. Document

The file list and outline can be collapsed independently.

When a column collapses:

- Store its current expanded width for that window.
- Set the column to the collapsed rail width.
- Keep the column participating in the split view so the user can see and click the rail.

When a column expands:

- Restore the last stored expanded width for that window.
- If there is no stored width, use the approved default split ratio from the split-layout design.
- Keep the other column and document area in their current relative positions as much as `NSSplitView` allows.

## Single-File Mode

Single-file mode has two visible logical columns:

1. Outline
2. Document

The file list remains hidden because the opened target is a single file. It should not show a collapsed file rail.

The outline column can collapse into a narrow rail and expand back to its previous width. If no previous width exists, use the single-file outline default ratio from the split-layout design.

## Menu Behavior

The existing View menu actions remain:

- "显示/隐藏文件"
- "显示/隐藏大纲"

These actions should call the same collapse and expand logic as the visible rail controls.

Behavior:

- If the relevant column is expanded, the menu action collapses it.
- If the relevant column is collapsed, the menu action expands it.
- In single-file mode, the file-list menu action should not reveal the file list because that layout intentionally has no file list.

The menu labels can remain unchanged for this change. A later polish pass can rename them to more precise labels if needed.

## Layout Rules

The collapsed rail width is fixed at `28px` for interaction stability.

Expanded widths are temporary and per-window:

- User-dragged widths are not written to settings.
- Collapsed and restored widths are not persisted across app restarts.
- Opening a new window starts with the approved default ratios.
- Switching between folder mode and single-file mode applies the existing mode default ratio.

No custom maximum or minimum width rule should be introduced for expanded columns. Existing native split-view behavior continues to handle extreme dragging.

## Architecture

`MainWindowController` should own split-view sizing because it already coordinates layout mode and default ratios.

`SidebarController` should own the visual state of each navigation column:

- Expanded content view for files and outline.
- Collapsed rail view for files and outline.
- Callbacks for rail button clicks.

The split view should continue to have three arranged subviews in this order:

1. File navigation container
2. Outline navigation container
3. Renderer view

Each navigation container can internally switch between expanded content and collapsed rail. This keeps the split-view model stable and avoids removing/re-adding arranged subviews.

## Data Flow

1. A window applies a `WindowModel`.
2. `MainWindowController` applies the default folder or single-file split ratio when required by the existing layout-mode rules.
3. `SidebarController` renders file and outline content.
4. The user triggers collapse or expand from a menu item or rail button.
5. `MainWindowController` stores the current expanded width, updates the sidebar visual state, and moves the relevant divider to the collapsed or restored position.
6. Future document changes in the same layout mode keep the current collapsed or expanded state for that window.

## Error Handling

If the window is too narrow, the collapsed rail still remains visible. The renderer can become narrow according to native split-view behavior.

If a stored width is no longer usable after a window resize, restore to the nearest practical position that keeps the rail or expanded column visible.

If the outline is empty, collapsing and expanding still works; the expanded outline shows the existing empty state.

## Testing

Native tests should cover:

- Folder mode starts with both file list and outline expanded using the approved ratios.
- Collapsing the file list creates a narrow visible rail and keeps the outline and document visible.
- Expanding the file list restores the previous file-list width.
- Collapsing the outline creates a narrow visible rail and keeps the file list and document visible.
- Expanding the outline restores the previous outline width.
- Single-file mode hides the file list completely and allows the outline to collapse and expand.
- Menu toggle actions and rail button actions use the same state transitions.
- Reapplying a `WindowModel` with the same layout mode does not reset collapsed state.
- Switching layout mode applies the existing default-ratio behavior.

Manual verification should cover:

- Open `mdreview docs/superpowers --new-window`, collapse and expand both left regions.
- Drag sidebars, collapse, and expand to confirm the dragged width is restored.
- Open `mdreview README.md --new-window` and confirm only the outline can collapse.
- Confirm the window still feels clean and GitBook-like, without heavy sidebar chrome.
