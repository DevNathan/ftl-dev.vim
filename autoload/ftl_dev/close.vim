" Auto-close block directives (VS Code closeTag / Enter parity). Lightweight.

let s:always_block = {
      \ 'if':1, 'list':1, 'macro':1, 'function':1, 'attempt':1, 'compress':1,
      \ 'escape':1, 'noescape':1, 'autoesc':1, 'noautoesc':1, 'transform':1,
      \ 'switch':1, 'items':1,
      \ }

let s:mid_block = {
      \ 'else':1, 'elseif':1, 'recover':1, 'case':1, 'default':1, 'sep':1,
      \ }

let s:capture = { 'assign':1, 'local':1, 'global':1 }

" Parse a single-line pairable open tag. Returns {} or
" { 'name': '#attempt', 'open': '<', 'close': '>' }
function! ftl_dev#close#parse_pairable(line) abort
  let t = substitute(a:line, '^\s*', '', '')
  let t = substitute(t, '\s*$', '', '')
  return s:parse_pairable_tag(t)
endfunction

function! s:parse_pairable_tag(t) abort
  let m = matchlist(a:t, '^\([<\[]\)\([#@]\)\([a-zA-Z_][a-zA-Z0-9_.]*\)\>\(.*\)\([>\]]\)$')
  if empty(m)
    return {}
  endif
  let open = m[1]
  let sigil = m[2]
  let name = m[3]
  let rest = m[4]
  let close = m[5]
  if (open ==# '<' && close !=# '>') || (open ==# '[' && close !=# ']')
    return {}
  endif
  if rest =~# '/\s*$'
    return {}
  endif
  if sigil ==# '#' && has_key(s:mid_block, name)
    return {}
  endif
  if sigil ==# '@'
    " user directive — always pair
  elseif has_key(s:always_block, name)
    " ok
  elseif has_key(s:capture, name)
    " Match = / ++ / -- / op= (avoid \\++ — E866 Misplaced + on Vim NFA)
    if rest =~# '[=]\|++\|--\|[+*/%-]='
      return {}
    endif
  else
    return {}
  endif
  return { 'name': sigil . name, 'open': open, 'close': close }
endfunction

function! s:closer_token(open) abort
  return a:open.open . '/' . a:open.name . a:open.close
endfunction

" True when `after` is only the matching closer (optional surrounding space).
function! s:same_line_closer(after, open) abort
  if empty(a:open) || a:after !~# '\S'
    return 0
  endif
  let closer = s:closer_token(a:open)
  let pat = '^\s*' . escape(closer, '[]\.*$^~') . '\s*$'
  return a:after =~# pat
endfunction

function! s:should_pair_close(sigil, name, inner) abort
  if a:sigil ==# '@'
    return 1
  endif
  if has_key(s:always_block, a:name)
    return 1
  endif
  if !has_key(s:capture, a:name)
    return 0
  endif
  let body = substitute(a:inner, '/\s*$', '', '')
  let body = substitute(body, '^\s*', '', '')
  let body = substitute(body, '\s*$', '', '')
  return body !~# '[=]\|++\|--\|[+*/%-]='
endfunction

function! s:apply_ftl_tag(stack, lnum, col, is_close, sigil, name, inner) abort
  let key = a:sigil . a:name
  if a:inner =~# '/\s*$'
    return
  endif
  if a:sigil ==# '#' && has_key(s:mid_block, a:name)
    return
  endif
  if a:is_close
    let i = len(a:stack) - 1
    while i >= 0
      if a:stack[i].name ==# key
        call remove(a:stack, i)
        break
      endif
      let i -= 1
    endwhile
    return
  endif
  if !s:should_pair_close(a:sigil, a:name, a:inner)
    return
  endif
  call add(a:stack, { 'name': key, 'lnum': a:lnum, 'col': a:col })
endfunction

" Push FTL tags from one buffer line onto stack (same bracket style).
function! s:push_line_ftl_tags(stack, lnum, line, open_bracket) abort
  let close_bracket = a:open_bracket ==# '<' ? '>' : ']'
  " Escape [ / ] for NFA — raw `[` inside \(\) starts a collection.
  let ob = a:open_bracket ==# '[' ? '\[' : '<'
  let cb = close_bracket ==# ']' ? '\]' : '>'
  let not_cb = close_bracket ==# ']' ? '[^]]*' : '[^>]*'
  let i = 0
  let len = strlen(a:line)
  while i < len
    let start = stridx(a:line, a:open_bracket, i)
    if start < 0
      break
    endif
    let rest = strpart(a:line, start)
    " Allow `>` / `]` inside quoted strings only loosely: stop at first closer.
    let m = matchlist(rest,
          \ '^\(' . ob . '\)\(/\?\)\([#@]\)\([a-zA-Z_][a-zA-Z0-9_.]*\)\>' .
          \ '\(' . not_cb . '\)\(' . cb . '\)')
    if empty(m)
      let i = start + 1
      continue
    endif
    call s:apply_ftl_tag(a:stack, a:lnum, start, m[2] ==# '/', m[3], m[4], m[5])
    let i = start + strlen(m[0])
  endwhile
endfunction

" True when the open tag starting at content of `lnum` is still unclosed
" after scanning the whole buffer (vsix isOpenStillUnclosed intent).
function! ftl_dev#close#is_open_still_unclosed(lnum, open) abort
  if empty(a:open) || a:lnum < 1 || a:lnum > line('$')
    return 0
  endif
  let line = getline(a:lnum)
  let content_col = match(line, '\S')
  if content_col < 0
    return 0
  endif
  let stack = []
  let l = 1
  while l <= line('$')
    call s:push_line_ftl_tags(stack, l, getline(l), a:open.open)
    let l += 1
  endwhile
  for s in stack
    if s.lnum == a:lnum && s.col == content_col && s.name ==# a:open.name
      return 1
    endif
  endfor
  return 0
endfunction

function! ftl_dev#close#enabled() abort
  return get(g:, 'ftl_dev_auto_close', 1)
endfunction

" One indent level: spaces when expandtab, else a tab (when sw == tabstop).
function! s:indent_unit() abort
  if &l:expandtab || shiftwidth() != &l:tabstop
    return repeat(' ', shiftwidth())
  endif
  return "\t"
endfunction

" Body line indent = opener leading whitespace + one indent unit.
function! s:body_indent_for(line) abort
  return matchstr(a:line, '^\s*') . s:indent_unit()
endfunction

" Insert-mode <CR> expr: pairable open → body + closer (when still unclosed).
" Must RETURN keys (not append()) — buffer edits from <expr> maps raise E565.
" Do NOT return "\<Cmd>…" — older Vim inserts that text literally.
function! ftl_dev#close#cr() abort
  if !ftl_dev#close#enabled()
    return "\<CR>"
  endif
  let line = getline('.')
  let col = col('.')
  let before = strpart(line, 0, col - 1)
  let after = strpart(line, col - 1)
  let open_before = ftl_dev#close#parse_pairable(before)

  " 1) Same-line pair: `<#assign>|</#assign>` → open / indented body / closer
  " CR splits closer down; Esc O opens body; Ctrl-U + explicit pad (opener indent +
  " unit) so cursor and line indent match even when indentexpr pad is wrong/empty.
  if !empty(open_before) && s:same_line_closer(after, open_before)
    return "\<CR>\<Esc>O\<C-u>" . s:body_indent_for(before)
  endif

  " Non-empty text after cursor (not a same-line closer) → plain CR
  if after =~# '\S'
    return "\<CR>"
  endif

  let open = ftl_dev#close#parse_pairable(line)
  if empty(open)
    return "\<CR>"
  endif

  let indent = matchstr(line, '^\s*')
  let body = s:body_indent_for(line)
  let closer = indent . s:closer_token(open)

  " 2) Open EOL + still unclosed → body + closer
  " CTRL-U clears indentexpr pad; body includes opener indent + one unit.
  if ftl_dev#close#is_open_still_unclosed(line('.'), open)
    return "\<CR>\<C-u>" . body . "\<CR>\<C-u>" . closer . "\<Esc>kA"
  endif

  " 3) Open EOL + already closed later → Enter + body indent only
  return "\<CR>\<C-u>" . body
endfunction

function! ftl_dev#close#expand_cr() abort
  " Kept for tests / non-expr callers (not used by the <CR> map).
  let lnum = line('.')
  let line = getline(lnum)
  let open = ftl_dev#close#parse_pairable(line)
  if empty(open)
    return
  endif
  let indent = matchstr(line, '^\s*')
  let body = s:body_indent_for(line)
  if !ftl_dev#close#is_open_still_unclosed(lnum, open)
    call append(lnum, [body])
    call cursor(lnum + 1, strlen(body) + 1)
    return
  endif
  let closer = indent . s:closer_token(open)
  call append(lnum, [body, closer])
  call cursor(lnum + 1, strlen(body) + 1)
endfunction

" After typing `>` / `]`: align mid/close indent first; else HTML-style pair.
" AC11: align-first then after_bracket. Keys only (AC12).
function! ftl_dev#close#after_closer(ch) abort
  if !ftl_dev#close#enabled()
    return ''
  endif
  let align = ftl_dev#indent_align#after_closer(a:ch)
  if align !=# ''
    return align
  endif
  return ftl_dev#close#after_bracket(a:ch)
endfunction

" After typing `>` / `]` (already inserted), append matching closer and sit between.
" Cursor sits after the typed bracket: before = text through that char.
" Prefer ftl_dev#close#after_closer from insert maps (align + pair).
function! ftl_dev#close#after_bracket(ch) abort
  if !ftl_dev#close#enabled()
    return ''
  endif
  let line = getline('.')
  let col = col('.')
  let before = strpart(line, 0, col - 1)
  let open = ftl_dev#close#parse_pairable(before)
  if empty(open) || open.close !=# a:ch
    return ''
  endif
  let closer = s:closer_token(open)
  let after = strpart(line, col - 1)
  " Skip when matching closer already follows (vsix autoClosePairOnCloser).
  if after =~# '^' . escape(closer, '[]\.*$^~')
    return ''
  endif
  " Skip when a matching closer exists later (same intent as cr() path 3).
  if !ftl_dev#close#is_open_still_unclosed(line('.'), open)
    return ''
  endif
  return closer . repeat("\<Left>", strlen(closer))
endfunction

" Innermost still-open FTL directive (same bracket style) before cursor's `</` / `[/`.
" Scans buffer lines above + current line text excluding the close starter.
function! s:find_unclosed_ftl(open_bracket) abort
  let lnum = line('.')
  let col = col('.')
  let line = getline('.')
  let before = strpart(line, 0, col - 1)
  if before !~# '\(<\|\[\)/$'
    return {}
  endif
  let text_before = strpart(before, 0, strlen(before) - 2)
  let stack = []
  let l = 1
  while l < lnum
    call s:push_line_ftl_tags(stack, l, getline(l), a:open_bracket)
    let l += 1
  endwhile
  call s:push_line_ftl_tags(stack, lnum, text_before, a:open_bracket)
  if empty(stack)
    return {}
  endif
  return stack[len(stack) - 1]
endfunction

" After typing `/` (already inserted): self-close `>`/`]`, or expand FTL `</` / `[/`.
" Must RETURN keys only (no append) — same constraint as cr() / after_bracket().
" HTML closes are intentionally skipped (FTL stack only).
function! ftl_dev#close#after_slash() abort
  if !ftl_dev#close#enabled()
    return ''
  endif
  let line = getline('.')
  let col = col('.')
  let before = strpart(line, 0, col - 1)
  if before !~# '/$'
    return ''
  endif

  " Case 2: `</` or `[/` → matching FTL closer (vsix autoCloseAfterSlash).
  let cm = matchlist(before, '\(<\|\[\)/$')
  if !empty(cm)
    let open_br = cm[1]
    let close_br = open_br ==# '<' ? '>' : ']'
    let top = s:find_unclosed_ftl(open_br)
    if empty(top)
      return ''
    endif
    let token = open_br . '/' . top.name . close_br
    let close_start = strlen(before) - 2
    let prefix = strpart(line, 0, close_start)
    " AC6: rewrite indent when `</` / `[/` is alone on the line.
    " Esc+cc replaces the line; CTRL-U drops cc's autoindent pad, then opener indent.
    if prefix !~# '\S'
      let indent = matchstr(getline(top.lnum), '^\s*')
      return "\<Esc>cc\<C-u>" . indent . token
    endif
    " Same-line / mid-line: keep prefix; append name + closer after `/`.
    return top.name . close_br
  endif

  " Case 1: self-close slash inside open directive → insert `>` or `]`.
  " NFA-safe: no \w; word-end via \> ; use \| not [<\[] (] ends collections).
  if before =~# '/[>\]]$'
    return ''
  endif
  let after = strpart(line, col - 1)
  if after =~# '^[>\]]'
    return ''
  endif
  let om = matchlist(before,
        \ '\(<\|\[\)\([#@]\)\([a-zA-Z_][0-9A-Za-z_.]*\)\>[^>\]]*/$')
  if empty(om)
    return ''
  endif
  return om[1] ==# '[' ? ']' : '>'
endfunction
