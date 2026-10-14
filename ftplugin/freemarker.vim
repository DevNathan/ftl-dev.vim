" ftl-dev — FreeMarker filetype plugin (editor-local UX; no comparison decorations)
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=<#--\ %s\ -->
setlocal comments=s:<#--,e:-->
setlocal matchpairs+=<:>

" matchit: FTL block pairs
if exists("loaded_matchit")
  let b:match_words =
        \ '<#if\>:<#elseif\>:<#else\>:</#if>,' .
        \ '<#list\>:<#items\>:<#sep\>:</#list>,' .
        \ '<#attempt\>:<#recover\>:</#attempt>,' .
        \ '<#macro\>:</#macro>,' .
        \ '<#function\>:</#function>,' .
        \ '<#compress\>:</#compress>,' .
        \ '<#switch\>:<#case\>:<#default\>:</#switch>,' .
        \ '\[#if\]:\[#elseif\]:\[#else\]:\[/#if\],' .
        \ '\[#list\]:\[/#list\],' .
        \ '\[#attempt\]:\[#recover\]:\[/#attempt\],' .
        \ '\[#macro\]:\[/#macro\],' .
        \ '\[#function\]:\[/#function\]'
endif

" ${ → }
inoremap <buffer> ${ ${}<Left>

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
setlocal include=\\v\\[#<]#\\s*(include\|import)\\s+[\"']
setlocal includeexpr=ftl_dev#ft#strip_include_quotes(v:fname)
setlocal suffixesadd=.ftl,.ftlh,.ftlx

let b:undo_ftplugin =
      \ "setlocal commentstring< comments< matchpairs< include< includeexpr< suffixesadd<"
      \ . " | silent! iunmap <buffer> ${"
      \ . " | silent! iunmap <buffer> <CR>"
      \ . " | silent! iunmap <buffer> >"
      \ . " | silent! iunmap <buffer> ]"
      \ . " | silent! iunmap <buffer> /"
      \ . " | silent! nunmap <buffer> <LocalLeader>c"
      \ . " | silent! xunmap <buffer> <LocalLeader>c"
      \ . " | unlet! b:match_words"
