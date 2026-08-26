local M = {}

local state_home = vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")
local runtime_dir = vim.env.XDG_RUNTIME_DIR or ("/run/user/" .. vim.fn.getuid())
local state_file = state_home .. "/debian-sway-dev/theme"
local socket_dir = runtime_dir .. "/debian-sway-dev-nvim"

local themes = {
	["tokyonight-dark"] = { background = "dark", colorscheme = "tokyonight-night" },
	["tokyonight-light"] = { background = "light", colorscheme = "tokyonight-day" },
	["kanagawa-dark"] = { background = "dark", colorscheme = "kanagawa-wave" },
	["kanagawa-light"] = { background = "light", colorscheme = "kanagawa-lotus" },
	["rose-pine-dark"] = { background = "dark", colorscheme = "rose-pine" },
	["everforest-dark"] = { background = "dark", colorscheme = "everforest" },
	["everforest-light"] = { background = "light", colorscheme = "everforest" },
	["catppuccin-dark"] = { background = "dark", colorscheme = "catppuccin-mocha" },
	["nightfox-dark"] = { background = "dark", colorscheme = "nightfox" },
}

local function read_theme()
	local file = io.open(state_file, "r")
	if not file then
		return "tokyonight-dark"
	end
	local selected = vim.trim(file:read("*l") or "")
	file:close()
	if selected == "light" or selected == "dark" then
		return "tokyonight-" .. selected
	end
	return themes[selected] and selected or "tokyonight-dark"
end

function M.apply()
	local selected = read_theme()
	local theme = themes[selected]
	vim.o.background = theme.background
	if selected == "everforest-dark" or selected == "everforest-light" then
		vim.g.everforest_background = "hard"
	end
	if vim.g.colors_name ~= theme.colorscheme then
		vim.cmd.colorscheme(theme.colorscheme)
	end
	for _, group in ipairs({ "Normal", "NormalNC", "NormalFloat", "FloatBorder", "SignColumn", "FoldColumn", "EndOfBuffer", "MsgArea" }) do
		local highlights = vim.api.nvim_get_hl(0, { name = group, link = false })
		highlights.bg = nil
		highlights.ctermbg = nil
		vim.api.nvim_set_hl(0, group, highlights)
	end
	return selected
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
