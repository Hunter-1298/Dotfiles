return {
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl', -- This tells lazy.nvim that the main module is 'ibl'
    opts = {
      -- Place any configuration here, for example:
      indent = { char = '│', highlight = 'IblIndent' },
      scope = { enabled = true, highlight = 'IblScope' },
    },
    config = function()
      -- Call the setup method to initialize the plugin
      require('ibl').setup {
        indent = {
          char = '│', -- Character used for indent lines
          highlight = 'IblIndent', -- Define the highlight group for indentation
        },
        scope = {
          enabled = true,
          highlight = 'IblScope', -- Define the highlight group for scope
        },
      }
    end,
  },
}
