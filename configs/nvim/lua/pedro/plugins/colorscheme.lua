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
					colors.bg = "#000000"
					colors.bg_dark = "#000000"
					colors.bg_float = "#000000"
					colors.bg_sidebar = "#000000"
					colors.bg_statusline = "#000000"
				end
			end,
			on_highlights = function(highlights, colors)
				highlights.NormalFloat = { bg = colors.bg }
				highlights.FloatBorder = { bg = colors.bg, fg = colors.blue }
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
			colors = {
				theme = {
					wave = {
						ui = {
							bg = "#000000",
							bg_dim = "#000000",
							bg_gutter = "#000000",
							bg_m3 = "#000000",
							bg_m2 = "#000000",
							bg_m1 = "#000000",
							bg_p1 = "#000000",
							bg_p2 = "#000000",
						},
					},
				},
			},
			overrides = function(colors)
				local theme = colors.theme
				return {
					NormalFloat = { bg = theme.ui.bg },
					FloatBorder = { bg = theme.ui.bg, fg = theme.ui.special },
				}
			end,
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
		opts = { variant = "main", dark_variant = "main" },
		config = function(_, opts)
			require("rose-pine").setup(opts)
		end,
	},
	{
		"sainnhe/everforest",
		lazy = false,
		priority = 1000,
	},
	{
		"catppuccin/nvim",
		name = "catppuccin",
		lazy = false,
		priority = 1000,
		opts = { flavour = "mocha" },
		config = function(_, opts)
			require("catppuccin").setup(opts)
		end,
	},
	{
		"EdenEast/nightfox.nvim",
		lazy = false,
		priority = 1000,
		opts = {},
		config = function(_, opts)
			require("nightfox").setup(opts)
		end,
	},
}
