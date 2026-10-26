-- @keybind neovim|Remote SSH|Space R P|Browse remote projects
-- @keybind neovim|Remote SSH|Space R D|Disconnect remote project
-- @keybind neovim|Remote SSH|Space R F|Find remote project files
-- @keybind neovim|Remote SSH|Space R G|Search remote project contents
return {
	"nosduco/remote-sshfs.nvim",
	dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
	keys = {
		{
			"<leader>rp",
			function()
				require("pedro.utils.remote-picker").open()
			end,
			desc = "Browse remote projects",
		},
		{
			"<leader>rd",
			function()
				require("pedro.utils.remote-picker").disconnect()
			end,
			desc = "Disconnect remote project",
		},
		{
			"<leader>rf",
			function()
				require("pedro.utils.remote-picker").search(false)
			end,
			desc = "Find remote project files",
		},
		{
			"<leader>rg",
			function()
				require("pedro.utils.remote-picker").search(true)
			end,
			desc = "Search remote project contents",
		},
	},
	config = function()
		require("pedro.utils.remote-picker").setup()
		require("telescope").load_extension("remote-sshfs")
	end,
}
