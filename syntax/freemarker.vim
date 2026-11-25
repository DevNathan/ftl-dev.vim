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

syn match ftlDocTag /\c@\%(nodoc\|deprecated\|see\|since\|stop\|example\|note\|remarks\|todo\|author\|version\|returns\?\|param\)\>/ contained
syn match ftlDocTag /\c@param\>/ contained nextgroup=ftlDocParamType,ftlDocParam skipwhite
syn match ftlDocParamType /{[^}]*}/ contained nextgroup=ftlDocParam skipwhite
syn match ftlDocParam /\[\?\zs[A-Za-z_][A-Za-z0-9_.]*/ contained
syn match ftlDocTag /\c@returns\?\>/ contained nextgroup=ftlDocType skipwhite
syn match ftlDocType /{[^}]*}/ contained

let s:dirs = join(ftl_dev#complete#directives(), '\|')

" --- atoms (no [\w] inside collections) ---
" [?] = literal question mark (avoid bare ? / \? quantifier ambiguity)
syn match ftlBuiltin /[?][a-zA-Z_][a-zA-Z0-9_]*/ contained
syn match ftlMethod /\.[a-zA-Z_][a-zA-Z0-9_]*/ contained
syn match ftlIdentifier /\<[a-zA-Z_][a-zA-Z0-9_]*\>/ contained
syn match ftlNumber /\<[0-9]\+\%(\.[0-9]\+\)\=\>/ contained
syn match ftlOperator /[=<>!+\-*\/%|&]/ contained
syn keyword ftlBoolean true false contained
syn region ftlStringD start=/"/ skip=/\\./ end=/"/ contained contains=ftlInterpolation,ftlEscape
syn region ftlStringS start=/'/ skip=/\\./ end=/'/ contained contains=ftlInterpolation,ftlEscape
syn match ftlEscape /\\./ contained
syn region ftlRawString start=/\<r"/ end=/"/ contained
syn region ftlRawString start=/\<r'/ end=/'/ contained
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
syn region ftlComment start=/<#--/ end=/-->/ contains=ftlComment,ftlCommentSquare,ftlDocTag keepend extend
syn region ftlCommentSquare start=/\[#--/ end=/--]/ contains=ftlComment,ftlCommentSquare,ftlDocTag keepend extend

syn cluster ftlExpr contains=ftlComment,ftlCommentSquare,ftlStringD,ftlStringS,ftlRawString,ftlBuiltin,ftlMethod,ftlNamedParam,ftlIdentifier,ftlNumber,ftlOperator,ftlBoolean

syn cluster ftlExpr add=ftlParenExpr,ftlIndexExpr,ftlHashExpr
syn region ftlParenExpr matchgroup=ftlDelimiter start=/(/ end=/)/ contained transparent contains=@ftlExpr
syn region ftlIndexExpr matchgroup=ftlDelimiter start=/\[\%([#@\/]\)\@!/ end=/]/ contained transparent contains=@ftlExpr
syn region ftlHashExpr matchgroup=ftlDelimiter start=/\%([$#]\)\@<!{/ end=/}/ contained transparent contains=@ftlExpr

" transparent regions — only contained groups paint
" CRITICAL: `/<\/\?#/` alone also matches the `<#` of comments `<#--…-->`, so
" identifiers inside comments (e.g. `rs`) get ftlIdentifier colour. Exclude `--`.
syn region ftlDirective start=/<\/\?#\%(--\)\@!/ matchgroup=ftlDelimiter end=/\/\?>/ transparent contains=ftlDirKeyword,@ftlExpr
syn region ftlDirectiveSquare start=/\[\/\?#\%(--\)\@!/ matchgroup=ftlDelimiter end=/\/\?]/ transparent contains=ftlDirKeyword,@ftlExpr
syn region ftlUserDirective start=/<\/\?@/ matchgroup=ftlDelimiter end=/\/\?>/ transparent contains=ftlUserName,@ftlExpr
syn region ftlUserDirectiveSquare start=/\[\/\?@/ matchgroup=ftlDelimiter end=/\/\?]/ transparent contains=ftlUserName,@ftlExpr
syn region ftlInterpolation start="${" matchgroup=ftlDelimiter end="}" transparent contains=@ftlExpr

" Shared HTML and SQL tokens. Keep these names independent of the editor's
" bundled HTML syntax and selected SQL dialect.
syn cluster ftlTemplate contains=ftlDirective,ftlDirectiveSquare,ftlUserDirective,ftlUserDirectiveSquare,ftlInterpolation,ftlComment,ftlCommentSquare
syn region ftlHtmlTag matchgroup=ftlHtmlTagName start=+</\?[A-Za-z][A-Za-z0-9_:-]*+ matchgroup=ftlHtmlDelimiter end=+/\?>+ contains=ftlHtmlAttribute,ftlHtmlString,@ftlTemplate
syn match ftlHtmlAttribute /[A-Za-z_:][A-Za-z0-9_.:-]*/ contained
syn region ftlHtmlString start=+"+ end=+"+ contained contains=@ftlTemplate,ftlHtmlEntity
syn region ftlHtmlString start=+'+ end=+'+ contained contains=@ftlTemplate,ftlHtmlEntity
syn match ftlHtmlEntity /&\%(#\d\+\|#[xX]\x\+\|[A-Za-z][A-Za-z0-9]*\);/
syn region ftlHtmlComment start=+<!--+ end=+-->+
syn region ftlHtmlDoctype start=+\c<!DOCTYPE\>+ end=+>+

syn case ignore
syn keyword ftlSqlKeyword contained select insert into values update delete from where set and or not null merge with join on order group by
syn keyword ftlSqlKeyword contained as distinct all inner outer left right full cross having union intersect except exists between in is like asc desc limit offset
syn keyword ftlSqlKeyword contained create alter drop table view index case when then else end over partition returning begin commit rollback
syn case match
syn match ftlSqlNumber /\<\d\+\%(\.\d\+\)\?\>/ contained
syn match ftlSqlBind /\%(\k\|@\)\@<!@\%(\d\)\@!\k\+/ contained
syn region ftlSqlString matchgroup=ftlSqlString start=+'+ skip=+''+ end=+'+ contained contains=ftlSqlQuoteEscape,@ftlTemplate
syn match ftlSqlQuoteEscape /''/ contained
syn region ftlSqlString start=+"+ skip=+""+ end=+"+ contained contains=@ftlTemplate
syn region ftlSqlComment start=+/\*+ end=+\*/+ contained
" A SQL line comment consumes the rest of its line, including tag-like text.
" Include the EOL insertion point so a delimiter typed there stays in the comment.
syn match ftlSqlComment /--.*\n/ contained extend
syn cluster ftlSqlBody contains=@ftlTemplate,ftlSqlKeyword,ftlSqlNumber,ftlSqlBind,ftlSqlString,ftlSqlComment

" The capture opener is painted by ftlDirective. End before the matching
" closer so an unfinished SQL quote/comment cannot color the next block.
let s:capture = '<#\z(assign\|local\|global\)\s\+'
let s:capture_tail = '\%(\s\+in\s\+[A-Za-z_][A-Za-z0-9_.]*\)\?\s*>'
let s:capture_end = ' end=+\ze</#\z1\s*>+ keepend contains=@ftlSqlBody'
execute 'syn region ftlSqlCapture start=+' . s:capture . '[sS][qQ][lL]\w*' . s:capture_tail . '+' . s:capture_end
execute 'syn region ftlSqlMarkedCapture contained start=+' . s:capture . '[A-Za-z_]\w*' . s:capture_tail . '+' . s:capture_end
syn match ftlSqlMarker /<#--\s*\c@lang\s\+sql\s*-->/ contains=ftlLangTag nextgroup=ftlSqlMarkedCapture skipwhite skipnl skipempty
syn match ftlLangTag /\c@lang\>/ contained
" A capture or marker can start far above the visible window.
syn sync fromstart

hi def link ftlDelimiter Delimiter
hi def link ftlHtmlTagName Statement
hi def link ftlHtmlDelimiter Delimiter
hi def link ftlHtmlAttribute Type
hi def link ftlHtmlString String
hi def link ftlHtmlComment Comment
hi def link ftlHtmlDoctype PreProc
hi def link ftlHtmlEntity Special
hi def link ftlSqlKeyword Statement
hi def link ftlSqlString String
hi def link ftlSqlQuoteEscape SpecialChar
hi def link ftlSqlBind Identifier
hi def link ftlSqlNumber Number
hi def link ftlSqlComment Comment
hi def link ftlSqlMarker ftlComment
hi def link ftlLangTag ftlDocTag

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

hi def link ftlDocTag SpecialComment
hi def link ftlDocParam Identifier
hi def link ftlDocParamType Type
hi def link ftlDocType Type
hi def link ftlRawString String
hi def link ftlEscape SpecialChar
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
