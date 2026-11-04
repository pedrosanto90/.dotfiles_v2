return {
	"stevearc/oil.nvim",
	dependencies = {
		{ "nvim-mini/mini.icons", opts = {} },
	},
	lazy = false,

	-- Keymaps
	keys = {
		{
			"-",
			"<cmd>Oil --float<cr>",
			desc = "Open Oil",
		},
	},

	opts = {
		default_file_explorer = true,

		-- Informação apresentada
		columns = {
			"icon",
		},

		-- Comportamento
		delete_to_trash = true,
		skip_confirm_for_simple_edits = false,

		-- Ficheiros ocultos
		view_options = {
			show_hidden = true,
			natural_order = true,
		},

		-- Keymaps dentro do Oil
		keymaps = {
			["<CR>"] = "actions.select",
			["-"] = "actions.parent",
			["q"] = "actions.close",
			["<C-p>"] = "actions.preview",
			["<C-l>"] = "actions.refresh",
			["g."] = "actions.toggle_hidden",
			["g?"] = "actions.show_help",

			["<C-v>"] = {
				"actions.select",
				opts = { vertical = true },
				desc = "Open vertical split",
			},

			["<C-x>"] = {
				"actions.select",
				opts = { horizontal = true },
				desc = "Open horizontal split",
			},
		},

		use_default_keymaps = true,

		-- Janela flutuante
		float = {
			padding = 2,
			max_width = 100,
			max_height = 30,
			border = "rounded",
			win_options = {
				winblend = 0,
			},
		},
	},
}
