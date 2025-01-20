-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  {
    'akinsho/bufferline.nvim',
    lazy = false, -- make sure Lualine is not lazy-loaded
    config = function()
      require('bufferline').setup {
        options = {
          numbers = 'buffer_id',
        },
      }
    end,
  },
}
