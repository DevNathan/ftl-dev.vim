" Each timer tick runs after the editor has processed a real batch of keys.
" Compare the whole example, including unrelated tags, while still in Insert mode.
set backspace=indent,eol,start noshowmode shortmess+=I
set report=9999
let s:original = getline(1, '$')
let s:angle = {1: '<@ui.card title="sample">', 3: '</@ui.card>'}
let s:square = {4: '[@ns.tag.card]한글[/@ns.tag.card]'}
let s:steps = [
      \ ['gg02lct ', 'i', {1: '<@ title="sample">', 3: '</@>'}],
      \ ['ui', 'i', {1: '<@ui title="sample">', 3: '</@ui>'}],
      \ ['.', 'i', {1: '<@ui. title="sample">', 3: '</@ui.>'}],
      \ ['card', 'i', s:angle],
      \ ["\<Esc>u", 'n', {}], ["\<C-r>", 'n', s:angle], ['u', 'n', {}],
      \ ['3G0f.lciw', 'i', {1: '<@ns. title="sample">', 3: '</@ns.>'}],
      \ ['row', 'i', {1: '<@ns.row title="sample">', 3: '</@ns.row>'}],
      \ ["\<Esc>u", 'n', {}],
      \ ['4G$i', 'i', {}],
      \ ['.', 'i', {4: '[@ns.tag.]한글[/@ns.tag.]'}],
      \ ['cart', 'i', {4: '[@ns.tag.cart]한글[/@ns.tag.cart]'}],
      \ ["\<BS>d", 'i', s:square],
      \ ["\<Esc>u", 'n', {}], ["\<C-r>", 'n', s:square], ['u', 'n', {}],
      \ ['gg02lciw', 'i', {1: '<@.tag title="sample">', 3: '</@.tag>'}],
      \ ['app', 'i', {1: '<@app.tag title="sample">', 3: '</@app.tag>'}],
      \ ["\<Esc>u", 'n', {}],
      \ ['2G0f#lciwlist', 'i', {2: '  <#list visible>content</#list>'}],
      \ ["\<Esc>u", 'n', {}],
      \ ['5G02f@lrX', 'n', {5: '<@ns.tag><@Xs.tag>nested</@Xs.tag></@ns.tag>'}],
      \ ['u', 'n', {}],
      \ ['6G0f@lrX', 'n', {6: '<#-- <@Xs.tag>comment</@ns.tag> -->'}],
      \ ['u', 'n', {}],
      \ ['8G0f@lrX', 'n', {8: '<@Xs.tag>short close</@>'}],
      \ ['u', 'n', {}],
      \ ['7G0f@lrX', 'n', {7: '<@Xs.tag />'}],
      \ ['gg02lrX', 'n', {1: '<@Xs.tag title="sample">', 3: '</@Xs.tag>', 7: '<@Xs.tag />'}],
      \ ['u', 'n', {7: '<@Xs.tag />'}],
      \ ['u', 'n', {}],
      \ [":set filetype=text\<CR>gg02lrX", 'n', {1: '<@Xs.tag title="sample">'}],
      \ ['u', 'n', {}],
      \ [":let g:ftl_dev_linked_editing = 0\<CR>:set filetype=freemarker\<CR>gg02lrY",
      \  'n', {1: '<@Ys.tag title="sample">'}],
      \ ]
let s:step = -1

function! s:advance(timer) abort
  try
    if s:step >= 0
      let [keys, expected_mode, changes] = s:steps[s:step]
      let expected = copy(s:original)
      for [n, text] in items(changes)
        let expected[str2nr(n) - 1] = text
      endfor
      call assert_equal(expected_mode, mode(), 'mode after ' . keytrans(keys))
      call assert_equal(expected, getline(1, '$'), 'buffer after ' . keytrans(keys))
    endif
    if !empty(v:errors)
      call writefile(v:errors, $FTL_TEST_RESULT)
      cquit 1
    endif
    let s:step += 1
    if s:step == len(s:steps)
      call writefile(['passed'], $FTL_TEST_RESULT)
      qa!
    endif
    call feedkeys(s:steps[s:step][0], 't')
  catch
    call writefile([v:exception, v:throwpoint], $FTL_TEST_RESULT)
    cquit 1
  endtry
endfunction
call timer_start(40, function('s:advance'), {'repeat': -1})
