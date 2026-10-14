# Changelog — ftl-dev.vim

User-facing notes for the **Vim / Neovim** FreeMarker runtime.

Canonical version file: [`VERSION`](VERSION). Independent of the VS Code extension ([ftl-dev](https://github.com/DevNathan/ftl-dev)).

## [Unreleased]

## [0.4.2] - 2026-10-14

### Fixed

- Enter between a nested same-line open/close pair rewrites the closer with the opener indent (no longer left at column 0)

## [0.4.1] - 2026-10-14

### Fixed

- `indentexpr` uses an open-block stack so after nested closers, still-open outer blocks keep body indent (not column 0)
- Enter between a same-line open/close pair places the cursor after opener-indent + one unit (no longer shiftwidth-only pad)
- Enter on a nested open tag indents the body by opener indent + one unit (spaces or tab per `expandtab`)
- Alone-on-line `</` / `[/` rewrite replaces the line with Esc+`cc`+CTRL-U (safe with `softtabstop`)

## [0.4.0] - 2026-10-14

VS Code (ftl-dev) parity release for auto-close, mid-block indent align, and Windows-friendly tests.

### Added

- `<LocalLeader>c` toggles `<#-- … -->` comments (normal + visual; count in normal mode); disable maps with `let g:ftl_dev_comment_maps = 0` in vimrc before opening `.ftl` buffers
- Typing `/` inside an unclosed FTL open tag inserts matching `>` or `]` (e.g. `<#assign r = 10 /` → `/>`)
- Typing `</` / `[/` expands to the matching FTL closer (indent rewrite when alone on the line)
- Typing `>` / `]` on mid-block (`#elseif` / `#else` / `#recover` / `#case` / `#default` / `#sep`) rewrites indent to the controlling opener (VSIX `alignIndentAfterCloser` parity)
- Close tags similarly align indent to their opener
- Windows test runners: `test/run.ps1` (full suite) and `test/dev.ps1` (local rtp smoke)

### Fixed

- Under stock Vim `Comment` (bright blue `#80a0ff`), FTL comments use muted `#6A9955`; named colorschemes still link to `Comment`
- Enter between a same-line open/close pair (`<#assign>`, `<#if>`, `[#list]`, …) splits with one indented body line and does not insert a second closer
- Enter at EOL of an open tag that already has a matching closer later indents the body only (no duplicate `</#…>` / `[/#…]`)
- `>` / `]` auto-close (`after_bracket`) skips when a matching closer already follows on the same line or later in the buffer
- Builtin `?name` match uses `/[?]…/` so Windows Vim NFA does not mishandle `\?`; Vader syntax asserts use `SyntaxAt` (synstack prime) instead of raw `synID`
- `.ftl` ftdetect forces `freemarker` over Vim’s Fluent filetype (`set filetype=` not `setfiletype`)

## [0.3.0] - 2026-10-13

### Added

- Block auto-close (VS Code parity): `>` / `]` pairs closers; Enter on an open-tag line inserts body + `</#…>`
- `let g:ftl_dev_auto_close = 0` to disable

### Fixed

- Comments no longer steal directive highlighting: `<#--` is excluded from `ftlDirective` start (`\#%(--\)\@!`), so words like `rs` inside comments stay Comment

## [0.2.0] - 2026-10-13

First coherent release. Consolidates the 0.1.x hotfix mess into one runtime that loads cleanly and paints correctly on light and dark terminal themes.

### Added

- Vim runtime: `ftdetect`, `syntax`, `indent`, `ftplugin` for FreeMarker (`.ftl` / `.ftlh` / `.ftlx`)
- Nested FTL comments; angle/square directives; `${…}` interpolations
- Layered highlight groups: `#assign` → `ftlDirKeyword`, vars → `ftlIdentifier`, `.method` → `ftlMethod`, `?builtin` → `ftlBuiltin`
- Groups **link to the colorscheme** (`Statement`, `Identifier`, `Function`, `Special`, …) — no hardcoded near-white `guifg`/`ctermfg`
- Optional Neovim LSP helper (`lua/ftl_dev/lsp.lua`) — language server built separately
- Vader + Neovim lua suite with coverage inventory (`bash test/run.sh`)
- Syntax smoke gate (`syntax_smoke.vim`) fails on E866/E475 load errors

### Fixed

- `indentkeys` avoids `[` / `<#` (Vim 8.1 E518); indent helpers in `autoload/ftl_dev/indent.vim`
- Vim NFA: literal `?` for builtins (`\?` is a quantifier); no `[\w]` inside `[]` (not a word class)
- Transparent directive/interpolation regions — not one solid colour slab
- No HTML-base / `matchgroup` steal mid-directive name

## [0.1.3] - 2026-10-13

Superseded by 0.2.0 (layered groups + smoke gate; still used absolute colours).

## [0.1.2] - 2026-10-13

Superseded by 0.2.0 (literal `?` for builtins).

## [0.1.1] - 2026-10-13

Superseded by 0.2.0 (initial runtime + tests).
