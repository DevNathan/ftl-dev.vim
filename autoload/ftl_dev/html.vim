" Compare completed HTML elements with the innermost FTL opener. Syntax
" groups distinguish tag delimiters from text inside attributes and SQL.
let s:void = split('area base br col embed hr img input link meta param source track wbr')

function! s:group(pos) abort
  return synIDattr(synID(a:pos[0], a:pos[1], 1), 'name')
endfunction

function! ftl_dev#html#close_target(lnum, startcol, ftl) abort
  let groups = map(synstack(a:lnum, a:startcol), 'synIDattr(v:val, "name")')
  if index(groups, 'ftlHtmlComment') >= 0 || index(groups, 'ftlHtmlTag') >= 0
        \ || index(groups, 'ftlHtmlDoctype') >= 0 || index(groups, 'ftlInterpolation') >= 0
        \ || index(groups, 'ftlSqlString') >= 0 || index(groups, 'ftlSqlComment') >= 0
    return {}
  endif
  if empty(&l:syntax) || index(groups, 'ftlSqlCapture') >= 0 || index(groups, 'ftlSqlMarkedCapture') >= 0
    return a:ftl
  endif

  let view = winsaveview()
  let closed = {}
  let limit = get(a:ftl, 'lnum', 1)
  try
    call cursor(a:lnum, a:startcol)
    while 1
      let tail = searchpos('>', 'bW', limit)
      if tail[0] == 0 | break | endif
      if s:group(tail) !=# 'ftlHtmlDelimiter' | continue | endif
      let self_closing = strpart(getline(tail[0]), tail[1] - 2, 1) ==# '/'
      let head = searchpos('</\?[A-Za-z]', 'bW', limit)
      while head[0] && s:group(head) !=# 'ftlHtmlTagName'
        let head = searchpos('</\?[A-Za-z]', 'bW', limit)
      endwhile
      if head[0] == 0 || (!empty(a:ftl) && head[0] == limit && head[1] - 1 < a:ftl.col)
        break
      endif
      let tag = matchlist(strpart(getline(head[0]), head[1] - 1), '^<\(/\?\)\([A-Za-z][A-Za-z0-9_:-]*\)')
      let name = tolower(tag[2])
      if self_closing || index(s:void, name) >= 0 | continue | endif
      if tag[1] ==# '/'
        let closed[name] = get(closed, name, 0) + 1
      elseif get(closed, name, 0)
        let closed[name] -= 1
      else
        return {'name': tag[2], 'lnum': head[0]}
      endif
    endwhile
    return a:ftl
  finally
    call winrestview(view)
  endtry
endfunction
