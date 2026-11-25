" Align mid-block / close-tag indent when `>` or `]` is typed (vsix indentAlign).
" Insert maps must RETURN keys only (no setline) — same constraint as close#after_slash.

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
  " Replace just the leading whitespace. Replaying backspaces over the tag
  " can join the previous line when softtabstop removes several spaces at once.
  return "\<Home>" . repeat("\<Del>", strlen(cur_indent)) . want
        \ . repeat("\<Right>", strchars(content))
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
        \ '^' . ob . '#\(else\|elseif\|elseIf\|recover\|case\|on\|default\|sep\)\>' .
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
  let parents = ftl_dev#scan#parents(a:mid_name)
  let stack = ftl_dev#scan#before(a:lnum).stack
  let i = len(stack) - 1
  while i >= 0
    let site = stack[i]
    if site.open ==# a:open_bracket
      if index(parents, site.name) >= 0
        return site
      endif
    endif
    let i -= 1
  endwhile
  return {}
endfunction

function! s:find_matching_open(lnum, key, open_bracket) abort
  let stack = ftl_dev#scan#before(a:lnum).stack
  let i = len(stack) - 1
  while i >= 0
    if stack[i].open ==# a:open_bracket && stack[i].name ==# a:key
      return stack[i]
    endif
    let i -= 1
  endwhile
  return {}
endfunction
