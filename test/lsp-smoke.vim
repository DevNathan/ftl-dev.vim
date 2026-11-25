set hidden
if has('nvim')
lua << LUA
local ok, err = pcall(function()
  assert(vim.wait(5000, function()
    local c = vim.lsp.get_clients({bufnr = 0, name = "ftl-dev"})[1]
    return c and c.initialized
  end), "Neovim client did not attach")
  local client = vim.lsp.get_clients({bufnr = 0})[1]
  local doc = { uri = vim.uri_from_bufnr(0) }
  local function request(method, params)
    local response, why = client:request_sync(method, params, 4000, 0)
    assert(response and not response.err, vim.inspect(response or why))
    return response.result
  end
  local function at(line, col)
    return { textDocument = doc, position = { line = line, character = col } }
  end
  local hover = request("textDocument/hover", at(3, 13))
  assert(hover.contents.value:find("has_content", 1, true), "builtin hover")
  local defs = request("textDocument/definition", at(4, 10))
  assert(vim.uri_to_fname(defs[1].uri):match("lib%.ftl$"), "import definition")
  local locations = at(3, 6)
  locations.context = { includeDeclaration = true }
  assert(#request("textDocument/references", locations) == 3, "references")
  local rename = at(3, 6)
  rename.newName = "heading"
  local changes = request("textDocument/rename", rename).changes[doc.uri]
  assert(#changes == 3 and changes[1].newText == "heading", "same-file rename")
  local items = request("textDocument/completion", at(3, 14))
  assert(vim.iter(items):any(function(i) return i.label == "has_content" end), "completion")
  local help = request("textDocument/signatureHelp", at(4, 15))
  assert(help.signatures[1].label:find("greet", 1, true), "import signature")
  assert(#request("textDocument/documentSymbol", { textDocument = doc }) > 0, "outline")
  assert(#request("textDocument/documentLink", { textDocument = doc }) == 1, "document link")
  assert(#request("textDocument/semanticTokens/full", { textDocument = doc }).data > 0, "tokens")
  assert(#request("textDocument/linkedEditingRange", at(3, 2)).ranges == 2, "tag pair")
  local hits = request("workspace/symbol", {query = "greet"})
  assert(#hits == 1 and hits[1].location.uri == defs[1].uri, "unopened workspace file")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "${hostValue}", "${missingRoot}" })
  local function has_diag(line)
    return #vim.diagnostic.get(0, { lnum = line }) > 0
  end
  assert(vim.wait(3000, function() return not has_diag(0) and has_diag(1) end), "workspace diagnostics")
  vim.fn.writefile({ '{"roots":["missingRoot"]}' }, ".ftl-data-model.json")
  assert(vim.wait(3000, function() return has_diag(0) and not has_diag(1) end), "data-model reload")
end)
if not ok then io.stderr:write(tostring(err) .. "\n"); vim.cmd("cquit 1") end
LUA
else
  " -S runs before VimEnter, when yegappan/lsp normally attaches.
  call g:LspEnable()
  let s:start = reltime()
  while !g:LspServerReady() && reltimefloat(reltime(s:start)) < 5
    sleep 20m
  endwhile
  call assert_true(g:LspServerReady(), 'Vim client did not attach')
  if g:LspServerReady()
    call cursor(5, 11)
    normal gd
    let s:start = reltime()
    while expand('%:t') !=# 'lib.ftl' && reltimefloat(reltime(s:start)) < 3
      sleep 20m
    endwhile
    call assert_equal('lib.ftl', expand('%:t'), 'gd on lib.greet')
    edit main.ftl
    call cursor(4, 7)
    LspRename heading
    let s:start = reltime()
    while getline(2) !~# 'heading' && reltimefloat(reltime(s:start)) < 3
      sleep 20m
    endwhile
    call assert_match('assign heading', getline(2))
    call assert_match('greet(heading)', getline(5))
    call assert_equal('  No title', getline(7))
  endif
  if !empty(v:errors)
    call writefile(v:errors, '/dev/stderr')
    cquit 1
  endif
endif
qa!
