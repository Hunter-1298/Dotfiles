-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
-- Set Python 3 interpreter
vim.g.python3_host_prog = '/usr/bin/python'
-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true
vim.opt.fileformats = { 'unix', 'dos' }
vim.api.nvim_set_keymap('n', '<leader>bd', ':bd<CR>', { noremap = true, silent = true, desc = 'Delete Buffer' })
-- [[ Setting options ]]
require 'options'

-- [[ Basic Keymaps ]]
require 'keymaps'
-- [[ Install `lazy.nvim` plugin manager ]]
require 'lazy-bootstrap'

if vim.g.vscode then
  require('lazy').setup {
    require 'custom.plugins.flash',
  }
  vim.cmd [[source $HOME/.config/nvim/vscode/settings.vim]]
else
  -- [[ Configure and install plugins ]]
  require 'lazy-plugins'
  -- The line beneath this is called `modeline`. See `:help modeline`
  -- vim: ts=2 sts=2 sw=2 et
  vim.cmd [[
    augroup SetCmpSelHighlight
      autocmd!
      autocmd VimEnter * lua vim.api.nvim_set_hl(0, 'CmpSel', { bg = '#4CAF50', fg = '#2E3440', bold = true })
    augroup END
  ]]
end
