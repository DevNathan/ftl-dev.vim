#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
editor=${1:-vim}
case "$editor" in vim|nvim) ;; *) echo 'Usage: dev.sh [vim|nvim] [editor arguments or files...]' >&2; exit 2 ;; esac
if (( $# )); then shift; fi
export FTL_DEV_SERVER=${FTL_DEV_SERVER:-"$root/../vsix/server/out/server/src/cli.js"}
if [[ ! -f "$FTL_DEV_SERVER" ]]; then
  echo "Build the sibling language server with npm ci and npm run compile in vsix/server, or set FTL_DEV_SERVER." >&2
  exit 1
fi
if [[ "$editor" == vim && ! -f "$root/test/vendor/lsp/plugin/lsp.vim" ]]; then
  git clone https://github.com/yegappan/lsp.git "$root/test/vendor/lsp"
  git -C "$root/test/vendor/lsp" checkout --detach 96dec727d06c649e654b1926b02713571ed56888
fi
play="$root/test/vendor/playground"
mkdir -p "$play"
for sample in "$root"/test/fixtures/*.ftl "$root/test/fixtures/.ftl-data-model.json"; do
  target="$play/${sample##*/}"
  if [[ ! -e "$target" ]]; then
    # Publish a complete sample atomically when both editors start together.
    copy=$(mktemp "$play/.sample.XXXXXX")
    cp "$sample" "$copy"
    ln "$copy" "$target" 2>/dev/null || [[ -e "$target" ]]
    unlink "$copy"
  fi
done
if (( $# == 0 )); then set -- "$play/main.ftl"; fi
export XDG_STATE_HOME="$root/test/vendor/state"
export XDG_CACHE_HOME="$root/test/vendor/cache"
exec "$editor" -i NONE -n -u "$root/test/dev.vim" "$@"
