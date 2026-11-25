" Byte offsets are relative to the lines before the user's edit.
let s:name = '[A-Za-z0-9_.]*'
let s:head = '[<\[]/\?[#@]\zs' . s:name

function! ftl_dev#linked#reset() abort
  let history = undotree()
  let b:ftl_dev_linked = {'lines': getline(1, '$'), 'tick': b:changedtick,
        \ 'seq': history.seq_cur, 'last': history.seq_last, 'pair': []}
endfunction

function! ftl_dev#linked#detach() abort
  autocmd! ftl_dev_linked_editing * <buffer>
  unlet! b:ftl_dev_linked
endfunction

function! s:edited_name(old, new) abort
  let offset = 0
  let delta = strlen(a:new) - strlen(a:old)
  while offset < strlen(a:old)
    let [name, start, end] = matchstrpos(a:old, s:head, offset)
    if start < 0 | break | endif
    let size = strlen(name) + delta
    if size >= 0 && strpart(a:old, 0, start) ==# strpart(a:new, 0, start)
          \ && strpart(a:old, end) ==# strpart(a:new, start + size)
      let replacement = strpart(a:new, start, size)
      if replacement =~# '^' . s:name . '$'
        return [start, name, replacement]
      endif
    endif
    let offset = max([start + 1, end])
  endwhile
  return []
endfunction

function! s:partner(lines, target, cached) abort
  if !empty(a:cached)
    if a:target == a:cached[0] | return copy(a:cached[1]) | endif
    if a:target == a:cached[1] | return copy(a:cached[0]) | endif
  endif
  let state = ftl_dev#scan#state()
  let state.target = a:target
  for n in range(1, len(a:lines))
    call ftl_dev#scan#line(state, n, a:lines[n-1])
    if has_key(state, 'partner') | return state.partner | endif
  endfor
  return []
endfunction

function! ftl_dev#linked#changed() abort
  let previous = b:ftl_dev_linked
  if previous.tick == b:changedtick | return | endif
  let lines = getline(1, '$')
  let seq = changenr()
  " Undo and redo restore the entire recorded block, including the mirror.
  let replay = seq != previous.seq && seq <= previous.last
  let current = {'lines': lines, 'tick': b:changedtick, 'seq': seq,
        \ 'last': max([previous.last, seq]), 'pair': []}
  let b:ftl_dev_linked = current
  if !&l:modifiable || len(previous.lines) != len(lines) || replay
    return
  endif
  let n = line('.')
  let old = previous.lines[n-1]
  let new = lines[n-1]
  if old ==# new | return | endif
  let change = s:edited_name(old, new)
  if empty(change) | return | endif
  " An edit, paste or undo that touched more than this name owns its own result.
  let previous.lines[n-1] = new
  let single_line = previous.lines ==# lines
  let previous.lines[n-1] = old
  if !single_line | return | endif

  let [start, name, replacement] = change
  let source = [n, start]
  let peer = s:partner(previous.lines, source, previous.pair)
  if empty(peer) | return | endif
  let delta = strlen(replacement) - strlen(name)
  if peer[0] == n && peer[1] > start
    let peer[1] += delta
  endif
  let text = lines[peer[0]-1]
  if strpart(text, peer[1], strlen(name)) !=# name | return | endif

  try
    undojoin
  catch /^Vim\%((\a\+)\)\=:E790/
    return
  endtry
  let updated = strpart(text, 0, peer[1]) . replacement . strpart(text, peer[1] + strlen(name))
  let pos = getcurpos()
  call setline(peer[0], updated)
  if peer[0] == n && peer[1] < start
    let source[1] += delta
    if pos[2] > peer[1] + strlen(name)
      let pos[2] += delta
      call setpos('.', pos)
    endif
  endif
  let current.lines[peer[0]-1] = updated
  let current.pair = [source, peer]
  let current.tick = b:changedtick
endfunction
