-- LSP Plugins
return {
  {
    -- Lua development enhancements (Neovim API annotations)
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        { path = 'luvit-meta/library', words = { 'vim%.uv' } },
      },
    },
  },
  { 'Bilal2453/luvit-meta', lazy = true },

  {
    -- Mason setup for installing LSPs
    'williamboman/mason.nvim',
    build = ':MasonUpdate',
    config = true,
  },

  {
    -- Mason integration with LSP
    'williamboman/mason-lspconfig.nvim',
    dependencies = { 'williamboman/mason.nvim' },
  },

  {
    -- Tool installer
    'WhoIsSethDaniel/mason-tool-installer.nvim',
    dependencies = { 'williamboman/mason.nvim' },
  },

  {
    -- Blink completion engine (builds fuzzy matcher from nightly Rust)
    'saghen/blink.cmp',
    dependencies = {
      'rafamadriz/friendly-snippets',
      'hrsh7th/cmp-nvim-lsp', -- optional compatibility
    },
    version = '1.*',
    -- Build from source with nightly Rust (requires rustup nightly)
    build = 'cargo +nightly build --release',
    opts = {
      keymap = { preset = 'default' },
      appearance = { nerd_font_variant = 'mono' },
      completion = { documentation = { auto_show = false } },
      sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
      fuzzy = {
        -- Prefer Rust fuzzy matcher for better performance
        implementation = 'prefer_rust_with_warning',
      },
    },
    opts_extend = { 'sources.default' },
  },

  {
    -- Useful LSP progress/status updates
    'j-hui/fidget.nvim',
    opts = {},
  },

  {
    -- Main LSP configuration
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      'saghen/blink.cmp',
      'j-hui/fidget.nvim',
    },
    config = function()
      local blink = require 'blink.cmp'
      local capabilities = vim.tbl_deep_extend('force', vim.lsp.protocol.make_client_capabilities(), blink.get_lsp_capabilities())

      local servers = {
        basedpyright = {
          settings = {
            basedpyright = {
              typeCheckingMode = 'basic',
              reportMissingImports = true,
              reportMissingTypeStubs = false,
              reportUnknownMemberType = false,
              reportUnknownArgumentType = false,
              reportUnknownVariableType = false,
              reportUnknownParameterType = false,
              reportOptionalMemberAccess = false,
              reportOptionalSubscript = false,
              reportOptionalCall = false,
              reportGeneralTypeIssues = false,
              ignore = { '**/lightning/pytorch' },
            },
          },
        },
        emmet_language_server = {},
        ts_ls = {},
        cssls = {},
        cssmodules_ls = {},
        tailwindcss = {},
        html = {},
        eslint_d = {},
        prettierd = {},
        lua_ls = {
          settings = {
            Lua = {
              completion = { callSnippet = 'Replace' },
            },
          },
        },
        -- ✅ Add Rust LSP setup
        rust_analyzer = {
          settings = {
            ['rust-analyzer'] = {
              cargo = { allFeatures = true },
              checkOnSave = { command = 'clippy' },
            },
          },
        },
      }

      local ensure_installed = vim.tbl_keys(servers)
      vim.list_extend(ensure_installed, { 'stylua' })

      require('mason').setup()
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      require('mason-lspconfig').setup {
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            server.capabilities = capabilities

            vim.lsp.config[server_name] = vim.tbl_deep_extend('force', {
              capabilities = capabilities,
              on_attach = function(client, bufnr)
                local map = function(keys, func, desc, mode)
                  mode = mode or 'n'
                  vim.keymap.set(mode, keys, func, { buffer = bufnr, desc = 'LSP: ' .. desc })
                end

                map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
                map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
                map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
                map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
                map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
                map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
                map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction', { 'n', 'x' })
                map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

                if client.supports_method 'textDocument/inlayHint' then
                  map('<leader>th', function()
                    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = bufnr })
                  end, '[T]oggle Inlay [H]ints')
                end
              end,
            }, server)

            vim.lsp.start(vim.lsp.config[server_name])
          end,
        },
      }
    end,
  },
}
