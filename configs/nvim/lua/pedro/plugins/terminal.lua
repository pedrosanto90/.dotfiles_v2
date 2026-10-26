-- @keybind neovim|Terminal|Space T T|Toggle terminal in a bottom split
return {
	"akinsho/toggleterm.nvim",
	version = "*",
	opts = {
		open_mapping = "<leader>tt",
		direction = "horizontal",
		size = 12,
		insert_mappings = false,
	},
}
