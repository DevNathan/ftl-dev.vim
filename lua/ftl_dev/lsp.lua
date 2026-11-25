-- Optional Neovim helper: start the ftl-dev language server for freemarker buffers.
-- The language server lives in the ftl-dev monorepo (server/), not in this plugin.
--
--   require("ftl_dev.lsp").setup({
--     cmd = { "node", "/path/to/ftl-dev/server/out/server/src/cli.js", "--stdio" },
--   })

local M = {}

function M.setup(opts)
  opts = opts or {}
  local cmd = opts.cmd
  if type(cmd) ~= "table" or #cmd == 0 then
    vim.notify(
      "ftl_dev.lsp: pass opts.cmd = { \"node\", \"…/server/out/server/src/cli.js\", \"--stdio\" }",
      vim.log.levels.ERROR
    )
    return
  end

  local function attach(buf)
    local name = vim.api.nvim_buf_get_name(buf)
    local root = opts.root_dir or (vim.fs.root and vim.fs.root(buf, { ".ftl-data-model.json", ".git" }))
    vim.lsp.start({
      name = "ftl-dev",
      cmd = cmd,
      root_dir = root or vim.fs.dirname(name) or vim.fn.getcwd(),
      init_options = opts.init_options,
      on_attach = opts.on_attach,
    }, { bufnr = buf })
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("ftl_dev_lsp", { clear = true }),
    pattern = "freemarker",
    callback = function(ev) attach(ev.buf) end,
  })
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "freemarker" then
      attach(buf)
    end
  end
end

return M
