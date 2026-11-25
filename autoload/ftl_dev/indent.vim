" Pure indent helpers (unit-tested). Used by indent/freemarker.vim.

let s:inc = '^\s*\%('
      \ . '<#\%(if\|list\|macro\|function\|attempt\|compress\|escape\|noescape\|autoesc\|noautoesc\|transform\|switch\|items\|autoEsc\|noAutoEsc\|noEscape\|foreach\|forEach\|comment\|else\|elseif\|elseIf\|recover\|case\|on\|default\|sep\)\>.*>\s*'
      \ . '\|'
      \ . '\[#\%(if\|list\|macro\|function\|attempt\|compress\|escape\|noescape\|autoesc\|noautoesc\|transform\|switch\|items\|autoEsc\|noAutoEsc\|noEscape\|foreach\|forEach\|comment\|else\|elseif\|elseIf\|recover\|case\|on\|default\|sep\)\>.*\]\s*'
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
      \ . '[\[<]#\%(else\|elseif\|elseIf\|recover\|case\|on\|default\|sep\)\>'
      \ . '\|'
      \ . '[\[<]/#\%(if\|list\|macro\|function\|attempt\|compress\|escape\|noescape\|autoesc\|noautoesc\|transform\|switch\|items\|autoEsc\|noAutoEsc\|noEscape\|foreach\|forEach\|comment\|assign\|local\|global\)\>'
      \ . '\|'
      \ . '[\[<]/@[a-zA-Z_][0-9A-Za-z_.]*\>'
      \ . '\)'

function! ftl_dev#indent#increases(line) abort
  return a:line =~# s:inc
endfunction

function! ftl_dev#indent#decreases(line) abort
  return a:line =~# s:dec
endfunction

function! ftl_dev#indent#for_line(state, text, width) abort
  let stack = a:state.stack
  if empty(stack) | return 0 | endif
  let m = matchlist(a:text, '^\s*\([<\[]\)\(/\?\)\([#@]\)\([A-Za-z_][A-Za-z0-9_.]*\)')
  if !empty(m) && empty(a:state.tag) && empty(a:state.comments)
    let parents = !empty(m[2]) ? [m[3] . m[4]] : m[3] ==# '#' ? ftl_dev#scan#parents(m[4]) : []
    if !empty(parents)
      for site in reverse(copy(stack))
        if site.open ==# m[1] && index(parents, site.name) >= 0
          return strdisplaywidth(site.indent)
        endif
      endfor
      return 0
    endif
  endif
  return strdisplaywidth(stack[-1].indent) + a:width
endfunction

function! ftl_dev#indent#compute(lnum, lines, shiftwidth) abort
  let state = ftl_dev#scan#state()
  for n in range(1, a:lnum - 1)
    call ftl_dev#scan#line(state, n, get(a:lines, n - 1, ''))
  endfor
  return ftl_dev#indent#for_line(state, get(a:lines, a:lnum - 1, ''), a:shiftwidth)
endfunction
