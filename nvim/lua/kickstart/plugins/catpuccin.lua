return {
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    config = function()
      require('catppuccin').setup {
        transparent_background = true, -- Enables transparency
        styles = {
          comments = { 'italic' }, -- Style for comments (optional)
        },
        integrations = {
          telescope = true, -- Enable integration with Telescope (optional)
          nvimtree = {
            enabled = true,
            show_root = true,
          },
        },
      }
      -- Load the colorscheme
      -- vim.cmd.colorscheme 'catppuccin-mocha'
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
