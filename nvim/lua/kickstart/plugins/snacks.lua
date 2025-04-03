return {
  { -- Collection of various small independent plugins/modules
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      indent = { enabled = true },
      animate = { enabled = true },
      dim = { enabled = true },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
