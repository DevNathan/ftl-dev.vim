" Core directives also used by the FreeMarker syntax highlighter.
let s:directives = split('assign attempt autoesc break case compress continue default else elseif escape fallback flush ftl function global if import include items list local lt macro nested noautoesc noescape noparse nt on outputformat recover recurse return rt sep setting stop switch t transform visit')

function! ftl_dev#complete#directives() abort
  return copy(s:directives)
endfunction

function! ftl_dev#complete#omni(findstart, base) abort
  " Neovim keeps an existing ftplugin omnifunc when a client attaches.
  if has('nvim-0.10') && luaeval("next(vim.lsp.get_clients({bufnr = 0, method = 'textDocument/completion'})) ~= nil")
    return v:lua.vim.lsp.omnifunc(a:findstart, a:base)
  endif
  if a:findstart
    let before = strpart(getline('.'), 0, col('.') - 1)
    let head = match(before, '[<\[]/\?#[A-Za-z]*$')
    if head < 0 | return -3 | endif
    let state = ftl_dev#scan#before(line('.'))
    call ftl_dev#scan#line(state, line('.'), strpart(before, 0, head), 0)
    if !empty(state.comments) || !empty(state.tag) | return -3 | endif
    return match(before, '[A-Za-z]*$')
  endif
  return filter(copy(s:directives), 'stridx(v:val, a:base) == 0')
endfunction
