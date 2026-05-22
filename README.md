# mdreview

Lightweight local Markdown previewer.

## Usage

```bash
mdreview README.md
mdreview docs
mdreview docs --no-open
mdreview docs --port 4010
```

Single-file mode hides the file tree and refreshes automatically when the file changes. Directory mode shows Markdown files, the rendered document, and an outline.

The local server binds to `127.0.0.1` and protects file APIs with a per-session token.
