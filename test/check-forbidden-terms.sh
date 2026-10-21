#!/usr/bin/env bash
# Blocks reintroduction of terms that must not appear in this repository.
#
# The term list is NOT stored in the repo. Sources, first non-empty wins:
#   1. env FTL_DEV_FORBIDDEN_TERMS       regexes (ERE) separated by newline or comma
#   2. env FTL_DEV_FORBIDDEN_TERMS_FILE  path to a file, one regex per line
#   3. <repo>/../.ftl-dev-forbidden-terms (workspace root, outside the repo)
#   4. none -> "no term list; skipped", exit 0
# Blank lines and lines starting with '#' are ignored. Matching is grep -E,
# case-sensitive; binary files are skipped (-I).
#
# Output never contains the matched text or the line: hits are reported as
# `path:line: <redacted term #N>`. Option `--commits <range>` also scans
# commit messages of `git log <range>`.
#
# Exit codes: 0 clean or skipped, 1 hits found, 2 usage / config error.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_FILE="$ROOT/../.ftl-dev-forbidden-terms"

die() { echo "check-forbidden-terms: $1" >&2; exit 2; }

commits=""
while [ $# -gt 0 ]; do
  case "$1" in
    --commits) [ $# -ge 2 ] && [ -n "$2" ] || die "--commits needs a revision range"; commits="$2"; shift 2 ;;
    --commits=*) commits="${1#--commits=}"; [ -n "$commits" ] || die "--commits needs a revision range"; shift ;;
    -h|--help) echo "usage: check-forbidden-terms.sh [--commits <range>]"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

is_set() { [ -n "${1//[[:space:]]/}" ]; }

raw=""; source_desc=""
if is_set "${FTL_DEV_FORBIDDEN_TERMS:-}"; then
  raw="$(printf '%s\n' "$FTL_DEV_FORBIDDEN_TERMS" | tr ',' '\n')"; source_desc="env FTL_DEV_FORBIDDEN_TERMS"
elif is_set "${FTL_DEV_FORBIDDEN_TERMS_FILE:-}"; then
  [ -f "$FTL_DEV_FORBIDDEN_TERMS_FILE" ] || die "term file not found"
  raw="$(cat -- "$FTL_DEV_FORBIDDEN_TERMS_FILE")"; source_desc="env FTL_DEV_FORBIDDEN_TERMS_FILE"
elif [ -f "$DEFAULT_FILE" ]; then
  raw="$(cat -- "$DEFAULT_FILE")"; source_desc="default term file"
fi

terms=()
while IFS= read -r line; do
  line="${line%$'\r'}"
  line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac
  terms+=("$line")
done <<< "$raw"

if [ ${#terms[@]} -eq 0 ]; then
  echo "no term list; skipped"
  exit 0
fi

for i in "${!terms[@]}"; do
  grep -E -e "${terms[$i]}" </dev/null >/dev/null 2>&1
  [ $? -eq 2 ] && die "invalid regex: term #$((i + 1))"
done

hits=0; scanned=0
while IFS= read -r -d '' f; do
  [ -f "$ROOT/$f" ] || continue
  scanned=$((scanned + 1))
  for i in "${!terms[@]}"; do
    while IFS= read -r ln; do
      [ -n "$ln" ] || continue
      echo "$f:$ln: <redacted term #$((i + 1))>"
      hits=$((hits + 1))
    done < <(grep -n -I -E -e "${terms[$i]}" -- "$ROOT/$f" 2>/dev/null | cut -d: -f1)
  done
done < <(git -C "$ROOT" ls-files -z)

ncommits=0
if [ -n "$commits" ]; then
  shas="$(git -C "$ROOT" log --format=%h "$commits" 2>/dev/null)" || die "git log failed for the given --commits range"
  for h in $shas; do
    ncommits=$((ncommits + 1))
    for i in "${!terms[@]}"; do
      if git -C "$ROOT" log -1 --format=%B "$h" | grep -q -E -e "${terms[$i]}"; then
        echo "commit $h: <redacted term #$((i + 1))>"
        hits=$((hits + 1))
      fi
    done
  done
fi

summary="$scanned file(s)"
[ -n "$commits" ] && summary="$summary, $ncommits commit message(s)"
summary="$summary, ${#terms[@]} term(s) from $source_desc"
if [ "$hits" -gt 0 ]; then
  echo "check-forbidden-terms: $hits hit(s) in $summary"
  exit 1
fi
echo "check-forbidden-terms: ok, 0 hits in $summary"
exit 0
