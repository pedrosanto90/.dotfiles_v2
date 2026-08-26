return {
	{ "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
	{
		"folke/tokyonight.nvim",
		lazy = false,
		priority = 1000,
		opts = {
			style = "night",
			light_style = "day",
			transparent = true,
			styles = {
				sidebars = "transparent",
				floats = "transparent",
			},
			on_colors = function(colors)
				if vim.o.background == "dark" then
					colors.bg = "NONE"
					colors.bg_dark = "NONE"
					colors.bg_float = "NONE"
					colors.bg_sidebar = "NONE"
					colors.bg_statusline = "NONE"
				end
			end,
		},
		config = function(_, opts)
			require("tokyonight").setup(opts)
		end,
	},
	{
		"rebelot/kanagawa.nvim",
		lazy = false,
		priority = 1000,
		opts = {
			transparent = true,
			background = {
				dark = "wave",
				light = "lotus",
			},
		},
		config = function(_, opts)
			require("kanagawa").setup(opts)
		end,
	},
	{
		"rose-pine/neovim",
		name = "rose-pine",
		lazy = false,
		priority = 1000,
		opts = { variant = "main", dark_variant = "main", disable_background = true },
		config = function(_, opts)
			require("rose-pine").setup(opts)
		end,
	},
	{
		"sainnhe/everforest",
		lazy = false,
		priority = 1000,
		init = function()
			vim.g.everforest_background = "hard"
			vim.g.everforest_transparent_background = 2
		end,
	},
	{
		"catppuccin/nvim",
		name = "catppuccin",
		lazy = false,
		priority = 1000,
		opts = { flavour = "mocha", transparent_background = true },
		config = function(_, opts)
			require("catppuccin").setup(opts)
		end,
	},
	{
		"EdenEast/nightfox.nvim",
		lazy = false,
		priority = 1000,
		opts = { options = { transparent = true } },
		config = function(_, opts)
			require("nightfox").setup(opts)
		end,
	},
}
