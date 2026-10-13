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
  let m = matchlist(t, '^\([<\[]\)\([#@]\)\([a-zA-Z_][a-zA-Z0-9_.]*\)\>\(.*\)\([>\]]\)$')
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
    if rest =~# '[=]\|\++\|--\|[+*/%-]='
      return {}
    endif
  else
    return {}
  endif
  return { 'name': sigil . name, 'open': open, 'close': close }
endfunction

function! ftl_dev#close#enabled() abort
  return get(g:, 'ftl_dev_auto_close', 1)
endfunction

" Insert-mode <CR> expr: pairable open → body + closer via append (no indentexpr fight).
function! ftl_dev#close#cr() abort
  if !ftl_dev#close#enabled()
    return "\<CR>"
  endif
  let line = getline('.')
  let col = col('.')
  if line[col - 1 :] =~# '\S'
    return "\<CR>"
  endif
  let open = ftl_dev#close#parse_pairable(line)
  if empty(open)
    return "\<CR>"
  endif
  return "\<Cmd>call ftl_dev#close#expand_cr()\<CR>"
endfunction

function! ftl_dev#close#expand_cr() abort
  let lnum = line('.')
  let line = getline(lnum)
  let open = ftl_dev#close#parse_pairable(line)
  if empty(open)
    return
  endif
  let indent = matchstr(line, '^\s*')
  let body = indent . repeat(' ', shiftwidth())
  let closer = indent . open.open . '/' . open.name . open.close
  call append(lnum, [body, closer])
  call cursor(lnum + 1, strlen(body) + 1)
endfunction

" After typing `>` / `]` (already inserted), append matching closer and sit between.
function! ftl_dev#close#after_bracket(ch) abort
  if !ftl_dev#close#enabled()
    return ''
  endif
  let line = getline('.')
  let col = col('.')
  let before = strpart(line, 0, col)
  let open = ftl_dev#close#parse_pairable(before)
  if empty(open) || open.close !=# a:ch
    return ''
  endif
  let closer = open.open . '/' . open.name . open.close
  return closer . repeat("\<Left>", strlen(closer))
endfunction
