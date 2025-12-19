--@diagnostic disable: missing-fields

-- INFO: Minimal neovim confiugraion leveraging the new package manager vim.pack
-- minimal neovim configuration written in lua.

-- set <space> as the leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.opt.winborder = "rounded"

-- ui / editor options
vim.opt.termguicolors = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.undofile = true
vim.opt.signcolumn = "yes"
vim.opt.ignorecase = true
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
vim.opt.inccommand = "split"
vim.opt.cursorline = true
vim.opt.hlsearch = true
vim.opt.breakindent = true
vim.opt.wrap = true
vim.opt.fileformats = { "unix", "dos" }

-- formatting style
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.textwidth = 80

vim.diagnostic.config({
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = " ",
			[vim.diagnostic.severity.WARN] = " ",
			[vim.diagnostic.severity.INFO] = " ",
			[vim.diagnostic.severity.HINT] = " ",
		},
	},
	-- Inline diagnostics
	virtual_text = {
		prefix = "●",
		spacing = 2,
		source = "if_many",
	},

	underline = true,
	severity_sort = true,

	-- Don't update while typing
	update_in_insert = false,

	-- Floating diagnostics window
	float = {
		border = "rounded",
		header = "",
		prefix = "",
	},
})

-- Faster hover diagnostics
vim.o.updatetime = 250

-- Auto-show diagnostics on hover
vim.api.nvim_create_autocmd("CursorHold", {
	callback = function()
		vim.diagnostic.open_float(nil, { focus = false })
	end,
})

-- Project-wide diagnostics (built-in)
vim.keymap.set("n", "<leader>d", function()
	vim.diagnostic.setqflist({ open = true })
end, { desc = "All diagnostics (Quickfix)" })

-- keymaps
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")
vim.keymap.set("n", "<Tab>", ":bn<CR>", { noremap = true, silent = true, desc = "Buffer Next" })
vim.keymap.set("n", "<S-Tab>", ":bp<CR>", { noremap = true, silent = true, desc = "Buffer Prev" })
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })
vim.keymap.set("n", "<leader>vs", ":vsplit<CR>", { desc = "Split vertically" })
vim.keymap.set("n", "<leader>vh", ":split<CR>", { desc = "Split horizontally" })

-- INFO: plugins (using vim.pack)
vim.pack.add({
	{ src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
	{ src = "https://github.com/saghen/blink.cmp", version = "1.*" },
	{ src = "https://github.com/rktjmp/lush.nvim" },
	{ src = "https://github.com/ellisonleao/gruvbox.nvim" },
	{ src = "https://github.com/ribru17/bamboo.nvim" },
	{ src = "https://github.com/folke/tokyonight.nvim" },
	{ src = "https://github.com/scottmckendry/cyberdream.nvim" },

	-- core LSP and mason toolkit
	"https://github.com/neovim/nvim-lspconfig",
	"https://github.com/mason-org/mason.nvim",
	"https://github.com/mason-org/mason-lspconfig.nvim",
	"https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim",

	-- formatting: conform.nvim
	"https://github.com/stevearc/conform.nvim",

	-- fuzzy finder ecosystem
	"https://github.com/nvim-lua/plenary.nvim",
	"https://github.com/nvim-tree/nvim-web-devicons",
	"https://github.com/nvim-telescope/telescope.nvim",
	"https://github.com/nvim-telescope/telescope-ui-select.nvim",
	"https://github.com/aznhe21/actions-preview.nvim",

	-- which-key
	"https://github.com/folke/which-key.nvim",

	-- bufferline
	"https://github.com/akinsho/bufferline.nvim",

	-- statusline
	"https://github.com/nvim-mini/mini.statusline",
	"https://github.com/nvim-mini/mini.pairs",
	"https://github.com/nvim-mini/mini.animate",

	-- noice -- command line only
	"https://github.com/MunifTanjim/nui.nvim",
	"https://github.com/rcarriga/nvim-notify",
	"https://github.com/folke/noice.nvim",

	-- bufferline
	"https://github.com/akinsho/toggleterm.nvim",

	-- oil (file buffer browser)
	"https://github.com/stevearc/oil.nvim",
}, { confirm = false })

-- colorscheme
-- vim.cmd("colorscheme bamboo")
require("cyberdream").setup({ transparent = true })
vim.cmd("colorscheme cyberdream")

-- bufferline setup
require("bufferline").setup({})

-- ToggleTerm setup: horizontal terminal only
require("toggleterm").setup({
	size = function(term)
		if term.direction == "horizontal" then
			return 15 -- height of horizontal terminal in lines
		end
	end,
	direction = "horizontal", -- always horizontal
	start_in_insert = true, -- start terminal in insert mode
	close_on_exit = true, -- close terminal when process exits
	shade_terminals = true, -- darken terminal background
	persist_size = true, -- remember size
	persist_mode = true, -- remember insert/normal mode
	auto_scroll = true, -- scroll to bottom automatically
	terminal_mappings = true, -- mappings inside terminal
	hide_numbers = true, -- hide line numbers in terminal
})

-- Create a terminal object for manual toggle
local Terminal = require("toggleterm.terminal").Terminal
local horizontal_term = Terminal:new({ direction = "horizontal", size = 15 })

-- Map <leader>t to toggle the horizontal terminal
vim.keymap.set("n", "<leader>t", function()
	horizontal_term:toggle()
	-- Ensure insert mode every toggle
end, { noremap = true, silent = true })

-- Map Esc in terminal to go back to normal mode
vim.api.nvim_set_keymap("t", "<Esc>", "<C-\\><C-n>", { noremap = true, silent = true })

-- Terminal split navigation shortcuts
vim.api.nvim_set_keymap("t", "<C-h>", "<C-\\><C-n><C-w>h", { noremap = true, silent = true })
vim.api.nvim_set_keymap("t", "<C-j>", "<C-\\><C-n><C-w>j", { noremap = true, silent = true })
vim.api.nvim_set_keymap("t", "<C-k>", "<C-\\><C-n><C-w>k", { noremap = true, silent = true })
vim.api.nvim_set_keymap("t", "<C-l>", "<C-\\><C-n><C-w>l", { noremap = true, silent = true })

-- mini [statusline and pairs setup]
require("mini.statusline").setup({})
require("mini.pairs").setup({})
require("mini.animate").setup({})
-- noice setup
require("noice").setup({
	cmdline = {
		enabled = true, -- enables the Noice cmdline UI
		view = "cmdline_popup", -- view for rendering the cmdline. Change to `cmdline` to get a classic cmdline at the bottom
		opts = {}, -- global options for the cmdline. See section on views
		---@type table<string, CmdlineFormat>
		format = {
			cmdline = { pattern = "^:", icon = "", lang = "vim" },
			search_down = { kind = "search", pattern = "^/", icon = " ", lang = "regex" },
			search_up = { kind = "search", pattern = "^%?", icon = " ", lang = "regex" },
			lua = { pattern = { "^:%s*lua%s+", "^:%s*lua%s*=%s*", "^:%s*=%s*" }, icon = "", lang = "lua" },
			help = { pattern = "^:%s*he?l?p?%s+", icon = "" },
			input = {}, -- Used by input()
		},
	},
	messages = {
		enabled = false,
	},
	popupmenu = {
		enabled = true,
	},
	signature = {
		enabled = true,
	},
	presets = {
		bottom_search = false, -- use a classic bottom cmdline for search
		command_palette = false, -- position the cmdline and popupmenu together
		long_message_to_split = false, -- long messages will be sent to a split
		inc_rename = false, -- enables an input dialog for inc-rename.nvim
		lsp_doc_border = true, -- add a border to hover docs and signature help
	},
})
-- blink.cmp setup
require("blink.cmp").setup({
	completion = {
		documentation = {
			auto_show = true,
		},
	},
	keymap = {
		["<S-Tab>"] = { "select_prev", "fallback_to_mappings" },
		["<Tab>"] = { "select_next", "fallback_to_mappings" },
		["<CR>"] = { "select_and_accept", "fallback" },
	},
	fuzzy = {
		implementation = "prefer_rust_with_warning",
	},
})

-- telescope setup
local telescope = require("telescope")
telescope.setup({
	defaults = {
		preview = { treesitter = false },
		color_devicons = true,
		sorting_strategy = "ascending",
		borderchars = {
			"─", -- top
			"│", -- right
			"─", -- bottom
			"│", -- left
			"┌", -- top-left
			"┐", -- top-right
			"┘", -- bottom-right
			"└", -- bottom-left
		},
		path_displays = { "smart" },
		layout_config = {
			height = 100,
			width = 400,
			prompt_position = "top",
			preview_cutoff = 40,
		},
	},
	refactor = {
		highligh_definitions = { enable = true },
		highligh_current_scope = { enable = false },
	},
})
telescope.load_extension("ui-select")
require("actions-preview").setup({
	backend = { "telescope" },
	extensions = { "env" },
	telescope = vim.tbl_extend("force", require("telescope.themes").get_dropdown(), {}),
})

local pickers = require("telescope.builtin")
vim.keymap.set("n", "<leader>sp", pickers.builtin, { desc = "[S]earch Builtin [P]ickers" })
vim.keymap.set("n", "<leader>b", pickers.buffers, { desc = "[S]earch [B]uffers" })
vim.keymap.set("n", "<leader>/", pickers.current_buffer_fuzzy_find, { desc = "[S]earch [W]ord" })
vim.keymap.set("n", "<leader>sf", pickers.find_files, { desc = "[S]earch [F]iles" })
vim.keymap.set("n", "<leader>sg", pickers.live_grep, { desc = "[S]earch by [G]rep" })
vim.keymap.set("n", "<leader>sr", pickers.resume, { desc = "[S]earch [R]esume" })
vim.keymap.set("n", "<leader>sh", pickers.help_tags, { desc = "[S]earch [H]elp" })
vim.keymap.set("n", "<leader>sm", pickers.man_pages, { desc = "[S]earch [M]anuals" })

-- which-key setup
require("which-key").setup({
	spec = {
		{ "<leader>s", group = "[S]earch", icon = { icon = "", color = "green" } },
	},
})

-- Oil: File Tree Buffer
require("oil").setup({
	float = {
		padding = 2,
		get_win_title = nil,
		preview_split = "right",
		override = function(conf)
			return conf
		end,
	},
	keymaps = {
		["<leader>e"] = "actions.close",
	},
})
vim.keymap.set("n", "<leader>e", "<CMD>Oil --float --preview<CR>", { desc = "File navigation" })
vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent dir" })

-- INFO: lsp server installation and configuration
local lsp_servers = {
	-- Lua
	lua_ls = {
		Lua = {
			workspace = {
				library = vim.api.nvim_get_runtime_file("lua", true),
			},
		},
	},

	-- C/C++
	clangd = {},

	-- Rust
	rust_analyzer = {
		["rust-analyzer"] = {
			checkOnSave = {
				command = "clippy",
			},
		},
	},
	codelldb = {},

	-- Python (basedpyright)
	basedpyright = {
		basedpyright = {
			typeCheckingMode = "off",
			logLevel = "error",
		},
	},

	-- JavaScript / TypeScript
	ts_ls = {},
	eslint = {},

	-- Web Dev
	html = {},
	cssls = {},
	tailwindcss = {},
	jsonls = {},
	yamlls = {},

	-- Misc Common
	bashls = {},
	dockerls = {},
	marksman = {},
}

-- Setup mason + lsp installer + tool-installer
require("mason").setup()
require("mason-lspconfig").setup()

-- Build an ensure_installed list containing formatters + LSP server names
local ensure = { "black", "prettier", "shfmt", "stylua" }
-- merge in lsp server names
for _, srv in ipairs(vim.tbl_keys(lsp_servers)) do
	table.insert(ensure, srv)
end

require("mason-tool-installer").setup({
	ensure_installed = ensure,
})

-- Configure each lsp server
-- Note: we call config exactly like your earlier loop but ensure settings shape is correct
for server, config in pairs(lsp_servers) do
	vim.lsp.config(server, {
		settings = config,

		on_attach = function(client, bufnr)
			-- go to definition
			vim.keymap.set("n", "gd", vim.lsp.buf.definition, {
				buffer = bufnr,
				desc = "vim.lsp.buf.definition()",
			})

			vim.keymap.set("n", "<leader>k", vim.lsp.buf.hover, {
				buffer = bufnr,
				desc = "Hover",
			})

			-- Format: prefer Conform, fallback to LSP if no conform formatter
			vim.keymap.set("n", "<leader>lf", function()
				require("conform").format({ async = true })
			end, { buffer = bufnr, desc = "Format buffer (Conform)" })

			if client.server_capabilities.documentHighlightProvider then
				local group = vim.api.nvim_create_augroup("LspReferenceHighlight_" .. bufnr, { clear = true })

				-- Highlight references when cursor moves (not in insert mode)
				vim.api.nvim_create_autocmd("CursorMoved", {
					group = group,
					buffer = bufnr,
					desc = "Highlight references under cursor",
					callback = function()
						if vim.fn.mode() ~= "i" then
							vim.lsp.buf.clear_references()
							vim.lsp.buf.document_highlight()
						end
					end,
				})

				-- Clear highlights in insert mode
				vim.api.nvim_create_autocmd("CursorMovedI", {
					group = group,
					buffer = bufnr,
					desc = "Clear references on insert movement",
					callback = function()
						vim.lsp.buf.clear_references()
					end,
				})
			end
			-------------------------------------------------------------------
		end,
	})
end
vim.api.nvim_set_hl(0, "LspReferenceText", { link = "Visual" })
vim.api.nvim_set_hl(0, "LspReferenceRead", { link = "Visual" })
vim.api.nvim_set_hl(0, "LspReferenceWrite", { link = "Visual" })
-- Conform.nvim setup (formatters + format-on-save)
require("conform").setup({
	-- try Conform formatters first; if none available, allow LSP fallback
	format_on_save = {
		timeout_ms = 2000,
		lsp_format = "fallback", -- try Conform, then LSP
	},

	-- mapping ft -> formatters
	formatters_by_ft = {
		python = { "black" },
		rust = { "rustfmt" },
		javascript = { "prettier" },
		typescript = { "prettier" },
		javascriptreact = { "prettier" },
		typescriptreact = { "prettier" },
		json = { "prettier" },
		yaml = { "prettier" },
		markdown = { "prettier" },
		html = { "prettier" },
		css = { "prettier" },
		scss = { "prettier" },
		sh = { "shfmt" },
		bash = { "shfmt" },
		lua = { "stylua" },
	},

	-- optional per-formatter options
	formatters = {
		black = {
			prepend_args = { "--fast" },
		},
		rustfmt = {
			-- rustfmt reads rustfmt.toml automatically; override args here if needed
		},
		prettier = {
			-- will use project settings (prettierrc) if present
		},
		shfmt = {
			args = { "-i", "2", "-ci" }, -- example: indent=2, continue indent
		},
		stylua = {
			-- use project settings if present, fallback options could be added
		},
	},
})
vim.keymap.set("n", "<leader>h", function()
	local enabled = vim.lsp.inlay_hint.is_enabled()
	vim.lsp.inlay_hint.enable(not enabled)
end, { desc = "Toggle Inlay Hints" })

-- uncomment to enable automatic plugin updates
-- vim.pack.update()
