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
				colors.bg = "#000000"
				colors.bg_dark = "#000000"
				colors.bg_float = "#000000"
				colors.bg_sidebar = "#000000"
				colors.bg_statusline = "#000000"
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
					all = {
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
}
