-- [[ Basic meymaps ]]
--  mee `:help vim.keymap.set()`
-- Change workign director to  current file dir
vim.api.nvim_set_keymap('n', '<leader>cd', ':cd %:p:h<CR>', { noremap = true, silent = true, desc = 'Change dir to curr file dir' })

-- Set buffer next and buufer previous keymaps
-- Mapping toggle comments
-- vim.keymap.set('n', '<leader>ct', '<cmd>norm gcc<CR>', { noremap = false, silent = true, desc = 'Comment Toggle' })
-- vim.keymap.set('v', '<leader>ct', '<cmd>norm gc<CR>', { noremap = false, silent = true, desc = 'Comment Toggle' })

-- Setting vsp buffer keymap
vim.keymap.set('n', '<leader>vsp', function()
  local buffer_number = vim.fn.input 'Buffer number: '
  if buffer_number == '' then
    return -- Exit if the prompt is canceled or left empty
  end
  vim.cmd('vsp | b' .. buffer_number)
end, { desc = 'Vertical split with buffer selection' })

-- Setting vsp buffer keymap
vim.keymap.set('n', '<leader>sp', function()
  local buffer_number = vim.fn.input 'Buffer number: '
  if buffer_number == '' then
    return -- Exit if the prompt is canceled or left empty
  end
  vim.cmd('sp | b' .. buffer_number)
end, { desc = 'Vertical split with buffer selection' })

vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic keymaps
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- TIP: Disable arrow keys in normal mode
vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

vim.keymap.set('n', '<Tab>', ':bn<CR>', { noremap = true, silent = true, desc = 'Buffer Next' })
vim.keymap.set('n', '<S-Tab>', ':bp<CR>', { noremap = true, silent = true, desc = 'Buffer Prev' })
-- Keybinds to make split navigatiob easier.
--  Use CTRL+<hjkl> to switch between windows
--w><C-h>
--  See `:help wincmd` for a list of all window commands
--  setting a keymao to open split screens in a new buffer
vim.api.nvim_create_user_command('Sp', function()
  vim.cmd 'split'
  vim.cmnd 'enew'
end, {})
vim.api.nvim_create_user_command('Vp', function()
  vim.cmd 'split'
  vim.cmnd 'enew'
end, {})

vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })
-- Resize splits using Alt + h, j, k, l
vim.keymap.set('n', '<A-l>', '<C-w><', { desc = 'Resize window left' })
vim.keymap.set('n', '<A-h>', '<C-w>>', { desc = 'Resize window right' })
vim.keymap.set('n', '<A-j>', '<C-w>+', { desc = 'Resize window down' })
vim.keymap.set('n', '<A-k>', '<C-w>-', { desc = 'Resize window up' })

-- TOGGLE TERM
vim.keymap.set('n', '<leader>t', ':ToggleTerm size=10 direction=float<CR>', {
  noremap = true,
  silent = true,
  desc = 'Toggle horizontal Terminal on Desktop',
})
vim.keymap.set('n', '<leader>ht', ':ToggleTerm size=10 direction=horizontal<CR>', {
  noremap = true,
  silent = true,
  desc = 'Toggle horizontal Terminal on Desktop',
})
vim.keymap.set('n', '<leader>vt', ':ToggleTerm size=40 direction=vertical<CR>', {
  noremap = true,
  silent = true,
  desc = 'Toggle Vertical Terminal on Desktop',
})
-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- vim: ts=2 sts=2 sw=2 et
