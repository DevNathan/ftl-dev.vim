" Pure indent helpers (unit-tested). Used by indent/freemarker.vim.

let s:inc = '^\s*\%('
      \ . '<#\%(if\|list\|macro\|function\|attempt\|compress\|escape\|noescape\|autoesc\|noautoesc\|transform\|switch\|items\|else\|elseif\|recover\|case\|default\|sep\)\>.*>\s*'
      \ . '\|'
      \ . '\[#\%(if\|list\|macro\|function\|attempt\|compress\|escape\|noescape\|autoesc\|noautoesc\|transform\|switch\|items\|else\|elseif\|recover\|case\|default\|sep\)\>.*\]\s*'
      \ . '\|'
      \ . '<#\%(assign\|local\|global\)\%(\s\+\%([a-zA-Z_]\w*\|"[^"]*"\)\%(\s\+in\s\+[^>]*\)\?\)\?>\s*'
      \ . '\|'
      \ . '\[#\%(assign\|local\|global\)\%(\s\+\%([a-zA-Z_]\w*\|"[^"]*"\)\%(\s\+in\s\+[^]]*\)\?\)\?\]\s*'
      \ . '\|'
      \ . '<@[a-zA-Z_][0-9A-Za-z_.]*\%(.*\/\s*>\)\@!\%(\s[^>]*\)\?>\s*'
      \ . '\|'
      \ . '\[@[a-zA-Z_][0-9A-Za-z_.]*\%(.*\/\s*]\)\@!\%(\s[^]]*\)\?\]\s*'
      \ . '\)$'

let s:dec = '^\s*\%('
      \ . '[\[<]#\%(else\|elseif\|recover\|case\|default\|sep\)\>'
      \ . '\|'
      \ . '[\[<]/#\%(if\|list\|macro\|function\|attempt\|compress\|escape\|noescape\|autoesc\|noautoesc\|transform\|switch\|items\|assign\|local\|global\)\>'
      \ . '\|'
      \ . '[\[<]/@[a-zA-Z_][0-9A-Za-z_.]*\>'
      \ . '\)'

let s:mid_re = '^\s*[\[<]#\(else\|elseif\|recover\|case\|default\|sep\)\>'
let s:close_re = '^\s*[\[<]/\([#@]\)\([a-zA-Z_][0-9A-Za-z_.]*\)\>'
let s:open_key_re = '^\s*[\[<]\([#@]\)\([a-zA-Z_][0-9A-Za-z_.]*\)\>'

" Mid-block → still-open parent keys (sigil + name).
let s:mid_parents = {
      \ 'else': ['#if', '#list'],
      \ 'elseif': ['#if'],
      \ 'recover': ['#attempt'],
      \ 'case': ['#switch'],
      \ 'default': ['#switch'],
      \ 'sep': ['#list', '#items'],
      \ }

function! ftl_dev#indent#increases(line) abort
  return a:line =~# s:inc
endfunction

function! ftl_dev#indent#decreases(line) abort
  return a:line =~# s:dec
endfunction

function! s:line_indent(line) abort
  let ind = match(a:line, '\S')
  return ind < 0 ? 0 : ind
endfunction

function! s:is_mid(line) abort
  return a:line =~# s:mid_re
endfunction

function! s:mid_name(line) abort
  let m = matchlist(a:line, s:mid_re)
  return empty(m) ? '' : m[1]
endfunction

function! s:close_key(line) abort
  let m = matchlist(a:line, s:close_re)
  return empty(m) ? '' : m[1] . m[2]
endfunction

function! s:is_block_open(line) abort
  return ftl_dev#indent#increases(a:line) && !s:is_mid(a:line)
endfunction

function! s:open_key(line) abort
  let m = matchlist(a:line, s:open_key_re)
  return empty(m) ? '' : m[1] . m[2]
endfunction

function! s:stack_pop_key(stack, key) abort
  let i = len(a:stack) - 1
  while i >= 0
    if a:stack[i].key ==# a:key
      call remove(a:stack, i)
      return 1
    endif
    let i -= 1
  endwhile
  return 0
endfunction

function! s:stack_find_key(stack, key) abort
  let i = len(a:stack) - 1
  while i >= 0
    if a:stack[i].key ==# a:key
      return a:stack[i]
    endif
    let i -= 1
  endwhile
  return {}
endfunction

function! s:stack_find_mid_parent(stack, mid_name) abort
  if !has_key(s:mid_parents, a:mid_name)
    return {}
  endif
  let parents = s:mid_parents[a:mid_name]
  let i = len(a:stack) - 1
  while i >= 0
    let key = a:stack[i].key
    for p in parents
      if key ==# p
        return a:stack[i]
      endif
    endfor
    let i -= 1
  endwhile
  return {}
endfunction

" Apply one prior line to the open-block stack (mid-block: no push/pop).
function! s:stack_apply_line(stack, line) abort
  if a:line !~# '\S'
    return
  endif
  if s:is_mid(a:line)
    return
  endif
  let close_key = s:close_key(a:line)
  if close_key !=# ''
    call s:stack_pop_key(a:stack, close_key)
    return
  endif
  if s:is_block_open(a:line)
    let key = s:open_key(a:line)
    if key !=# ''
      call add(a:stack, {
            \ 'key': key,
            \ 'opener_indent': s:line_indent(a:line),
            \ })
    endif
  endif
endfunction

" Collect still-open block/capture/macro sites on lines before lnum.
function! s:collect_open_stack(lnum, lines) abort
  let stack = []
  let l = 1
  while l < a:lnum
    call s:stack_apply_line(stack, get(a:lines, l - 1, ''))
    let l += 1
  endwhile
  return stack
endfunction

function! s:indent_for_mid_or_close(stack, cur) abort
  if s:is_mid(a:cur)
    let parent = s:stack_find_mid_parent(a:stack, s:mid_name(a:cur))
    return empty(parent) ? 0 : parent.opener_indent
  endif
  let close_key = s:close_key(a:cur)
  if close_key !=# ''
    let parent = s:stack_find_key(a:stack, close_key)
    return empty(parent) ? 0 : parent.opener_indent
  endif
  return -1
endfunction

" Compute indent for line lnum (1-based) given buffer lines as a List (0-based).
" Stack-based open-block indent (mirrors GetFreemarkerIndent without v:lnum).
function! ftl_dev#indent#compute(lnum, lines, shiftwidth) abort
  if a:lnum <= 1
    return 0
  endif
  let stack = s:collect_open_stack(a:lnum, a:lines)
  let cur = get(a:lines, a:lnum - 1, '')
  let mid_or_close = s:indent_for_mid_or_close(stack, cur)
  if mid_or_close >= 0
    return mid_or_close
  endif
  if empty(stack)
    return 0
  endif
  let top = stack[len(stack) - 1]
  let ind = top.opener_indent + a:shiftwidth
  return ind < 0 ? 0 : ind
endfunction
