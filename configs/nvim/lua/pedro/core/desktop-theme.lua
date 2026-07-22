local M = {}

local state_home = vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")
local runtime_dir = vim.env.XDG_RUNTIME_DIR or ("/run/user/" .. vim.fn.getuid())
local state_file = state_home .. "/debian-sway-dev/theme"
local socket_dir = runtime_dir .. "/debian-sway-dev-nvim"

local function read_mode()
	local file = io.open(state_file, "r")
	if not file then
		return "dark"
	end
	local mode = vim.trim(file:read("*l") or "")
	file:close()
	return mode == "light" and "light" or "dark"
end

function M.apply()
	local mode = read_mode()
	local colorscheme = mode == "light" and "tokyonight-day" or "tokyonight-night"
	vim.o.background = mode
	if vim.g.colors_name ~= colorscheme then
		vim.cmd.colorscheme(colorscheme)
	end
	return mode
end

local function start_theme_server()
	vim.fn.mkdir(socket_dir, "p")
	local address = string.format("%s/%d.sock", socket_dir, vim.fn.getpid())
	if vim.uv.fs_stat(address) then
		vim.fn.delete(address)
	end

	local ok = pcall(vim.fn.serverstart, address)
	if not ok then
		return
	end

	vim.api.nvim_create_autocmd("VimLeavePre", {
		once = true,
		callback = function()
			pcall(vim.fn.serverstop, address)
			vim.fn.delete(address)
		end,
	})
end

function M.setup()
	M.apply()
	start_theme_server()
end

return M
