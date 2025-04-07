return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    'MunifTanjim/nui.nvim',
  },
  cmd = 'Neotree',
  keys = {
    { '<leader>e', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
  },
  opts = {
    filesystem = {
      window = {
        mappings = {
          ['<leader>e'] = 'close_window',
          ['-'] = 'navigate_up',
          ['v'] = 'open_vsplit',
        },
      },
    },
    event_handlers = {
      {
        event = 'after_render',
        handler = function()
          local state = require('neo-tree.sources.manager').get_state 'filesystem'
          if not require('neo-tree.sources.common.preview').is_active() then
            state.config = { use_float = true } -- use split instead of floating preview
            state.commands.toggle_preview(state)
          end
        end,
      },
    },
  },
}
