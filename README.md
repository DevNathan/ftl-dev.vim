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

## Tests

```bash
bash test/run.sh
```

Requires `vim`, `git`, `python3`, and `nvim` (for `lua/ftl_dev/lsp.lua`).

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
