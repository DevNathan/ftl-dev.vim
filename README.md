# ftl-dev.vim

FreeMarker syntax and editing helpers for Vim / Neovim.

When opening a `.ftl` / `.ftlh` / `.ftlx` file the filetype is set to **`freemarker`**, which activates syntax highlighting. The plugin also provides indent rules and a few quick-editing helpers (`commentstring`, matchit words, `${` pairing, `gf` on include/import paths).

This repository is the **source of truth** and the install target for plugin managers. The VS Code / VSIX product lives in a separate repo: [ftl-dev](https://github.com/DevNathan/ftl-dev).

## Installation

### Pathogen

```bash
git clone https://github.com/DevNathan/ftl-dev.vim.git ~/.vim/bundle/ftl-dev.vim
```

### Vundle

Add to your vimrc:

```vim
Plugin 'DevNathan/ftl-dev.vim'
```

Then `:PluginInstall`.

### vim-plug

```vim
Plug 'DevNathan/ftl-dev.vim'
```

Then `:PlugInstall`.

### lazy.nvim (Neovim)

```lua
{ "DevNathan/ftl-dev.vim", lazy = false }
```

## What you get

- Syntax (nested `<#-- -->` / `[#-- --]`, angle/square directives, `${…}`, `?builtins`)
- Indent aligned with `#if` / `#else` / `#recover` / macros
- Filetype helpers for comments and navigation

Highlight groups are **layered** (`ftlDirKeyword`, `ftlIdentifier`, `ftlMethod`, `ftlBuiltin`, …) and **linked to the colorscheme** (`Statement`, `Identifier`, `Function`, `Special`, …). Do not hardcode near-white `guifg` — that vanishes on light terminal themes. Override with `:hi link ftlIdentifier MyGroup` if you want custom colours.

### Auto-close + indent

Block opens (`<#if>`, `<#attempt>`, `<#macro>`, …) get VS Code–style pairing:

- Type `>` (or `]`) on an open tag → inserts `</#…>` and leaves the caret between (skips if a matching closer already exists on the same line or later)
- Press Enter on a finished open-tag line → body line + closer

Indent (`indentexpr`) stays — it is useful once closers exist. Disable pairing with:

```vim
let g:ftl_dev_auto_close = 0
```

Indent follows normal Vim rules via `indentexpr` plus your `shiftwidth` / `expandtab` / `tabstop` / `softtabstop`. The plugin does not invent its own pad characters on Enter.

### Comment toggle

`<LocalLeader>c` toggles FreeMarker comments (`<#-- … -->`) on the current line (normal) or visual selection. In normal mode, a count wraps that many lines from the cursor (e.g. `3<LocalLeader>c`). Leading indent is kept; blank lines are left alone. If every non-blank line in the range is already commented, comments are removed; otherwise only uncommented lines are wrapped (lines already commented stay as-is).

`<LocalLeader>` is `\` by default unless you set `maplocalleader`.

Disable the maps in vimrc (**before** opening a `.ftl` buffer — unlike `g:ftl_dev_auto_close`, this flag is read when the filetype plugin loads):

```vim
let g:ftl_dev_comment_maps = 0
```

## Tests

**Linux / macOS**

```bash
bash test/run.sh
```

**Windows (PowerShell)** — requires `vim`, `git`, and `nvim` on `PATH`:

```powershell
winget install -e --id vim.vim
winget install -e --id Neovim.Neovim
# If `vim` is missing after install, add e.g. %LOCALAPPDATA%\Programs\Vim to User PATH, then open a new shell.
powershell -ExecutionPolicy Bypass -File test/run.ps1
```

Manual smoke (loads this repo on `runtimepath`, opens a sample `.ftl`):

```powershell
powershell -ExecutionPolicy Bypass -File test/dev.ps1
powershell -ExecutionPolicy Bypass -File test/dev.ps1 -Nvim
```

Requires `vim`, `git`, `python3` (bash runner), and `nvim` (for `lua/ftl_dev/lsp.lua`).

The runner:

1. Checks [test/coverage_inventory.json](test/coverage_inventory.json) tags (**100% inventory**)
2. **`syntax_smoke.vim`** — sources `syntax/freemarker.vim` and **fails on E866/E475** (Vim NFA regexp mistakes)
3. Vader suite + Neovim lua tests

## Versioning / release

1. Bump [`VERSION`](VERSION) and [`CHANGELOG.md`](CHANGELOG.md)
2. Commit on `main`
3. Tag `vX.Y.Z` and `git push origin main --tags`

Version: see [`VERSION`](VERSION). Updates: re-pull with your plugin manager (`PluginUpdate` / `PlugUpdate` / …).

## License

Apache-2.0 — [LICENSE](LICENSE).
