" ftl-dev — FreeMarker filetype plugin (editor-local UX; no comparison decorations)
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=<#--\ %s\ -->
setlocal comments=s:<#--,e:-->
setlocal matchpairs+=<:>

" matchit: FTL block pairs
if exists("g:loaded_matchit") || exists("g:loaded_matchit_plugin")
  let b:match_words = ''
  for s:br in ['<', '\[']
    for s:group in ['if:elseif:elseIf:else:/if', 'list:items:sep:else:/list',
          \ 'attempt:recover:/attempt', 'switch:case:on:default:/switch',
          \ 'macro:/macro', 'function:/function', 'compress:/compress']
      let s:patterns = []
      for s:name in split(s:group, ':')
        call add(s:patterns, s:br . substitute(s:name, '^/\?', '&#', '') . '\>')
      endfor
      let b:match_words .= (empty(b:match_words) ? '' : ',') . join(s:patterns, ':')
    endfor
  endfor
endif

" ${ → }
inoremap <silent><buffer> ${ ${<C-R>=ftl_dev#close#interpolation()<CR>
inoremap <silent><buffer> } <C-R>=ftl_dev#close#brace()<CR>

" Block auto-close (VS Code parity). Disable: let g:ftl_dev_auto_close = 0
inoremap <silent><buffer><expr> <CR> ftl_dev#close#cr()
" Align mid/close indent first, then HTML-style pair (vsix autoClose).
inoremap <silent><buffer> > ><C-R>=ftl_dev#close#after_closer('>')<CR>
inoremap <silent><buffer> ] ]<C-R>=ftl_dev#close#after_closer(']')<CR>
inoremap <silent><buffer> / /<C-R>=ftl_dev#close#after_slash()<CR>

" Comment toggle. Disable: let g:ftl_dev_comment_maps = 0 (before filetype)
if get(g:, 'ftl_dev_comment_maps', 1)
  nnoremap <silent><buffer> <LocalLeader>c :<C-u>call ftl_dev#comment#toggle()<CR>
  xnoremap <silent><buffer> <LocalLeader>c :<C-u>call ftl_dev#comment#toggle_visual()<CR>
endif

" gf for quoted include/import paths
let &l:include = '\v[<\[]#\s*(include|import)\s+["'']\zs[^"'']+'
setlocal includeexpr=ftl_dev#ft#strip_include_quotes(v:fname)
setlocal suffixesadd=.ftl,.ftlh,.ftlx

let b:undo_ftplugin =
      \ "setlocal commentstring< comments< matchpairs< include< includeexpr< suffixesadd<"
      \ . " | silent! iunmap <buffer> ${"
      \ . " | silent! iunmap <buffer> }"
      \ . " | silent! iunmap <buffer> <CR>"
      \ . " | silent! iunmap <buffer> >"
      \ . " | silent! iunmap <buffer> ]"
      \ . " | silent! iunmap <buffer> /"
      \ . " | silent! nunmap <buffer> <LocalLeader>c"
      \ . " | silent! xunmap <buffer> <LocalLeader>c"
      \ . " | unlet! b:match_words b:ftl_dev_self_close b:ftl_dev_scan"

if get(g:, 'ftl_dev_linked_editing', 1)
  call ftl_dev#linked#reset()
  augroup ftl_dev_linked_editing
    autocmd! * <buffer>
    autocmd BufEnter <buffer> call ftl_dev#linked#reset()
    autocmd InsertEnter,TextChangedI,TextChangedP,TextChanged,InsertLeave <buffer> call ftl_dev#linked#changed()
  augroup END
  let b:undo_ftplugin .= ' | call ftl_dev#linked#detach()'
endif

if get(g:, 'ftl_dev_delimiter_pairs', 0)
  call ftl_dev#pairs#install()
  let b:undo_ftplugin .= ' | call ftl_dev#pairs#detach()'
endif
