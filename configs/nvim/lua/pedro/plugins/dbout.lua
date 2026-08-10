-- @keybind neovim|Database|Space D B|Open the database connection picker (Telescope dbout)
return {
	"zongben/dbout.nvim",
	build = "npm install",
	cmd = { "Dbout" },
	config = function()
		require("dbout").setup({})
	end,
}