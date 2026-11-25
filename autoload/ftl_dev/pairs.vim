" Optional FTL-local insert and Visual mappings.
let s:pairs = {'(': ')', '[': ']', '{': '}', '"': '"', "'": "'"}

function! ftl_dev#pairs#install() abort
  let b:ftl_dev_pair_marks = []
  for ch in ['(', ')', '[', ']', '{', '}', '"', "'"]
    let key = '<Char-' . char2nr(ch) . '>'
    let rhs = '<C-R>=ftl_dev#pairs#type(' . char2nr(ch) . ')<CR>'
    if ch ==# ']'
      let rhs .= "<C-R>=ftl_dev#close#after_closer(']')<CR>"
    endif
    execute 'inoremap <silent><buffer> ' . key . ' ' . rhs
    if has_key(s:pairs, ch) && exists('*getregionpos')
      execute 'xnoremap <silent><buffer><expr> ' . key . ' ftl_dev#pairs#visual_key(' . char2nr(ch) . ')'
    endif
  endfor
  inoremap <silent><buffer> <BS> <C-R>=ftl_dev#pairs#backspace()<CR>
  augroup ftl_dev_pairs
    autocmd! * <buffer>
    autocmd InsertLeave,BufLeave <buffer> let b:ftl_dev_pair_marks = []
  augroup END
endfunction

function! ftl_dev#pairs#detach() abort
  autocmd! ftl_dev_pairs * <buffer>
  unlet! b:ftl_dev_pair_marks
  for ch in ['(', ')', '[', '{', '"', "'"]
    execute 'iunmap <buffer> <Char-' . char2nr(ch) . '>'
    if has_key(s:pairs, ch) && exists('*getregionpos')
      execute 'xunmap <buffer> <Char-' . char2nr(ch) . '>'
    endif
  endfor
  iunmap <buffer> <BS>
  " The ftplugin's base mappings own the cleanup of ] and }.
endfunction

" The text to the right stays fixed as the user types inside the pair.
" Counting lines from EOF also follows a closer across an inserted newline.
function! ftl_dev#pairs#finish(close) abort
  let tail = strpart(getline('.'), col('.') - 1)
  call add(b:ftl_dev_pair_marks, [line('$') - line('.'), a:close . tail])
  return a:close . "\<C-G>U\<Left>"
endfunction

function! ftl_dev#pairs#consume(close) abort
  if !exists('b:ftl_dev_pair_marks') || getline('.')[col('.') - 1] !=# a:close
    return 0
  endif
  let mark = [line('$') - line('.'), strpart(getline('.'), col('.') - 1)]
  let i = index(b:ftl_dev_pair_marks, mark)
  if i < 0 | return 0 | endif
  call remove(b:ftl_dev_pair_marks, i)
  return 1
endfunction

function! s:literal() abort
  " Prime the line before querying a gap during queued Insert-mode input.
  call synID(line('.'), 1, 1)
  let groups = map(synstack(line('.'), col('.')), 'synIDattr(v:val, "name")')
  " The closing interpolation delimiter has already left its syntax region.
  if getline('.')[col('.') - 1] ==# '}' && !empty(groups) && groups[-1] ==# 'ftlDelimiter'
    let groups = map(synstack(line('.'), col('.') - 1), 'synIDattr(v:val, "name")')
  endif
  for group in reverse(groups)
    if group =~# '^ftl\%(Interpolation\|\%(User\)\?Directive\%(Square\)\?\)$'
      return 0
    elseif group =~# '^ftl\%(.*String\|.*Comment\|SqlMarker\)'
      return 1
    endif
  endfor
  return 0
endfunction

function! ftl_dev#pairs#type(code) abort
  let ch = nr2char(a:code)
  let offset = col('.') - 1
  let before = strpart(getline('.'), 0, offset)
  let quote = ch ==# '"' || ch ==# "'"
  if quote && strlen(matchstr(before, '\\\+$')) % 2
    return ch
  endif
  if ftl_dev#pairs#consume(ch)
    return "\<C-G>U\<Right>"
  endif
  if !has_key(s:pairs, ch)
    return ch ==# '}' ? ftl_dev#close#brace() : ch
  endif
  let next = getline('.')[offset]
  if !empty(next) && next !~# '\s' && stridx(';:.,=}])>', next) < 0
    return ch
  endif
  if quote && before =~# '\k$' && before !~# '\<r$'
    return ch
  endif
  return empty(&l:syntax) || s:literal() ? ch : ch . ftl_dev#pairs#finish(s:pairs[ch])
endfunction

function! ftl_dev#pairs#backspace() abort
  let before = strpart(getline('.'), 0, col('.') - 1)
  let open = matchstr(before, '.$')
  if has_key(s:pairs, open) && ftl_dev#pairs#consume(s:pairs[open])
    return "\<Del>\<BS>"
  endif
  return "\<BS>"
endfunction

function! ftl_dev#pairs#visual_key(code) abort
  if mode() ==# "\<C-V>"
    return nr2char(a:code)
  endif
  return ":\<C-U>call ftl_dev#pairs#surround(" . a:code . ")\<CR>"
endfunction

function! ftl_dev#pairs#surround(code) abort
  let open = nr2char(a:code)
  let span = getregionpos(getpos("'<"), getpos("'>"), {'type': visualmode(), 'eol': 1})
  let first = span[0][0]
  let last = span[-1][1]
  let lines = getline(first[1], last[1])
  let start = first[2] - 1
  let end = last[2] - 1
  let end += strlen(matchstr(strpart(lines[-1], end), '^.'))
  let lines[-1] = strpart(lines[-1], 0, end) . s:pairs[open] . strpart(lines[-1], end)
  let lines[0] = strpart(lines[0], 0, start) . open . strpart(lines[0], start)
  call setline(first[1], lines)
  call cursor(first[1], start + 1)
endfunction
