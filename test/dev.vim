set nocompatible
set encoding=utf-8
let g:ftl_dev_delimiter_pairs = get(g:, 'ftl_dev_delimiter_pairs', 1)
let s:root = expand('<sfile>:p:h:h')
let &runtimepath = escape(s:root, ',') . ',' . escape($VIMRUNTIME, ',')
let &packpath = &runtimepath
if exists('g:did_load_filetypes')
  filetype off
endif
set backspace=indent,eol,start
set shiftwidth=2 softtabstop=2 expandtab
set completeopt=menuone,noinsert,noselect
set pumheight=5
packadd matchit
if has('nvim')
lua << LUA
require("ftl_dev.lsp").setup({
  cmd = { "node", vim.env.FTL_DEV_SERVER, "--stdio" },
  init_options = vim.g.ftl_dev_init_options,
  on_attach = function(client, buf)
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = buf })
    vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = buf })
    if vim.lsp.completion then
      vim.lsp.completion.enable(true, client.id, buf, {
        autotrigger = false,
        convert = function() return { menu = "" } end,
      })
    end
  end,
})
LUA
else
  let &runtimepath = escape(s:root . '/test/vendor/lsp', ',') . ',' . &runtimepath
  let g:lsp_servers = [{'name': 'ftl-dev', 'filetype': ['freemarker'],
        \ 'path': exepath('node'), 'args': [$FTL_DEV_SERVER, '--stdio'],
        \ 'initializationOptions': get(g:, 'ftl_dev_init_options', {}),
        \ 'rootSearch': ['.ftl-data-model.json', '.git/']}]
  let g:lsp_options = {'semanticHighlight': v:true, 'omniComplete': v:true,
        \ 'autoComplete': v:false, 'condensedCompletionMenu': v:true, 'showSignature': v:false}
  augroup ftl_dev_playground
    autocmd!
    autocmd FileType freemarker nnoremap <silent><buffer> gd <Cmd>LspGotoDefinition<CR>
    autocmd FileType freemarker nnoremap <silent><buffer> K <Cmd>LspHover<CR>
  augroup END
endif
augroup ftl_dev_test_folds
  autocmd!
  autocmd FileType freemarker setlocal foldmethod=expr foldexpr=ftl_dev#fold#level(v:lnum) foldlevel=99
augroup END
filetype plugin indent on
syntax enable
