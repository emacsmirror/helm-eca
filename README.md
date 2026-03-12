[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![MELPA](http://melpa.org/packages/helm-eca-badge.svg)](http://melpa.org/#/helm-eca)

# helm-eca

A tiny [Helm](https://github.com/emacs-helm/helm) frontend for
[ECA (Editor Code Assistant)](https://github.com/editor-code-assistant/eca-emacs).

`helm-eca` is meant as a fast, familiar alternative to the widget/tree UI in
`eca-workspaces`: it gives you a classic Helm selection buffer to jump between
ECA chats and workspaces.

## Features

- One command: `M-x helm-eca`
- Two Helm sources:
  - **ECA chats** (across all running ECA sessions)
  - **ECA workspaces** (ECA sessions)
- Chat actions:
  - Open chat (via ECA display logic)
  - Switch to raw chat buffer
  - Rename chat (sets a buffer-local custom title)
  - Kill chat buffer
- Workspace actions:
  - Open workspace (opens last chat)
  - Create a new chat in workspace
  - Jump to the original `eca-workspaces` buffer (tree view)

## Requirements

- Emacs 28.1+
- Helm
- `eca` (from [eca-emacs](https://github.com/editor-code-assistant/eca-emacs))

## Installation

### MELPA

1. Install `helm-eca` (`M-x package-install RET helm-eca RET`)
2. Add a keybinding (optional):

```elisp
(global-set-key (kbd "C-c e") #'helm-eca)
```

### use-package

```elisp
(use-package helm-eca
  :after helm
  :commands (helm-eca)
  :bind ("C-c e" . helm-eca))
```

### straight.el

```elisp
(straight-use-package
 '(helm-eca :type git :host github :repo "PalaceChan/helm-eca"))
(require 'helm-eca)
```

## Usage

Start ECA normally (e.g., `M-x eca` / open a chat), then run:

```text
M-x helm-eca
```

You'll see:

- **ECA chats**: candidates look like `WORKSPACE • CHAT TITLE [USAGE]`
- **ECA workspaces**: candidates show workspace roots and session status

Tip: If you already run `helm-mode`, note that `eca-chat-select` uses
`completing-read`, so it may already help if all you need is single-session chat
selection. `helm-eca` is still useful because it lists chats across all running
sessions and adds extra actions.

## Customization

These variables are intended for light customization:

- `helm-eca-workspace-display` – how workspace roots are displayed (`basename`, `abbrev`, `full`)
- `helm-eca-separator` – separator between workspace label and chat title
- `helm-eca-show-usage` – show token/cost usage when available
- `helm-eca-loading-indicator` – prefix for chats that are currently streaming
- `helm-eca-buffer-name` – name of the Helm buffer

## Example

```elisp
(setq helm-eca-workspace-display 'abbrev
      helm-eca-show-usage t
      helm-eca-separator " _ ")
```

## Stability / ECA internals

helm-eca is deliberately small, but it currently relies on a few eca-emacs
internals because eca-emacs does not yet expose a stable public API for
"enumerate all chats across all sessions".

In particular, helm-eca uses (or may use) internal variables/struct accessors such as:

- `eca--sessions`
- `eca-vals`
- `eca--session-chats`
- `eca--session-last-chat-buffer`
- `eca--session-workspace-folders`
- `eca--session-status`

These names are not guaranteed stable by upstream. If eca-emacs changes its
internals, helm-eca may need a small update.

If you hit breakage after updating `eca`, please open an issue with:

- your `eca` version
- your `helm-eca` version
- the backtrace (if any)

## License

MIT (see `LICENSE`).
