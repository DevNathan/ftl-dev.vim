" ftl-dev — FreeMarker indent (mirrors extension/src/indentRules.ts)
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetFreemarkerIndent()
" Keep keys simple: `[` / `<#` in indentkeys break :set on Vim 8.1 (E518).
setlocal indentkeys=o,O,!^F

let b:undo_indent = 'setlocal indentexpr< indentkeys<'

function! GetFreemarkerIndent() abort
  return ftl_dev#indent#for_line(ftl_dev#scan#before(v:lnum), getline(v:lnum), shiftwidth())
endfunction
