return {
  { -- You can easily change to a different colorscheme.
    -- Change the name of the colorscheme plugin below, and then
    -- change the command in the config to whatever the name of that colorscheme is.
    --
    'olimorris/onedarkpro.nvim',
    priority = 1000, -- Ensure it loads first
    config = function()
      require('onedarkpro').setup {
        options = {
          transparency = true,
        },
      }

      -- Load the colorscheme
      vim.cmd.colorscheme 'onedark_vivid'

      -- You can configure highlights by doing something like:
      vim.cmd.hi 'Comment gui=none'
    end,
  },
}

