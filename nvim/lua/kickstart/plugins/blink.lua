return {
  {
    'saghen/blink.cmp',
    dependencies = {
      'rafamadriz/friendly-snippets',
      'hrsh7th/cmp-nvim-lsp',
    },
    version = '1.*', -- prebuilt binaries
    opts = {
      keymap = { preset = 'enter' }, -- Enter accepts
      appearance = { nerd_font_variant = 'mono' },
      completion = { documentation = { auto_show = false } },
      sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
      fuzzy = { implementation = 'lua' }, -- use Lua matcher
    },
    config = function(_, opts)
      local blink = require 'blink.cmp'
      blink.setup(opts)

      -- Tab to select next, Shift-Tab to select previous
      vim.keymap.set('i', '<Tab>', function()
        if blink.is_visible() then
          blink.select_next()
        else
          return '<Tab>'
        end
      end, { expr = true, noremap = true })

      vim.keymap.set('i', '<S-Tab>', function()
        if blink.is_visible() then
          blink.select_prev()
        else
          return '<S-Tab>'
        end
      end, { expr = true, noremap = true })
    end,
  },
}
