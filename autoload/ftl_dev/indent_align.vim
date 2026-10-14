" Align mid-block / close-tag indent when `>` or `]` is typed (vsix indentAlign).
" Insert maps must RETURN keys only (no setline) — same constraint as close#after_slash.

let s:always_block = {
      \ 'if':1, 'list':1, 'macro':1, 'function':1, 'attempt':1, 'compress':1,
      \ 'escape':1, 'noescape':1, 'autoesc':1, 'noautoesc':1, 'transform':1,
      \ 'switch':1, 'items':1,
      \ }

let s:mid_block = {
      \ 'else':1, 'elseif':1, 'recover':1, 'case':1, 'default':1, 'sep':1,
      \ }

let s:capture = { 'assign':1, 'local':1, 'global':1 }

let s:else_parents = { 'if':1, 'list':1 }
let s:elseif_parents = { 'if':1 }
let s:recover_parents = { 'attempt':1 }
let s:case_parents = { 'switch':1 }
let s:sep_parents = { 'list':1, 'items':1 }

" After typing `>` / `]` (already inserted): keys to rewrite line indent, or ''.
function! ftl_dev#indent_align#after_closer(ch) abort
  if a:ch !=# '>' && a:ch !=# ']'
    return ''
  endif
  let open_bracket = a:ch ==# '>' ? '<' : '['
  let line = getline('.')
  let col = col('.')
  if col < 2
    return ''
  endif
  let closer = strpart(line, col - 2, 1)
  if closer !=# a:ch
    return ''
  endif

  let content_start = match(line, '\S')
  if content_start < 0
    return ''
  endif
  " Tag text ends at the typed closer; same-line trail (e.g. </#attempt>) stays.
  let content = strpart(line, content_start, (col - 1) - content_start)
  let cur_indent = strpart(line, 0, content_start)

  let want = s:want_indent(content, open_bracket, a:ch)
  if want is# v:null || want ==# cur_indent
    return ''
  endif
  return repeat("\<BS>", col - 1) . want . content
endfunction

function! s:want_indent(content, open_bracket, closer) abort
  let mid = s:match_mid(a:content, a:open_bracket, a:closer)
  if !empty(mid)
    let parent = s:find_mid_parent(line('.'), mid, a:open_bracket)
    return empty(parent) ? v:null : parent.indent
  endif
  let close = s:match_close(a:content, a:open_bracket, a:closer)
  if !empty(close)
    let parent = s:find_matching_open(line('.'), close.key, a:open_bracket)
    return empty(parent) ? v:null : parent.indent
  endif
  return v:null
endfunction

function! s:match_mid(content, open_bracket, closer) abort
  let ob = a:open_bracket ==# '[' ? '\[' : '<'
  let cb = a:closer ==# ']' ? '\]' : '>'
  let m = matchlist(a:content,
        \ '^' . ob . '#\(else\|elseif\|recover\|case\|default\|sep\)\>' .
        \ '\_.*' . cb . '$')
  if empty(m)
    return ''
  endif
  return m[1]
endfunction

function! s:match_close(content, open_bracket, closer) abort
  let ob = a:open_bracket ==# '[' ? '\[' : '<'
  let cb = a:closer ==# ']' ? '\]' : '>'
  let m = matchlist(a:content,
        \ '^' . ob . '/\([#@]\)\([a-zA-Z_][0-9A-Za-z_.]*\)\>' .
        \ '\_.*' . cb . '$')
  if empty(m)
    return {}
  endif
  return { 'key': m[1] . m[2] }
endfunction

function! s:find_mid_parent(lnum, mid_name, open_bracket) abort
  let parents = {}
  if a:mid_name ==# 'elseif'
    let parents = s:elseif_parents
  elseif a:mid_name ==# 'else'
    let parents = s:else_parents
  elseif a:mid_name ==# 'recover'
    let parents = s:recover_parents
  elseif a:mid_name ==# 'case' || a:mid_name ==# 'default'
    let parents = s:case_parents
  elseif a:mid_name ==# 'sep'
    let parents = s:sep_parents
  else
    return {}
  endif
  let stack = s:collect_open_stack(a:lnum, a:open_bracket)
  let i = len(stack) - 1
  while i >= 0
    let site = stack[i]
    if site.name =~# '^#'
      let dir = strpart(site.name, 1)
      if has_key(parents, dir)
        return site
      endif
    endif
    let i -= 1
  endwhile
  return {}
endfunction

function! s:find_matching_open(lnum, key, open_bracket) abort
  let stack = s:collect_open_stack(a:lnum, a:open_bracket)
  let i = len(stack) - 1
  while i >= 0
    if stack[i].name ==# a:key
      return stack[i]
    endif
    let i -= 1
  endwhile
  return {}
endfunction

" Still-open block directives on lines above `lnum` (same bracket style).
function! s:collect_open_stack(lnum, open_bracket) abort
  let stack = []
  let l = 1
  while l < a:lnum
    call s:push_line_ftl_tags(stack, l, getline(l), a:open_bracket)
    let l += 1
  endwhile
  return stack
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

function! s:apply_ftl_tag(stack, lnum, is_close, sigil, name, inner) abort
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
  let indent = matchstr(getline(a:lnum), '^\s*')
  call add(a:stack, { 'name': key, 'indent': indent, 'lnum': a:lnum })
endfunction

" Index of closing `>` / `]` from byte offset `from`, or -1. Quotes + () nesting.
function! s:scan_tag_end(text, from, close_bracket) abort
  let in_str = ''
  let paren = 0
  let p = a:from
  let len = strlen(a:text)
  while p < len
    let ch = strpart(a:text, p, 1)
    if in_str !=# ''
      if ch ==# '\' && p + 1 < len
        let p += 2
        continue
      endif
      if ch ==# in_str
        let in_str = ''
      endif
      let p += 1
      continue
    endif
    if ch ==# '"' || ch ==# "'"
      let in_str = ch
      let p += 1
      continue
    endif
    if ch ==# '('
      let paren += 1
      let p += 1
      continue
    endif
    if ch ==# ')' && paren > 0
      let paren -= 1
      let p += 1
      continue
    endif
    if ch ==# a:close_bracket && paren == 0
      return p
    endif
    let p += 1
  endwhile
  return -1
endfunction

function! s:push_line_ftl_tags(stack, lnum, line, open_bracket) abort
  let close_bracket = a:open_bracket ==# '<' ? '>' : ']'
  let i = 0
  let len = strlen(a:line)
  while i < len
    let start = stridx(a:line, a:open_bracket, i)
    if start < 0
      break
    endif
    let p = start + 1
    let is_close = 0
    if strpart(a:line, p, 1) ==# '/'
      let is_close = 1
      let p += 1
    endif
    let sigil = strpart(a:line, p, 1)
    if sigil !=# '#' && sigil !=# '@'
      let i = start + 1
      continue
    endif
    let p += 1
    let first = strpart(a:line, p, 1)
    if first !~# '[a-zA-Z_]'
      let i = start + 1
      continue
    endif
    let name_start = p
    let p += 1
    while p < len && strpart(a:line, p, 1) =~# '[0-9A-Za-z_.]'
      let p += 1
    endwhile
    let name = strpart(a:line, name_start, p - name_start)
    let inner_start = p
    let end = s:scan_tag_end(a:line, p, close_bracket)
    if end < 0
      break
    endif
    let inner = strpart(a:line, inner_start, end - inner_start)
    let i = end + 1
    call s:apply_ftl_tag(a:stack, a:lnum, is_close, sigil, name, inner)
  endwhile
endfunction
