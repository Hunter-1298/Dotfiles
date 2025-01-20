--adding rust tools, make sure rust-analyzer is installed in local toolchain
return {
  -- amongst your other plugins
  {
    'saecki/crates.nvim',
    tag = 'stable',
    ft = {"toml"},
    config = function()
      require('crates').setup{
        completion = {
            cmp = {
                enabled = true
            },
        },
    }
    require('cmp').setup.buffer({
        sources = { { name = "crates" } }
        })
        end
  },
}
