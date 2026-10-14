" ftl-dev — detect FreeMarker templates
" Use `set filetype=` (not setfiletype): Vim runtime ships Fluent for *.ftl and
" setfiletype will not override an already-detected type.
au BufRead,BufNewFile *.ftl,*.ftlh,*.ftlx set filetype=freemarker
