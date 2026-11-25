" Auto-close block directives (VS Code closeTag / Enter parity). Lightweight.

" Parse a single-line pairable open tag. Returns {} or
" { 'name': '#attempt', 'open': '<', 'close': '>' }
function! ftl_dev#close#parse_pairable(line) abort
  let text = trim(a:line)
  let state = ftl_dev#scan#state()
  call ftl_dev#scan#line(state, 1, text)
  if len(state.stack) != 1 | return {} | endif
  let site = state.stack[0]
  if site.col != 0 || site.endcol != strlen(text) - 1 | return {} | endif
  return {'name': site.name, 'open': site.open, 'close': site.open ==# '<' ? '>' : ']'}
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
  let state = ftl_dev#scan#before(line('$') + 1)
  for s in state.stack
    if s.lnum == a:lnum && s.col == content_col && s.name ==# a:open.name
      return 1
    endif
  endfor
  return 0
endfunction

function! ftl_dev#close#enabled() abort
  return get(g:, 'ftl_dev_auto_close', 1)
endfunction

" Insert-mode <CR> expr: structural pair ops only — indent comes from indentexpr.
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

  " 1) Same-line pair: `<#assign>|</#assign>`
  " CR moves closer down; == / CTRL-F reindent via indentexpr (no hand-built pads).
  if !empty(open_before) && s:same_line_closer(after, open_before)
    return "\<CR>\<Esc>==O\<C-f>"
  endif

  " Non-empty text after cursor (not a same-line closer) → plain CR
  if after =~# '\S'
    return "\<CR>"
  endif

  let open = ftl_dev#close#parse_pairable(line)
  if empty(open)
    return "\<CR>"
  endif

  let token = s:closer_token(open)

  " 2) Open EOL + still unclosed → closer below, then body above it.
  " Avoid Esc on an empty body line (Vim strips autoindent when leaving insert).
  if ftl_dev#close#is_open_still_unclosed(line('.'), open)
    return "\<Esc>o" . token . "\<Esc>==O\<C-f>"
  endif

  " 3) Open EOL + already closed later → Enter + CTRL-F (indentexpr)
  return "\<CR>\<C-f>"
endfunction

function! ftl_dev#close#expand_cr() abort
  " Kept for tests / non-expr callers (not used by the <CR> map).
  let lnum = line('.')
  let line = getline(lnum)
  let open = ftl_dev#close#parse_pairable(line)
  if empty(open)
    return
  endif
  if !ftl_dev#close#is_open_still_unclosed(lnum, open)
    call append(lnum, [''])
    execute (lnum + 1) . 'normal! =='
    call cursor(lnum + 1, col('$'))
    return
  endif
  call append(lnum, ['', s:closer_token(open)])
  execute (lnum + 1) . 'normal! =='
  execute (lnum + 2) . 'normal! =='
  call cursor(lnum + 1, col('$'))
endfunction

" After typing `>` / `]`: align mid/close indent first; else HTML-style pair.
" AC11: align-first then after_bracket. Keys only (AC12).
function! ftl_dev#close#after_closer(ch) abort
  if !ftl_dev#close#enabled()
    return ''
  endif
  " A slash after a call can still be division. Keep the tag closer ahead
  " of the cursor until the user types it, even after entering a divisor.
  if exists('b:ftl_dev_slash_tail') && a:ch ==# b:ftl_dev_slash_tail[1][0]
        \ && b:ftl_dev_slash_tail ==# [line('$') - line('.'), strpart(getline('.'), col('.') - 1)]
    let state = ftl_dev#scan#before(line('.'))
    call ftl_dev#scan#line(state, line('.'), strpart(getline('.'), 0, col('.') - 2), 0)
    if !empty(state.tag) && state.tag.end ==# a:ch && !state.tag.depth && empty(state.tag.quote) && empty(state.comments)
      unlet b:ftl_dev_slash_tail
      return "\<Del>"
    endif
  endif
  let mark = get(b:, 'ftl_dev_self_close', [])
  unlet! b:ftl_dev_self_close
  if mark ==# [line('.'), col('.'), b:changedtick, a:ch]
    return "\<BS>"
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
  let offset = col('.') - 1
  let n = line('.')
  let state = ftl_dev#scan#before(n)
  call ftl_dev#scan#line(state, n, strpart(line, 0, offset), 0)
  if empty(state.stack) | return '' | endif
  let site = state.stack[-1]
  if site.endline != n || site.endcol != offset - 1 | return '' | endif
  let closer = site.open . '/' . site.name . a:ch
  if stridx(strpart(line, offset), closer) == 0 | return '' | endif
  " Follow this opener through the rest of the file, including nested namesakes.
  call ftl_dev#scan#line(state, n, strpart(line, offset), offset)
  for later in range(n + 1, line('$'))
    if index(state.stack, site) < 0 | return '' | endif
    call ftl_dev#scan#line(state, later, getline(later), 0)
  endfor
  return index(state.stack, site) < 0 ? '' : closer . repeat("\<Left>", strlen(closer))
endfunction

" Innermost still-open FTL directive (same bracket style) before cursor's `</` / `[/`.
" Scans buffer lines above + current line text excluding the close starter.
function! s:find_unclosed(open_bracket) abort
  let lnum = line('.')
  let col = col('.')
  let line = getline('.')
  let before = strpart(line, 0, col - 1)
  if before !~# '\(<\|\[\)/$'
    return {}
  endif
  let text_before = strpart(before, 0, strlen(before) - 2)
  let state = ftl_dev#scan#before(lnum)
  call ftl_dev#scan#line(state, lnum, text_before, 0)
  if !empty(state.tag) || !empty(state.comments)
    return {}
  endif
  let ftl = {}
  for site in reverse(state.stack)
    if site.open ==# a:open_bracket
      let ftl = site
      break
    endif
  endfor
  return a:open_bracket ==# '<' ? ftl_dev#html#close_target(lnum, strlen(text_before) + 1, ftl) : ftl
endfunction

" After typing `/` (already inserted): self-close `>`/`]`, or expand FTL `</` / `[/`.
" Must RETURN keys only (no append) — same constraint as cr() / after_bracket().
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
    let top = s:find_unclosed(open_br)
    if empty(top)
      return ''
    endif
    let consume = open_br ==# '[' && ftl_dev#pairs#consume(']') ? "\<Del>" : ''
    let close_start = strlen(before) - 2
    let prefix = strpart(line, 0, close_start)
    " AC6: rewrite indent when `</` / `[/` is alone on the line.
    if prefix !~# '\S'
      let indent = matchstr(getline(top.lnum), '^\s*')
      if indent !=# prefix
        return consume . "\<Home>" . repeat("\<Del>", strlen(prefix)) . indent . "\<Right>\<Right>" . top.name . close_br
      endif
    endif
    " Same-line / mid-line: keep prefix; append name + closer after `/`.
    return consume . top.name . close_br
  endif

  " Only a slash at the top level of an unfinished directive can self-close.
  let state = ftl_dev#scan#before(line('.'))
  call ftl_dev#scan#line(state, line('.'), before, 0)
  let tag = state.tag
  if empty(tag) || !empty(state.comments) || tag.closing || tag.depth || !empty(tag.quote)
    return ''
  endif
  let after = strpart(line, col - 1)
  let call_rhs = tag.sigil ==# '#' && index(['assign', 'local', 'global'], tag.name) >= 0
        \ && tag.operator && tag.body =~# ')\s*/$'
  if !call_rhs && !ftl_dev#scan#self_close(tag)
    return ''
  endif
  if after[0] ==# tag.end
    let b:ftl_dev_slash_tail = [line('$') - line('.'), after]
    return ''
  endif
  if call_rhs
    if after =~# '\S' | return '' | endif
    let b:ftl_dev_slash_tail = [line('$') - line('.'), tag.end . after]
    return tag.end . "\<C-G>U\<Left>"
  endif
  if after =~# '^\s*/*' . escape(state.tag.end, ']')
    return ''
  endif
  let end = state.tag.end
  let b:ftl_dev_self_close = [line('.'), col + 2, b:changedtick + 2, end]
  return end
endfunction

function! ftl_dev#close#interpolation() abort
  if !ftl_dev#close#enabled()
    return ''
  endif
  let prefix = strpart(getline('.'), 0, col('.') - 3)
  let escapes = matchstr(prefix, '\\\+$')
  if strlen(escapes) % 2 | return '' | endif
  for id in synstack(line('.'), col('.') - 2)
    if synIDattr(id, 'name') =~# '^ftl\%(Comment\|HtmlComment\|SqlComment\|SqlMarker\|RawString\)'
      return ''
    endif
  endfor
  if exists('b:ftl_dev_pair_marks')
    let tail = strpart(getline('.'), col('.') - 1)
    if tail[0] ==# '}' && index(b:ftl_dev_pair_marks, [line('$') - line('.'), tail]) < 0
      return ''
    endif
    return ftl_dev#pairs#finish('}')
  endif
  return getline('.')[col('.') - 1] ==# '}' ? '' : "}\<Left>"
endfunction

function! ftl_dev#close#brace() abort
  let offset = col('.') - 1
  if ftl_dev#close#enabled() && getline('.')[offset] ==# '}'
        \ && strpart(getline('.'), 0, offset) =~# '${[^{}]*$'
    return "\<Right>"
  endif
  return '}'
endfunction
