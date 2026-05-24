# mdreview Split Layout Design

## Scope

Improve the native macOS window layout for Markdown preview:

- Folder mode uses three columns: file list, outline, document.
- Single-file mode hides the file list and uses two columns: outline, document.
- Default column sizing is proportional to the current window width.
- Column dividers are draggable.
- Dragged widths apply only to the current window and are not persisted.

This spec does not change Markdown parsing, rendering fidelity, file watching, tab behavior, or command-line arguments.

## Current Problem

The native app already uses an `NSSplitView`, but the file list and outline widths are controlled by fixed width constraints from settings. That makes the initial proportions feel cramped and can prevent normal divider dragging because Auto Layout keeps pushing the sidebars back to their configured constants.

The settings page also exposes default file and outline widths. Those pixel settings conflict with the new desired behavior: a predictable default ratio that adapts to the window width.

## Approved Defaults

Folder mode default ratio:

- File list: `17%`
- Outline: `14%`
- Document area: `69%`

Single-file mode default ratio:

- Outline: `16%`
- Document area: `84%`

These ratios are applied when a window first receives a folder or file layout. The document area remains the primary region and should get most of the width.

## Dragging Behavior

Use native `NSSplitView` divider behavior.

- In folder mode, users can drag both dividers: file list / outline and outline / document.
- In single-file mode, users can drag the outline / document divider.
- The app should not add custom minimum or maximum width rules.
- If a user drags a column very narrow, the content in that column may clip, truncate, or scroll according to the existing sidebar and renderer behavior.
- Dragged widths are per-window and temporary.
- Opening a new window, reopening a folder, or restarting the app restores the approved default ratio.

## Architecture

`MainWindowController` remains responsible for constructing the window and coordinating layout mode changes.

The design should replace fixed sidebar width constraints with split-view positioning logic:

- Build the same arranged subviews: file list, outline, renderer.
- When applying `.filesOutlineAndDocument`, make all three views visible and set divider positions from the folder ratio.
- When applying `.outlineAndDocument`, hide or collapse the file list and set the outline/document divider from the single-file ratio.
- Do not bind divider positions to `AppSettings.filesWidth` or `AppSettings.outlineWidth`.

`SidebarController` should remain focused on rendering file and outline rows. It should not own layout ratios or persistence.

## Settings

The settings UI should no longer present "file sidebar default width" or "outline default width" as active user controls, because default sizing is now ratio-based and not persisted.

For implementation compatibility, the existing settings fields can remain in `AppSettings` temporarily if removing them would cause unnecessary migration churn. They should not control the split layout. A later cleanup can remove unused persisted keys once the rest of settings is revisited.

Existing visibility actions such as showing or hiding the file list and outline remain separate from the default ratio behavior.

## Data Flow

1. The app opens a file or folder and produces a `WindowModel`.
2. `MainWindowController.apply(windowModel:)` updates tabs, sidebars, and renderer content.
3. After the split view has a valid size, `MainWindowController` applies the default ratio for the current `LayoutMode`.
4. The user may drag dividers. The split view updates the current window only.
5. The app does not write the dragged widths to `SettingsStore`.

The default ratio should be applied on layout-mode changes and new window setup, not continuously during every resize. A resize should preserve the user's current split proportions as much as native `NSSplitView` normally does.

## Error Handling

If the window is too narrow, no custom error state is needed. The split view and existing scroll views handle overflow. The renderer should remain present even if the user drags sidebars wide enough to leave little document space.

If divider positioning runs before the split view has a real width, defer the ratio application until the next layout pass instead of calculating from zero width.

## Testing

Native layout tests should cover:

- Folder mode starts with three visible split columns.
- Folder mode initial widths approximate the `17 / 14 / 69` ratio for a known window width.
- Single-file mode hides the file list and starts with outline/document widths near `16 / 84`.
- Programmatic divider movement is not immediately reset by fixed width constraints.
- Settings width values do not affect the default split positions.
- Existing sidebar row rendering, outline selection, and tab tests continue to pass.

Manual verification should cover:

- Open `mdreview docs/superpowers --new-window` and drag both dividers.
- Open `mdreview README.md --new-window` and drag the outline/document divider.
- Close and reopen to confirm dragged widths are not persisted.
- Confirm the Settings window no longer suggests pixel sidebar defaults are active.
