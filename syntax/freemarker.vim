" Vim syntax for FreeMarker (ftl-dev)
"
" Highlighting model (nested, not one blue slab):
"   #assign / #if     → ftlDirKeyword
"   @macro            → ftlUserName
"   var / ob          → ftlIdentifier
"   .now / .log       → ftlMethod   (after a dot)
"   ?string / ?size   → ftlBuiltin
"   "…" / 0-9 / =     → string / number / operator
"
" Vim NFA rules that bit us before:
"   - Prefer [?] for literal '?'; bare ? / \? interact with quantifiers
"   - `$` is EOL; use start="${" for interpolations
"   - `[\w]` does NOT mean word-class inside []; use [a-zA-Z0-9_] or \w outside []
if exists("b:current_syntax")
  finish
endif

syn case match

syn region ftlComment start=/<#--/ end=/-->/ contains=ftlComment,ftlCommentSquare keepend extend
syn region ftlCommentSquare start=/\[#--/ end=/--]/ contains=ftlComment,ftlCommentSquare keepend extend

let s:dirs = 'assign\|attempt\|autoesc\|break\|case\|compress\|continue\|default\|else\|elseif\|escape\|fallback\|flush\|ftl\|function\|global\|if\|import\|include\|items\|list\|local\|lt\|macro\|nested\|noautoesc\|noescape\|noparse\|nt\|outputformat\|recover\|recurse\|return\|rt\|sep\|setting\|stop\|switch\|t\|transform\|visit'

" --- atoms (no [\w] inside collections) ---
" [?] = literal question mark (avoid bare ? / \? quantifier ambiguity)
syn match ftlBuiltin /[?][a-zA-Z_][a-zA-Z0-9_]*/ contained
syn match ftlMethod /\.[a-zA-Z_][a-zA-Z0-9_]*/ contained
syn match ftlIdentifier /\<[a-zA-Z_][a-zA-Z0-9_]*\>/ contained
syn match ftlNumber /\<[0-9]\+\%(\.[0-9]\+\)\=\>/ contained
syn match ftlOperator /[=<>!+\-*\/%|&]/ contained
syn keyword ftlBoolean true false contained
syn region ftlStringD start=/"/ skip=/\\./ end=/"/ contained
syn region ftlStringS start=/'/ skip=/\\./ end=/'/ contained
exe 'syn match ftlDirKeyword /#\%('.s:dirs.'\)\>/ contained'
syn match ftlDirKeyword /#[a-zA-Z_][a-zA-Z0-9_.]*/ contained
syn match ftlUserName /@[a-zA-Z_][a-zA-Z0-9_.]*/ contained

" Known #ftl / #setting / #include named-param LHS (snake ∪ camel).
" Sync with vsix TextMate #directive-named-param / DIRECTIVE_NAMED_PARAMS aliases.
" Lookahead \%(\s*=[^=]\)\@= mirrors (?=\s*=[^=]) — avoids matching ==.
" Defined after ftlIdentifier so this group wins on the same token.
let s:named_params = 'encoding\|strip_whitespace\|stripWhitespace\|strip_text\|stripText\|strict_syntax\|strictSyntax\|attributes\|ns_prefixes\|nsPrefixes\|auto_esc\|autoEsc\|output_format\|outputFormat\|locale\|number_format\|numberFormat\|boolean_format\|booleanFormat\|date_format\|dateFormat\|time_format\|timeFormat\|datetime_format\|datetimeFormat\|time_zone\|timeZone\|sql_date_and_time_time_zone\|sqlDateAndTimeTimeZone\|c_format\|cFormat\|url_escaping_charset\|urlEscapingCharset\|output_encoding\|outputEncoding\|classic_compatible\|classicCompatible\|parse\|ignore_missing\|ignoreMissing'
exe 'syn match ftlNamedParam /\<\%('.s:named_params.'\)\>\%(\s*=[^=]\)\@=/ contained'

" Method before Identifier so `.now` wins over bare names
syn cluster ftlExpr contains=ftlStringD,ftlStringS,ftlBuiltin,ftlMethod,ftlNamedParam,ftlIdentifier,ftlNumber,ftlOperator,ftlBoolean

" transparent regions — only contained groups paint
" CRITICAL: `/<\/\?#/` alone also matches the `<#` of comments `<#--…-->`, so
" identifiers inside comments (e.g. `rs`) get ftlIdentifier colour. Exclude `--`.
syn region ftlDirective start=/<\/\?#\%(--\)\@!/ end=/\/\?>/ transparent keepend contains=ftlDirKeyword,@ftlExpr
syn region ftlDirectiveSquare start=/\[\/\?#\%(--\)\@!/ end=/\/\?]/ transparent keepend contains=ftlDirKeyword,@ftlExpr
syn region ftlUserDirective start=/<\/\?@/ end=/\/\?>/ transparent keepend contains=ftlUserName,@ftlExpr
syn region ftlUserDirectiveSquare start=/\[\/\?@/ end=/\/\?]/ transparent keepend contains=ftlUserName,@ftlExpr
syn region ftlInterpolation start="${" end="}" transparent keepend contains=@ftlExpr

" Link to colorscheme groups — NEVER hardcode near-white guifg/ctermfg.
" Absolute #eeeeee / ctermfg=255 vanishes on light terminal themes.
"
" Stock Vim Comment is bright blue (#80a0ff / ctermfg 11). Mute FTL
" comments to a subdued green when that default is active; otherwise
" follow Comment so theme-aware schemes keep working.
function! s:ApplyFtlCommentHighlight() abort
  let l:guifg = synIDattr(hlID('Comment'), 'fg#')
  let l:ctermfg = synIDattr(hlID('Comment'), 'fg', 'cterm')
  if l:guifg =~? '^#80a0ff$' || l:ctermfg ==# '11'
    hi! ftlComment guifg=#6A9955 ctermfg=8
    hi! ftlCommentSquare guifg=#6A9955 ctermfg=8
  else
    hi! link ftlComment Comment
    hi! link ftlCommentSquare Comment
  endif
endfunction

call s:ApplyFtlCommentHighlight()

augroup ftl_dev_comment_hi
  autocmd!
  autocmd ColorScheme * call s:ApplyFtlCommentHighlight()
augroup END

hi def link ftlDirKeyword Statement
hi def link ftlUserName Type
hi def link ftlBuiltin Special
hi def link ftlMethod Function
hi def link ftlNamedParam PreProc
hi def link ftlIdentifier Identifier
hi def link ftlNumber Number
hi def link ftlOperator Operator
hi def link ftlBoolean Boolean
hi def link ftlStringD String
hi def link ftlStringS String

let b:current_syntax = "freemarker"
