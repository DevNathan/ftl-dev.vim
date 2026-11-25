" Exercise the popup as a user would, after the language client has attached.
let s:stage = 0
let s:started = reltime()
let s:auto_opened = 0
autocmd CompleteChanged <buffer> if s:stage == 1 && pumvisible() | let s:auto_opened = 1 | endif

function! s:check(timer) abort
  try
    if reltimefloat(reltime(s:started)) > 8
      throw 'Timed out at completion stage ' . s:stage
    endif
    if s:stage == 0
      let ready = has('nvim') ? luaeval("vim.lsp.get_clients({bufnr = 0, name = 'ftl-dev'})[1] ~= nil")
            \ : exists('*g:LspServerReady') && g:LspServerReady()
      if !ready | return | endif
      let s:stage = 1
      let s:typed = reltime()
      call feedkeys("Go<#", 't')
    elseif s:stage == 1 && reltimefloat(reltime(s:typed)) > 0.5
      call assert_equal('<#', trim(getline('.')))
      call assert_false(s:auto_opened || pumvisible(), 'completion appeared while typing <#')
      let s:stage = 2
      call feedkeys("\<C-X>\<C-O>", 't')
    elseif s:stage == 2 && pumvisible()
      let items = complete_info(['items']).items
      call assert_true(index(map(copy(items), 'v:val.abbr'), 'assign') >= 0, 'manual directive completion')
      call assert_equal([], filter(copy(items), '!empty(v:val.menu)'), 'inline descriptions')
      call assert_equal(5, &pumheight)
      let menu = pum_getpos()
      if has_key(menu, 'height')
        call assert_inrange(1, 5, menu.height)
      endif
      let s:stage = 3
      call feedkeys("\<C-E>", 't')
    elseif s:stage == 3
      call assert_false(pumvisible(), 'menu dismissed')
      call assert_equal('<#', trim(getline('.')))
      if !empty(v:errors) | throw join(v:errors, "\n") | endif
      call writefile(['passed'], $FTL_TEST_RESULT)
      qa!
    endif
  catch
    call writefile([v:exception, v:throwpoint] + v:errors, $FTL_TEST_RESULT)
    cquit 1
  endtry
endfunction
call timer_start(50, function('s:check'), {'repeat': -1})
