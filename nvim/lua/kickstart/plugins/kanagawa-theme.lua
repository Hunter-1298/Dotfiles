return {
  { -- You can easily change to a different colorscheme.
    -- Change the name of the colorscheme plugin below, and then
    -- change the command in the config to whatever the name of that colorscheme is.
    --
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
    'rebelot/kanagawa.nvim',
    name = 'kanagawa',
    priority = 1000,
    init = function()
      -- wave or dragon mode
      -- vim.cmd.colorscheme 'kanagawa-dragon'
      vim.cmd.colorscheme 'kanagawa-wave'

      -- You can configure highlights by doing something like:
      vim.cmd 'hi Comment gui=none'
    end,
  },
}
