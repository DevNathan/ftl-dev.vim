" Scan FTL tags without interpreting quoted delimiters, comments or nested expressions.
let s:blocks = split('if list macro function attempt compress escape noescape noEscape autoesc autoEsc noautoesc noAutoEsc transform switch items foreach forEach comment')
let s:branches = {
      \ 'else': ['#if', '#list'], 'elseif': ['#if'], 'elseIf': ['#if'],
      \ 'recover': ['#attempt'], 'case': ['#switch'], 'on': ['#switch'],
      \ 'default': ['#switch'], 'sep': ['#list', '#items'] }

function! ftl_dev#scan#parents(name) abort
  return get(s:branches, a:name, [])
endfunction

function! ftl_dev#scan#pairable(sigil, name, body) abort
  if a:body =~# '/\s*$'
    return 0
  endif
  return a:sigil ==# '@' || index(s:blocks, a:name) >= 0
        \ || (index(['assign', 'global', 'local'], a:name) >= 0 && a:body !~# '=\|++\|--')
endfunction

function! ftl_dev#scan#self_close(tag) abort
  if a:tag.closing || !empty(a:tag.quote) || a:tag.depth || a:tag.body !~# '/$'
    return 0
  endif
  let name = a:tag.name
  if a:tag.sigil ==# '#' && (index(s:blocks, name) >= 0 || has_key(s:branches, name)
        \ || index(['outputformat', 'outputFormat', 'noparse', 'noParse'], name) >= 0)
    return 0
  endif
  let body = strpart(a:tag.body, 0, strlen(a:tag.body) - 1)
  if body !~# '\S' || body =~# '["'']\s*$' || body =~# '\%(++\|--\)\s*$'
    return 1
  endif
  return !a:tag.operator && !(a:tag.sigil ==# '#' && (name ==# 'return'
        \ || (index(['include', 'import'], name) >= 0 && body =~# '[[:alnum:]_$.]$')))
endfunction

function! ftl_dev#scan#state() abort
  return {'stack': [], 'comments': [], 'tag': {}}
endfunction

function! s:finish_tag(state, tag, lnum, col) abort
  let key = a:tag.sigil . a:tag.name
  let linking = has_key(a:state, 'target')
  if linking && a:tag.closing && empty(a:tag.name) && a:tag.body =~# '\S'
    let a:state.tag = {}
    return
  endif
  if a:tag.closing
    let shorthand = linking && key ==# '@'
    let i = len(a:state.stack) - 1
    while i >= 0
      let open = a:state.stack[i]
      if open.open ==# a:tag.open && (open.name ==# key || (shorthand && open.name[0] ==# '@'))
        call remove(a:state.stack, i)
        if linking && open.name ==# key
          let first = [open.lnum, open.col + 2]
          let last = [a:tag.lnum, a:tag.col + 3]
          if a:state.target == first
            let a:state.partner = last
          elseif a:state.target == last
            let a:state.partner = first
          endif
        endif
        break
      endif
      let i -= 1
    endwhile
  elseif ftl_dev#scan#pairable(a:tag.sigil, a:tag.name, a:tag.body)
        \ || (linking && a:tag.body !~# '/\s*$' && !has_key(s:branches, a:tag.name)
        \ && index(['assign', 'global', 'local'], a:tag.name) < 0)
    if linking && key ==# '#noparse'
      let a:state.literal_end = a:tag.open . '/#noparse'
    endif
    call add(a:state.stack, {'name': key, 'open': a:tag.open, 'lnum': a:tag.lnum,
          \ 'col': a:tag.col, 'indent': a:tag.indent, 'endline': a:lnum, 'endcol': a:col})
  endif
  let a:state.tag = {}
endfunction

" Pass the starting byte offset for slices of a real buffer. The pure scanner
" also accepts free-standing text, for which there are no syntax groups.
function! ftl_dev#scan#line(state, lnum, text, ...) abort
  let p = 0
  let linking = has_key(a:state, 'target')
  if !empty(a:state.tag)
    let a:state.tag.body .= "\n"
  endif
  while p < strlen(a:text)
    let tag = a:state.tag
    if empty(tag) && empty(a:state.comments)
      if has_key(a:state, 'literal_end')
        let p = stridx(a:text, a:state.literal_end, p)
        if p < 0 | break | endif
        unlet a:state.literal_end
      endif
      let head = '[<\[]/\?[#@]'
      let p = match(a:text, linking ? head . '\|[$#]{' : head, p)
      if p < 0 | break | endif
      if a:0 && !empty(&l:syntax)
        let group = synIDattr(synID(a:lnum, a:1 + p + 1, 1), 'name')
        if index(['ftlHtmlComment', 'ftlHtmlDoctype', 'ftlSqlComment'], group) >= 0
          let p += 1
          continue
        endif
      endif
    endif
    let ch = a:text[p]
    if empty(tag) || empty(tag.quote)
      let opener = strpart(a:text, p, 4)
      if opener ==# '<#--' || opener ==# '[#--'
        call add(a:state.comments, opener[0] ==# '<' ? '-->' : '--]')
        let p += 4
        continue
      endif
    endif
    if !empty(a:state.comments)
      if strpart(a:text, p, 3) ==# a:state.comments[-1]
        call remove(a:state.comments, -1)
        let p += 3
      else
        let p += 1
      endif
      continue
    endif
    if empty(tag)
      if linking && strpart(a:text, p, 2) =~# '^[$#]{'
        let a:state.tag = {'expression': 1, 'end': '}', 'depth': 0, 'quote': '', 'raw': 0, 'body': ''}
        let p += 2
        continue
      endif
      let m = matchlist(strpart(a:text, p), '^\([<\[]\)\(/\?\)\([#@]\)\([A-Za-z_][A-Za-z0-9_.]*\)')
      if empty(m) && linking
        let m = matchlist(strpart(a:text, p), '^\([<\[]\)\(/\?\)\([#@]\)\(\)\ze\%([/>[:space:]\]]\|$\)')
      endif
      if empty(m)
        let p += 1
        continue
      endif
      let a:state.tag = {'open': ch, 'end': ch ==# '<' ? '>' : ']', 'closing': !empty(m[2]),
            \ 'sigil': m[3], 'name': m[4], 'body': '', 'depth': 0, 'operator': 0,
            \ 'quote': '', 'raw': 0, 'lnum': a:lnum, 'col': p, 'indent': matchstr(a:text, '^\s*')}
      let p += strlen(m[0])
      continue
    endif
    if !empty(tag.quote)
      if ch ==# '\' && !tag.raw
        let tag.body .= strpart(a:text, p, 2)
        let p += 2
        continue
      elseif ch ==# tag.quote
        let tag.quote = ''
      endif
    elseif ch ==# '"' || ch ==# "'"
      let tag.quote = ch
      let tag.raw = tag.body =~# '\<r$'
    elseif linking && !has_key(tag, 'expression') && !tag.depth && (ch ==# '<' || ch ==# '[')
          \ && strpart(a:text, p) =~# (tag.open ==# '<' ? '^</\?[#@A-Za-z]' : '^\[\%([#@]\|/\)')
      " A new head before the terminator abandons the incomplete tag.
      let a:state.tag = {}
      continue
    elseif ch ==# tag.end && !tag.depth
      if has_key(tag, 'expression')
        let a:state.tag = {}
      else
        call s:finish_tag(a:state, tag, a:lnum, p)
      endif
      let p += 1
      continue
    elseif stridx('([{', ch) >= 0
      let tag.depth += 1
    elseif stridx(')]}', ch) >= 0
      let tag.depth = max([0, tag.depth - 1])
    elseif ch ==# '=' && !tag.depth
      let tag.operator = 1
    endif
    let tag.body .= ch
    let p += 1
  endwhile
endfunction

function! ftl_dev#scan#before(lnum) abort
  " During gg=G each new indent may advance changedtick. Compare the
  " already-scanned prefix before reusing state across a change.
  let cache = get(b:, 'ftl_dev_scan', {})
  let last = a:lnum - 1
  if empty(cache) || cache.last > last || (cache.tick != b:changedtick
        \ && cache.lines !=# getline(1, cache.last))
    let cache = {'last': 0, 'lines': [], 'state': ftl_dev#scan#state()}
  endif
  for n in range(cache.last + 1, last)
    let text = getline(n)
    call ftl_dev#scan#line(cache.state, n, text, 0)
    call add(cache.lines, text)
  endfor
  let cache.last = last
  let cache.tick = b:changedtick
  let b:ftl_dev_scan = cache
  return deepcopy(cache.state)
endfunction
