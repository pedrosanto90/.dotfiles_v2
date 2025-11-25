return {
	"catppuccin/nvim",
	name = "catppuccin",
	priority = 1000,
	config = function()
		require("catppuccin").setup({
			flavour = "macchiato", -- latte, frappe, macchiato, mocha
			background = { -- :h background
				light = "latte",
				dark = "mocha",
			},
			transparent_background = true, -- disables setting the background color.
			show_end_of_buffer = false, -- shows the '~' characters after the end of buffers
			term_colors = false, -- sets terminal colors (e.g. `g:terminal_color_0`)
			dim_inactive = {
				enabled = false, -- dims the background color of inactive window
				shade = "dark",
				percentage = 0.15, -- percentage of the shade to apply to the inactive window
			},
			no_italic = false, -- Force no italic
			no_bold = false, -- Force no bold
			no_underline = false, -- Force no underline
			styles = { -- Handles the styles of general hi groups (see `:h highlight-args`):
				comments = { "italic" }, -- Change the style of comments
				conditionals = { "italic" },
				loops = {},
				functions = {},
				keywords = {},
				strings = {},
				variables = {},
				numbers = {},
				booleans = {},
				properties = {},
				types = {},
				operators = {},
				-- miscs = {}, -- Uncomment to turn off hard-coded styles
			},
			color_overrides = {},
			custom_highlights = {},
			default_integrations = true,
			integrations = {
				cmp = true,
				gitsigns = true,
				neotree = true,
				treesitter = true,
				notify = false,
				mini = {
					enabled = true,
					indentscope_color = "",
				},
				-- For more plugins integrations please scroll down (https://github.com/catppuccin/nvim#integrations)
			},
		})

		-- setup must be called before loading
		vim.cmd.colorscheme("catppuccin")
	end,
}
--
-- night-fox (duskfox)
-- return {
-- 	"EdenEast/nightfox.nvim",
-- 	config = function()
-- 		require("nightfox").setup({
-- 			options = {
-- 				transparent = true,
-- 			},
-- 		})
-- 		vim.cmd("colorscheme duskfox")
-- 	end,
-- }
-- tokyonight
-- return {
-- 	"folke/tokyonight.nvim",
-- 	priority = 1000, -- make sure to load this before all the other start plugins
-- 	config = function()
-- 		require("tokyonight").setup({
-- 			style = "storm",
-- 			transparent = true,
-- 		})
-- 		-- load the colorscheme here
-- 		vim.cmd([[colorscheme tokyonight]])
-- 	end,
-- }
--
-- Vague
-- return {
-- 	"vague2k/vague.nvim",
-- 	lazy = false, -- make sure we load this during startup if it is your main colorscheme
-- 	priority = 1000, -- make sure to load this before all the other plugins
-- 	config = function()
-- 		-- NOTE: you do not need to call setup if you don't want to.
-- 		require("vague").setup({
-- 			-- optional configuration here
-- 			transparent = true,
-- 		})
-- 		vim.cmd("colorscheme vague")
-- 	end,
-- }
--
-- rose-pine
-- return {
-- 	"rose-pine/neovim",
-- 	name = "rose-pine",
-- 	config = function()
-- 		require("rose-pine").setup({
-- 			styles = {
-- 				transparency = true,
-- 			},
-- 		})
-- 		vim.cmd("colorscheme rose-pine")
-- 	end,
-- }
