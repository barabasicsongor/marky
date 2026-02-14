# Marky

A native macOS WYSIWYG Markdown editor. Lightweight, fast, and keyboard-driven.

Marky renders Markdown as you type — headings, bold, italic, lists, and code blocks transform live, so you never see raw syntax. Open `.md` files from Finder, edit with rich formatting, save back as clean Markdown.

## Features

- **Live Markdown transforms** — type `## ` and it becomes a heading, `**text**` becomes bold, `` `code` `` becomes inline code
- **WYSIWYG editing** — see formatted output, not raw markup
- **Tabbed interface** — multiple files open as tabs in one window
- **Command palette** — `Cmd+K` to quickly switch tabs, open files, or run commands
- **Keyboard-first** — `Cmd+1-9` to switch tabs, `Cmd+B`/`Cmd+I` for formatting
- **Finder integration** — right-click any `.md` file → Open With → Marky
- **Dark mode** — automatically adapts to your system appearance
- **Lightweight** — native SwiftUI app, ~70KB of bundled JavaScript (marked.js + turndown.js)

## Supported Formats

| Syntax | Trigger | Result |
|--------|---------|--------|
| `# ` to `###### ` | Space after hashes | Headings H1–H6 |
| `**text**` | Closing `**` | **Bold** |
| `*text*` | Closing `*` | *Italic* |
| `` `text` `` | Closing `` ` `` | `Inline code` |
| `~~text~~` | Closing `~~` | ~~Strikethrough~~ |
| `- ` or `* ` | Space after marker | Bullet list |
| `1. ` | Space after number | Ordered list |
| `> ` | Space after `>` | Blockquote |
| `---` | Third dash | Horizontal rule |
| ` ``` ` | Third backtick | Code block |

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+K` | Open command palette |
| `Cmd+1`–`Cmd+9` | Switch to tab N |
| `Cmd+B` | Bold |
| `Cmd+I` | Italic |
| `Cmd+S` | Save |
| `Cmd+Z` | Undo |
| `Cmd+Shift+Z` | Redo |
| `Cmd+N` | New document |
| `Cmd+O` | Open file |

## Install

### Download

Grab the latest `Marky.app.zip` from [Releases](../../releases), unzip, and drag to your Applications folder.

### Build from source

Requires Xcode and [xcodegen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
git clone https://github.com/barabasicsongor/marky.git
cd marky
xcodegen generate
xcodebuild -project Marky.xcodeproj -scheme Marky -configuration Release -derivedDataPath ./build build
cp -R ./build/Build/Products/Release/Marky.app ~/Applications/
```

## Architecture

Marky is a SwiftUI `DocumentGroup` app that hosts a `WKWebView` with an embedded WYSIWYG editor.

```
Marky/
├── MarkyApp.swift              # App entry point, AppDelegate with global shortcuts
├── MarkdownDocument.swift      # FileDocument for .md/.txt files
├── ContentView.swift           # Document view hosting the editor
├── MarkdownEditorView.swift    # NSViewRepresentable wrapping WKWebView
├── CommandPalette.swift        # Cmd+K command palette (NSPanel)
└── Resources/
    ├── editor.html             # Self-contained WYSIWYG editor
    └── Assets.xcassets/        # App icon
```

**Key dependencies (bundled inline in editor.html):**
- [marked.js](https://github.com/markedjs/marked) — Markdown → HTML
- [turndown.js](https://github.com/mixmark-io/turndown) — HTML → Markdown

## License

[MIT](LICENSE)
