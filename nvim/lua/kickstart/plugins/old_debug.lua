return {
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      'nvim-neotest/nvim-nio',
      'rcarriga/nvim-dap-ui',
      'mfussenegger/nvim-dap-python',
      'theHamsta/nvim-dap-virtual-text',
    },

    keys = function(_, keys)
      local dap = require 'dap'
      local dapui = require 'dapui'
      return {
        -- Baic debugging keymap, feel free to change to your liking!
        { '<leader>dc', dap.continue, desc = 'Debug: Start/Continue' },
        { '<leader>di', dap.step_into, desc = 'Debug: Step Into' },
        { '<leader>dn', dap.step_over, desc = 'Debug: Next - (Step Over)' },
        { '<leader>do', dap.step_out, desc = 'Debug: Step Out' },
        { '<leader>db', dap.toggle_breakpoint, desc = 'Debug: Toggle Breakpoint' },
        { '<leader>dq', dap.terminate, desc = 'Debug: Quit' },
        { '<leader>dt', dapui.toggle, desc = 'Debug: Toggle' },
        { '<leader>dx', dap.repl.open, desc = 'Debug: Repl' },
        {
          '<leader>dB',
          function()
            dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
          end,
          desc = 'Debug: Set Breakpoint',
        },
        {
          '<leader>xp',
          function()
            -- Prompt the user for a command to execute in the REPL
            local command = vim.fn.input 'Enter REPL command: '
            if command and command ~= '' then
              dap.repl.execute(command)
              print('Executed: ' .. command)
            else
              print 'No command entered'
            end
          end,
          desc = 'Debug: Execute custom REPL command',
        },

        unpack(keys),
      }
    end,

    config = function()
      local dap = require 'dap'
      local dapui = require 'dapui'
      local dap_python = require 'dap-python'

      require('dapui').setup {}
      require('nvim-dap-virtual-text').setup {
        commented = true, -- Show virtual text alongside comment
      }

      dap_python.setup 'python3'

      vim.fn.sign_define('DapBreakpoint', {
        text = '',
        texthl = 'DiagnosticSignError',
        linehl = '',
        numhl = '',
      })

      vim.fn.sign_define('DapBreakpointRejected', {
        text = '', -- or "❌"
        texthl = 'DiagnosticSignError',
        linehl = '',
        numhl = '',
      })

      vim.fn.sign_define('DapStopped', {
        text = '', -- or "→"
        texthl = 'DiagnosticSignWarn',
        linehl = 'Visual',
        numhl = 'DiagnosticSignWarn',
      })

      -- Automatically open/close DAP UI
      dap.listeners.after.event_initialized['dapui_config'] = function()
        dapui.open()
      end

      local opts = { noremap = true, silent = true }
    end,
  },
}
