local M = {}

local function should_check()
	local mode = vim.api.nvim_get_mode().mode
	return not (
		mode:match("[cR!s]") -- Skip: command-line, replace, ex, select modes
		or vim.fn.getcmdwintype() ~= "" -- Skip: command-line window is open
	)
end

-- Autocmds that trigger checktime when neovim regains focus or cursor moves
M.setup = function()
	vim.api.nvim_create_autocmd({ "FocusGained", "TermLeave", "BufEnter", "WinEnter", "CursorHold", "CursorHoldI" }, {
		group = vim.api.nvim_create_augroup("hotreload", { clear = true }),
		callback = function()
			if should_check() then
				vim.cmd("checktime")
			end
		end,
	})

	-- Poll for changes every 1 second even without user interaction.
	-- This catches external edits (e.g. from Claude Code) when neovim
	-- is visible but unfocused in a split terminal.
	local timer = vim.uv.new_timer()
	if timer then
		timer:start(
			1000,
			1000,
			vim.schedule_wrap(function()
				if should_check() then
					pcall(vim.cmd, "checktime")
				end
			end)
		)
	end
end

return M
