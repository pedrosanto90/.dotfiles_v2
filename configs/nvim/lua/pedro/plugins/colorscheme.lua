return {
	{ "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
	{
		"folke/tokyonight.nvim",
		lazy = false,
		priority = 1000,
		opts = {
			style = "night",
			transparent = true,
			styles = {
				sidebars = "transparent",
				floats = "dark",
			},
			on_highlights = function(highlights, colors)
				highlights.NormalFloat = { bg = colors.bg_dark }
				highlights.FloatBorder = { bg = colors.bg_dark, fg = colors.blue }
			end,
		},
		config = function(_, opts)
			require("tokyonight").setup(opts)
			vim.cmd.colorscheme("tokyonight-night")
		end,
	},
}
