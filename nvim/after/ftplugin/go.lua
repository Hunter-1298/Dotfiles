local bufnr = vim.api.nvim_get_current_buf()
--go nvim keybinding
vim.api.nvim_set_keymap(
  'n', -- Insert mode
  '<leader>g', -- Keybinding (Ctrl+e, or choose your own)
  'oif err !=  nil {<CR><TAB>fmt.Println("err: %v", err)<ESC>}', -- Opens a new line and inserts the snippet with newlines
  { noremap = true, silent = true, desc = 'Go error' }
)
