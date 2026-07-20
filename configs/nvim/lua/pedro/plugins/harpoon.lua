-- List of favorite files/marks per project
-- Harpoon 2 configuration
-- @keybind neovim|Harpoon|Space H A|Add the current file
-- @keybind neovim|Harpoon|Space H F|Open the quick menu
-- @keybind neovim|Harpoon|Space H 1…9|Open marked file 1…9
return {
	-- https://github.com/ThePrimeagen/harpoon
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	event = "VeryLazy",
	dependencies = {
		-- https://github.com/nvim-lua/plenary.nvim
		"nvim-lua/plenary.nvim",
	},
	opts = {
		settings = {
			save_on_toggle = false, -- avoids an error with Neo-tree
			sync_on_ui_close = false,
		},
		menu = {
			width = 80, -- adjust as needed
			height = 35, -- adjust as needed
			borderchars = "rounded",
			preview = true, -- enables a preview of the selected file
		},
	},
	config = function(_, opts)
		local harpoon = require("harpoon")

		-- Initialize Harpoon with the configured options
		harpoon:setup(opts)

		-- Keybindings
		vim.keymap.set("n", "<leader>ha", function()
			harpoon:list():add()
		end, { desc = "Add file to Harpoon" })

		vim.keymap.set("n", "<leader>hf", function()
			harpoon.ui:toggle_quick_menu(harpoon:list())
		end, { desc = "Open harpoon window" })

		-- Quickly navigate between marked files
		for i = 1, 9 do
			vim.keymap.set("n", "<leader>h" .. i, function()
				harpoon:list():select(i)
			end, { desc = "Go to Harpoon file " .. i })
		end
	end,
}
