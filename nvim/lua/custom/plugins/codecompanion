return {
  {
    'olimorris/codecompanion.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    config = function()
      require('codecompanion').setup {
        strategies = {
          chat = {
            adapter = 'gemini',
          },
          inline = {
            adapter = 'gemini',
            keymaps = {
              accept_change = {
                modes = { n = '<leader>a' },
                description = 'Accept Code Changes',
              },
              reject_change = {
                modes = { n = '<leader>r' },
                description = 'Reject Code Changes',
              },
            },
          },
        },
      }
    end,
    keys = {
      { mode = 'n', '<leader>cc', '<cmd>CodeCompanion chat<cr>', desc = 'CodeCompanion Chat' },
      { mode = 'v', '<leader>cc', '<cmd>CodeCompanion<cr>', desc = 'CodeCompanion Inline' },
    },
  },
}
