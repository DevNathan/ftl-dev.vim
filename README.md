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

### Manual directive completion

With a FreeMarker buffer in Insert mode, type `<#assig`, press `Ctrl-X`, then `Ctrl-O`, and accept `assign` with `Ctrl-Y` after selecting it. Square-bracket directive names work the same way. The runtime supplies these names locally. Completion for variables, functions and built-ins uses a configured language server.

### Mixed HTML and SQL templates

Vim and Neovim use the same syntax rules for HTML elements, attributes, entities and FTL expressions. With syntax enabled, typing `</` completes the innermost open HTML element or FTL block. Void elements such as `br` and self-closing tags are skipped.

In angle-bracket templates, the bodies of `<#assign sqlOrders>`, `<#local SQLQuery>` and `<#global sqlText>` highlight SQL. Use `<#-- @lang sql -->` directly before a capture with a different name. Blank lines between the marker and opener are allowed. SQL strings support doubled single quotes and FTL interpolation. Parameters such as `@customerId` and `@고객` have their own highlight group. Ordinary captures and inline assignments retain their FTL or text highlighting.

To edit the same sample in either development profile, run from this repository:

```sh
bash test/dev.sh vim test/vendor/playground/mixed.ftl
bash test/dev.sh nvim test/vendor/playground/mixed.ftl
```

The launcher creates the writable copy on first use. With the sibling VSIX checkout and its extension test dependencies installed, `node test/compare-embedded.mjs` checks the upstream HTML and SQL grammar fixtures in TextMate and both editors.

### Linked FTL tag names

Edit either name in a paired FreeMarker tag to update the other as you type. Both editors use the same Vimscript, including for dotted names such as `<@ns.tag>…</@ns.tag>` and `[@ns.tag]…[/@ns.tag]`. An insert followed by `Esc` and `u` restores both names. `Ctrl-R` reapplies the change. The feature works without a language server. Set `let g:ftl_dev_linked_editing = 0` before opening a template to disable it.

From this repository, open the writable example in either profile.

```sh
bash test/dev.sh vim test/vendor/playground/linked-tags.ftl
bash test/dev.sh nvim test/vendor/playground/linked-tags.ftl
```

On the first line, place the cursor on the `t` of `ns.tag` and type `ciwcard`. The third line becomes `</@ns.card>` while you are still in Insert mode. Press `Esc`, then `u`. Try the same edit from the closing tag on line 3 or the square-bracket closer on line 4.

### Delimiters and selections

The development profiles pair parentheses, square brackets, braces and both quotes as you type. Type the generated closer to move past it, or use Backspace between the empty pair. With syntax enabled, ordinary delimiters pair in code and remain literal inside strings and comments.

In the mixed template, select `title` with `viw` and press `(` to wrap it as `(title)`. Characterwise and linewise selections support all five openers on editors with `getregionpos()`. The runtime leaves these general mappings opt-in so existing pairing plugins and Visual shortcuts can own the keys. Set `let g:ftl_dev_delimiter_pairs = 1` before opening an FTL buffer to enable them in a personal configuration.

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

## Try the local checkout on Linux or macOS

Run these from this repository. Each command starts your installed editor with the development profile and opens an editable copy of the same two-file example.

```sh
bash test/dev.sh vim
bash test/dev.sh nvim
```

The copies live in `test/vendor/playground/` and retain your edits. Pass a path after the editor name to open your own template. On a fresh workspace, build the sibling server with `npm ci` and `npm run compile` in `../vsix/server`. Set `FTL_DEV_SERVER` to use another compiled CLI. The Vim profile fetches a pinned yegappan/lsp checkout under `test/vendor/` on first use. The Neovim profile uses the built-in client.

| Try it in main.ftl | Vim | Neovim 0.12 |
|---|---|---|
| Jump from `lib.greet(title)` to its definition and return | `gd`, then `Ctrl-O` | Same |
| Read docs on `has_content` | `K` | `K` |
| Complete a built-in after `title?` in insert mode | `Ctrl-X Ctrl-O` | `Ctrl-X Ctrl-O` |
| Rename `title` under the cursor | `:LspRename heading` | `grn`, then enter `heading` |
| List references / file symbols | `:LspShowReferences` / `:LspOutline` | `grr` / `gO` |
| Search even unopened templates | `:LspSymbolSearch greet` | `:lua vim.lsp.buf.workspace_symbol("greet")` |
| Fold / reopen the current block | `zc` / `zo` | Same |

Completion in both development profiles is manual. Type `<#`, then press `Ctrl-X Ctrl-O` for up to five visible rows of names. `Ctrl-E` dismisses the menu. Use `K` in Normal mode for documentation.

On either editor, type `<#if title?has_content>` on a blank line and press Enter between the tags. The body should be one shiftwidth deeper. Try `<#assign n = 6 / 2>` to check division. To test strict variables, start either launcher with `--cmd "let g:ftl_dev_init_options = {'strictVariables': v:true}"` and a file path. The server also accepts `dataModel` (a list of names) and `ftldoc.validateParams` (a boolean inside the `ftldoc` dictionary).

For an ordinary Neovim configuration, call `require("ftl_dev.lsp").setup({ cmd = { "node", "/absolute/path/to/cli.js", "--stdio" } })`. The optional `init_options` field takes the same settings. For Vim 9, the server registration and options are in [test/dev.vim](test/dev.vim). The runtime also provides an optional fold expression. Enable it in a FreeMarker window with `:setlocal foldmethod=expr foldexpr=ftl_dev#fold#level(v:lnum) foldlevel=99`.

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
3. Vader editing suite in Vim and Neovim on the bash runner, plus Neovim Lua setup tests.

With sibling checkouts and a compiled server, `bash test/lsp-smoke.sh` also tests the real stdio clients against a temporary workspace.

Before committing, run `bash test/check-forbidden-terms.sh` (forbidden-terms guard; the term list lives outside the repo and is supplied via `FTL_DEV_FORBIDDEN_TERMS` / `FTL_DEV_FORBIDDEN_TERMS_FILE`; without a list it prints `no term list; skipped`).

## Versioning / release

1. Bump [`VERSION`](VERSION) and [`CHANGELOG.md`](CHANGELOG.md)
2. Commit on `main`
3. Create the annotated release tag with `git tag -a vX.Y.Z -m "Release vX.Y.Z"`.
4. Push the intended branch and tag together with `git push --atomic origin main vX.Y.Z`.

A version tag triggers the Vim and Neovim tests. After they pass, GitHub Actions checks the tag against `VERSION` and publishes a GitHub Release using that version's changelog entry. The tagged source contains the installable Vim runtime.

Version: see [`VERSION`](VERSION). Updates: re-pull with your plugin manager (`PluginUpdate` / `PlugUpdate` / …).

## License

Apache-2.0 — [LICENSE](LICENSE).
