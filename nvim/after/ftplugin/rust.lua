local bufnr = vim.api.nvim_get_current_buf()
vim.keymap.set('n', '<leader>a', function()
  vim.cmd.RustLsp 'codeAction' -- supports rust-analyzer's grouping
  -- or vim.lsp.buf.codeAction() if you don't want grouping.
end, { silent = true, buffer = bufnr, desc = 'Ruct Code Action - suggests changes' })

vim.keymap.set(
  'n',
  'K', -- Override Neovim's built-in hover keymap with rustaceanvim's hover actions
  function()
    vim.cmd.RustLsp { 'hover', 'action' }
  end,
  { silent = true, buffer = bufnr, desc = 'Overrides neovim built in over with rust hover' }
)

--rustacean nvim keybinding
vim.keymap.set('n', '<leader>dt', '<cmd>lua vim.cmd("RustLsp testables")<CR>', { desc = 'Debugger testables' })
