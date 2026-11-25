" A fold includes the opening tag, its body and its matching closer.
function! ftl_dev#fold#level(lnum) abort
  let state = ftl_dev#scan#before(a:lnum)
  let before = len(state.stack)
  call ftl_dev#scan#line(state, a:lnum, getline(a:lnum), 0)
  let after = len(state.stack)
  if after > before | return '>' . after | endif
  if after < before | return '<' . before | endif
  return after
endfunction
