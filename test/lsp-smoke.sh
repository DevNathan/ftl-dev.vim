#!/usr/bin/env bash
# Integration test for sibling checkouts with the compiled language server.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/ftl 한글.XXXXXX")
trap 'rm -rf -- "$scratch"' EXIT
cp "$here"/fixtures/*.ftl "$scratch/"
cp "$here/fixtures/.ftl-data-model.json" "$scratch/"
cd "$scratch"
"$here/dev.sh" vim -es -S "$here/lsp-smoke.vim" main.ftl
"$here/dev.sh" nvim --headless --cmd "let g:ftl_dev_init_options = {'strictVariables': v:true}" -S "$here/lsp-smoke.vim" main.ftl
# Repeat the keyboard test with each development profile and its LSP client.
python3 "$here/linked-editing.py" --dev
