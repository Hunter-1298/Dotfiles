-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)

return {
  -- NOTE: Yes, you can install new plugins here!
  'mfussenegger/nvim-dap',
  -- NOTE: And you can specify dependencies as well
  dependencies = {
    -- Creates a beautiful debugger UI
    'rcarriga/nvim-dap-ui',
    -- Required dependency for nvim-dap-ui
    'nvim-neotest/nvim-nio',
    -- Installs the debug adapters for you
    'williamboman/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',
    -- Add your own debuggers here
    'leoluz/nvim-dap-go',
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
      { '<leader>dt', dapui.toggle, desc = 'Debug: Toggle' },
      { '<leader>dl', dapui.toggle, desc = 'Debug: Close' },
      { '<leader>dx', dap.repl.open, desc = 'Debug: Close' },
      {
        '<leader>dB',
        function()
          dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
        end,
        desc = 'Debug: Set Breakpoint',
      },
      -- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
      { '<leader>dr', dapui.toggle, desc = 'Debug: See last session result.' },
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
    -- Dap UI setup
    -- For more information, see |:help nvim-dap-ui|
    dapui.setup {
      -- Set icons to characters that are more likely to work in every terminal.
      --    Feel free to remove or use ones that you like more! :)
      --    Don't feel like these are good choices.
      icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
      controls = {
        icons = {
          pause = '⏸',
          play = '▶',
          step_into = '⏎',
          step_over = '⏭',
          step_out = '⏮',
          step_back = 'b',
          run_last = '▶▶',
          terminate = '⏹',
          disconnect = '⏏',
        },
      },
    }

    -- Change breakpoint icons
    -- vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
    -- vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
    -- local breakpoint_icons = vim.g.have_nerd_font
    --     and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
    --   or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
    -- for type, icon in pairs(breakpoint_icons) do
    --   local tp = 'Dap' .. type
    --   local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
    --   vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
    -- end

    -- Open DAP UI automatically when debugging starts
    dap.listeners.after.event_initialized['dapui_config'] = function()
      dapui.open()
    end
    -- Close DAP UI when debugging stops
    dap.listeners.before.event_terminated['dapui_config'] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited['dapui_config'] = function()
      dapui.close()
    end

    local function map_dap_keys()
      -- Dynamically map keys for debugging
      vim.api.nvim_buf_set_keymap(0, 'n', 'n', "<Cmd>lua require('dap').step_over()<CR>", { noremap = true, silent = true, desc = 'Debug: Next - (Step Over)' })
    end

    -- Hook into DAP events to dynamically map/unmap keys
    dap.listeners.after.event_initialized['dap_keys'] = function()
      map_dap_keys() -- Map keys when debugging starts
    end
    dap.listeners.before.event_terminated['dap_keys'] = function()
      vim.api.nvim_buf_del_keymap(0, 'n') -- Remove mapping when debugging stops
    end
    dap.listeners.before.event_exited['dap_keys'] = function()
      vim.api.nvim_buf_del_keymap(0, 'n') -- Remove mapping when debugging exits
    end
    -- nvim-dap-go setup
    require('dap-go').setup {
      delve = {
        path = '/home/hshayde/go/bin/dlv',
      },
      buildFlags = "-gcflags 'all=-N -1'",
    }
  end,
}
