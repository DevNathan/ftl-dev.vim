" Comment toggle helpers using &l:commentstring (left/right around %s).

function! s:parts() abort
  let cs = &l:commentstring
  if cs !~# '%s'
    return ['', '']
  endif
  let left = matchstr(cs, '^.*\ze%s')
  let right = matchstr(cs, '%s\zs.*$')
  return [left, right]
endfunction

function! s:is_blank(line) abort
  return a:line !~# '\S'
endfunction

" Fully commented: after indent, starts with left and ends with right.
function! s:is_commented(line, left, right) abort
  let indent = matchstr(a:line, '^\s*')
  let content = strpart(a:line, strlen(indent))
  if stridx(content, a:left) != 0
    return 0
  endif
  if empty(a:right)
    return 1
  endif
  if strlen(content) < strlen(a:left) + strlen(a:right)
    return 0
  endif
  return strpart(content, strlen(content) - strlen(a:right)) ==# a:right
endfunction

function! s:comment_line(line, left, right) abort
  if s:is_commented(a:line, a:left, a:right)
    return a:line
  endif
  let indent = matchstr(a:line, '^\s*')
  let content = strpart(a:line, strlen(indent))
  return indent . a:left . content . a:right
endfunction

function! s:uncomment_line(line, left, right) abort
  let indent = matchstr(a:line, '^\s*')
  let content = strpart(a:line, strlen(indent))
  let mid = strpart(content, strlen(a:left),
        \ strlen(content) - strlen(a:left) - strlen(a:right))
  return indent . mid
endfunction

function! s:toggle_range(first, last) abort
  let [left, right] = s:parts()
  if empty(left) && empty(right)
    return
  endif
  let lines = getline(a:first, a:last)
  let all_commented = 1
  let any_nonblank = 0
  for line in lines
    if s:is_blank(line)
      continue
    endif
    let any_nonblank = 1
    if !s:is_commented(line, left, right)
      let all_commented = 0
      break
    endif
  endfor
  if !any_nonblank
    return
  endif
  let i = 0
  while i < len(lines)
    let line = lines[i]
    if !s:is_blank(line)
      if all_commented
        let lines[i] = s:uncomment_line(line, left, right)
      else
        let lines[i] = s:comment_line(line, left, right)
      endif
    endif
    let i += 1
  endwhile
  call setline(a:first, lines)
endfunction

" Normal-mode toggle: current line, or v:count lines (default 1).
function! ftl_dev#comment#toggle() abort
  let first = line('.')
  let last = first + v:count1 - 1
  if last > line('$')
    let last = line('$')
  endif
  call s:toggle_range(first, last)
endfunction

" Visual-mode toggle: lines spanning '< to '>.
function! ftl_dev#comment#toggle_visual() abort
  call s:toggle_range(line("'<"), line("'>"))
endfunction
