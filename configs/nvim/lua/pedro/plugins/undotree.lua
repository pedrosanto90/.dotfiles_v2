-- @keybind neovim|History|Space U|Toggle the undo tree
return {
	"mbbill/undotree",
	config = function()
		vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle)
	end,
}
