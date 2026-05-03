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
vim.opt.wrap = false
vim.opt.autoread = true
vim.opt.fileformats = { "unix", "dos" }
vim.cmd([[autocmd FileType * set formatoptions-=ro]])

-- formatting style
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.textwidth = 80

vim.api.nvim_create_autocmd("FileType", {
	pattern = "python",
	callback = function()
		vim.opt_local.wrap = false
	end,
})

vim.diagnostic.config({
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = " ",
			[vim.diagnostic.severity.WARN] = " ",
			[vim.diagnostic.severity.INFO] = " ",
			[vim.diagnostic.severity.HINT] = " ",
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
vim.o.updatetime = 100

-- Auto-show diagnostics on hover
-- vim.api.nvim_create_autocmd("CursorHold", {
-- 	callback = function()
-- 		vim.diagnostic.open_float(nil, { focus = false })
-- 	end,
-- })

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
-- vim.keymap.set("n", "<leader>vs", ":vsplit<CR>", { desc = "Split vertically" })
-- vim.keymap.set("n", "<leader>vh", ":split<CR>", { desc = "Split horizontally" })
vim.keymap.set("n", "<M-k>", ":resize +8<CR>", { silent = true })
vim.keymap.set("n", "<M-j>", ":resize -8<CR>", { silent = true })
vim.keymap.set("n", "<M-h>", ":vertical resize -8<CR>", { silent = true })
vim.keymap.set("n", "<M-l>", ":vertical resize +8<CR>", { silent = true })

-- INFO: plugins (using vim.pack)
vim.pack.add({
	{ src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
	{ src = "https://github.com/saghen/blink.cmp", version = "v1" },
	{ src = "https://github.com/rktjmp/lush.nvim" },
	{ src = "https://github.com/ellisonleao/gruvbox.nvim" },
	{ src = "https://github.com/ribru17/bamboo.nvim" },
	{ src = "https://github.com/savq/melange-nvim" },
	{ src = "https://github.com/olimorris/onedarkpro.nvim" },
	{ src = "https://github.com/folke/tokyonight.nvim" },
	{ src = "https://github.com/scottmckendry/cyberdream.nvim" },
	{ src = "https://github.com/EdenEast/nightfox.nvim" },
	{ src = "https://github.com/tanvirtin/monokai.nvim" },
	{ src = "https://github.com/uloco/bluloco.nvim" },

	-- core LSP and mason toolkit
	"https://github.com/neovim/nvim-lspconfig",
	"https://github.com/mason-org/mason.nvim",
	"https://github.com/mason-org/mason-lspconfig.nvim",
	"https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim",

	-- formatting: conform.nvim
	"https://github.com/stevearc/conform.nvim",

	-- tmux splits
	"https://github.com/christoomey/vim-tmux-navigator",

	-- flash
	"https://github.com/folke/flash.nvim",

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

	-- git diff
	"https://github.com/sindrets/diffview.nvim",

	-- statusline
	"https://github.com/nvim-mini/mini.statusline",
	"https://github.com/nvim-mini/mini.pairs",
	"https://github.com/nvim-mini/mini.animate",
	"https://github.com/nvim-mini/mini.indentscope",

	-- indent blankline
	"https://github.com/lukas-reineke/indent-blankline.nvim",

	-- noice -- command line only
	"https://github.com/MunifTanjim/nui.nvim",
	"https://github.com/rcarriga/nvim-notify",
	"https://github.com/folke/noice.nvim",

	-- toggleterm
	"https://github.com/akinsho/toggleterm.nvim",

	-- CodeCompanion
	"https://github.com/olimorris/codecompanion.nvim",

	-- center buffer
	"https://github.com/folke/zen-mode.nvim",

	-- oil (file buffer browser)
	"https://github.com/stevearc/oil.nvim",
}, { confirm = false })

-- colorscheme
-- vim.cmd("colorscheme bamboo")
require("cyberdream").setup({ transparent = true })
vim.cmd("colorscheme cyberdream")
vim.api.nvim_create_autocmd("FileType", {
	callback = function()
		pcall(vim.treesitter.start)
	end,
})

--undo tree
vim.cmd("packadd nvim.undotree")
vim.keymap.set("n", "<leader>u", require("undotree").open)
-- set zenmode
vim.keymap.set(
	{ "n", "v" },
	"<LocalLeader>z",
	"<cmd>ZenMode<cr>",
	{ noremap = true, silent = true, desc = "[C]hat [T]oggle" }
)

-- CodeCompanion Setup
require("codecompanion").setup({
	display = {
		chat = {
			window = {
				layout = "vertical", -- Options: "vertical", "horizontal", "float", "buffer"
				position = "right", -- Can be "left" or "right"
				width = 10, -- Fixed width of 45 columns
			},
		},
	},
	dependencies = {
		{ "nvim-lua/plenary.nvim" },
		{
			"nvim-treesitter/nvim-treesitter",
			lazy = false,
			build = ":TSUpdate",
		},
		{
			"saghen/blink.cmp",
			lazy = false,
			version = "*",
			opts = {
				keymap = {
					preset = "enter",
					["<S-Tab>"] = { "select_prev", "fallback" },
					["<Tab>"] = { "select_next", "fallback" },
				},
				cmdline = { sources = { "cmdline" } },
				sources = {
					default = { "lsp", "path", "buffer", "codecompanion" },
				},
			},
		},
	},

	interactions = {
		chat = {
			adapter = {
				name = "gemini",
				model = "gemini-2.5-flash",
			},
			slash_commands = {
				["file"] = {
					-- Use Telescope as the provider for the /file command
					opts = {
						provider = "telescope", -- "default", "telescope", "fzf_lua", "mini_pick", or "snacks"
					},
				},
			},
		},

		inline = {
			adapter = {
				name = "gemini",
				model = "gemini-2.5-flash",
			},
			keymaps = {
				accept_change = {
					modes = { n = "ca" },
				},
				reject_change = {
					modes = { n = "cr" },
				},
				always_accept = {
					modes = { n = "cA" },
				},
			},
		},

		cmd = {
			adapter = {
				name = "gemini",
				model = "gemini-2.5-flash",
			},
		},

		background = {
			adapter = {
				name = "gemini",
				model = "gemini-2.5-flash",
			},
		},
	},
})

vim.keymap.set(
	{ "n", "v" },
	"<LocalLeader>ct",
	"<cmd>CodeCompanionChat Toggle<cr>",
	{ noremap = true, silent = true, desc = "[C]hat [T]oggle" }
)
vim.keymap.set(
	"v",
	"<LocalLeader>ca",
	"<cmd>CodeCompanionChat Add<cr>",
	{ noremap = true, silent = true, desc = "[C]hat [A]dd" }
)
vim.keymap.set(
	"v",
	"<LocalLeader>ci",
	"<cmd>CodeCompanion<cr>",
	{ noremap = true, silent = true, desc = "[C]hat [I]nline" }
)

-- bufferline setup
require("bufferline").setup({})

require("flash").setup({})

local flash = require("flash")

vim.keymap.set({ "n", "x", "o" }, "s", flash.jump, { desc = "Flash" })
vim.keymap.set({ "n", "x", "o" }, "S", flash.treesitter, { desc = "Flash Treesitter" })
vim.keymap.set({ "o", "x" }, "R", flash.treesitter_search, { desc = "Treesitter Search" })

-- ToggleTerm setup: horizontal terminal only
require("toggleterm").setup({
	size = function(term)
		if term.direction == "vertical" then
			return 60 -- height of horizontal terminal in lines
		end
	end,
	direction = "vertical", -- always horizontal
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
local vertical_term = Terminal:new({ direction = "vertical", size = 15 })

-- Map <leader>t to toggle the horizontal terminal
vim.keymap.set("n", "<leader>t", function()
	vertical_term:toggle()
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
require("mini.indentscope").setup({
	symbol = "›", -- character for the indent line
	options = {
		try_as_border = true, -- optional, makes active scope look nicer
	},
})

-- Set hot pink color for indent lines
vim.api.nvim_set_hl(0, "MiniIndentscopeSymbol", { fg = "#FF69B4" })

-- Optional: highlight the active scope with background
vim.api.nvim_set_hl(0, "MiniIndentscopeActive", { bg = "#2c313a" })

-- noice setup
require("noice").setup({
	lsp = {
		-- This is the specific fix for the "print()" wall of text
		signature = {
			enabled = true,
			auto_open = {
				enabled = false, -- !!! SET TO FALSE TO STOP THE AUTO POPUPS !!!
				trigger = true, -- Allows manual trigger via keymap or C-k
			},
		},
		hover = {
			enabled = true,
			silent = true, -- Stops noice from complaining if hover has no info
		},
	},
	cmdline = {
		enabled = true,
		view = "cmdline_popup",
		opts = {},
		format = {
			cmdline = { pattern = "^:", icon = "", lang = "vim" },
			search_down = { kind = "search", pattern = "^/", icon = " ", lang = "regex" },
			search_up = { kind = "search", pattern = "^%?", icon = " ", lang = "regex" },
			lua = { pattern = { "^:%s*lua%s+", "^:%s*lua%s*=%s*", "^:%s*=%s*" }, icon = "", lang = "lua" },
			help = { pattern = "^:%s*he?l?p?%s+", icon = "" },
			input = {},
		},
	},
	messages = {
		enabled = false,
	},
	popupmenu = {
		enabled = true,
	},
	presets = {
		bottom_search = false,
		command_palette = false,
		long_message_to_split = false,
		inc_rename = false,
		lsp_doc_border = true,
	},
	routes = {
		{
			filter = {
				any = {
					{ event = "msg_show", find = "Missing frontmatter, name or interaction" },
					{ event = "notify", find = "Missing frontmatter, name or interaction" },
				},
			},
			opts = { skip = true },
		},
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
		{ "<leader>s", group = "[S]earch", icon = { icon = "", color = "green" } },
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
		["v"] = {
			callback = function()
				require("oil").select({ vertical = true })
			end,
			desc = "Open the entry under cursor in a vertical split",
		},
	},
	open = {
		-- Always open files in vertical split by default
		vertical = true,
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

	-- Zig
	zls = {},

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
	ruff = {},
	ty = {},
	-- basedpyright = {
	-- 	basedpyright = {
	-- 		analysis = {
	-- 			pythonVersion = "3.14",
	-- 			autoSearchPaths = true,
	-- 			diagnosticMode = "openFilesOnly",
	-- 			autoImportCompletions = true,
	-- 			useLibraryCodeForTypes = true,
	-- 			typeCheckingMode = "basic",
	-- 			inlayHints = {
	-- 				variableTypes = true,
	-- 				functionReturnTypes = true,
	-- 				callArgumentNames = false,
	-- 				genericTypes = true,
	-- 			},
	-- 		},
	-- 	},
	-- },

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
local ensure = { "ruff", "prettier", "shfmt", "stylua" }
-- merge in lsp server names
for _, srv in ipairs(vim.tbl_keys(lsp_servers)) do
	table.insert(ensure, srv)
end

require("mason-tool-installer").setup({
	ensure_installed = ensure,
})

-- Configure each lsp server
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

				vim.api.nvim_create_autocmd("CursorMovedI", {
					group = group,
					buffer = bufnr,
					desc = "Clear references on insert movement",
					callback = function()
						vim.lsp.buf.clear_references()
					end,
				})
			end
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
		python = { "ruff" },
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
		rustfmt = {},
		prettier = {},
		shfmt = {
			args = { "-i", "2", "-ci" },
		},
		stylua = {},
	},
})

-- check which python we are using
vim.keymap.set("n", "<leader>py", "<cmd>!which python<CR>", { desc = "Check Python Path" })

vim.keymap.set("n", "<leader>h", function()
	local enabled = vim.lsp.inlay_hint.is_enabled()
	vim.lsp.inlay_hint.enable(not enabled)
end, { desc = "Toggle Inlay Hints" })

-- diffview config
local is_git_ignored = function(filepath)
	vim.fn.system("git check-ignore -q " .. vim.fn.shellescape(filepath))
	return vim.v.shell_error == 0
end

local update_left_pane = function()
	pcall(function()
		local lib = require("diffview.lib")
		local view = lib.get_current_view()
		if view then
			view:update_files()
		end
	end)
end

vim.notify("[diffview] init")

require("custom.directory-watcher").registerOnChangeHandler("diffview", function(filepath, events)
	local is_in_dot_git_dir = filepath:match("/%.git/") or filepath:match("^%.git/")

	if is_in_dot_git_dir or not is_git_ignored(filepath) then
		vim.notify("[diffview] File changed: " .. vim.fn.fnamemodify(filepath, ":t"), vim.log.levels.INFO)
		update_left_pane()
	end
end)

vim.api.nvim_create_autocmd("FocusGained", {
	callback = update_left_pane,
})

vim.api.nvim_create_autocmd("User", {
	pattern = "DiffviewViewLeave",
	callback = function()
		vim.cmd("DiffviewClose")
	end,
})

require("diffview").setup({
	default_args = {
		DiffviewOpen = { "--imply-local" },
	},
	keymaps = {
		view = {
			{ "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
		},
		file_panel = {
			{ "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
		},
		file_history_panel = {
			{ "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
		},
	},
})

vim.keymap.set("n", "<leader>gd", "<cmd>DiffviewOpen<CR>", { silent = true })

-- custom dir watchers and yankers for claude code
require("custom.hotreload").setup()
require("custom.yank")
