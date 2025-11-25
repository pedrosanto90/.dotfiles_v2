return {
	"zbirenbaum/copilot.lua",
	cmd = "Copilot",
	event = "InsertEnter",
	config = function()
		require("copilot").setup({
			suggestion = {
				enabled = true,
				auto_trigger = true,
				keymap = {
					accept = "<C-a>", -- aceita sugestão inteira
					accept_word = "<C-w>", -- aceita palavra
					accept_line = "<C-l>", -- aceita linha
					next = "<M-]>", -- próxima sugestão
					prev = "<M-[>", -- sugestão anterior
					dismiss = "<C-]>",
				},
			},
			panel = {
				enabled = true,
				keymap = {
					jump_prev = "[[",
					jump_next = "]]",
					accept = "<CR>",
					refresh = "gr",
					open = "<M-CR>",
				},
			},
		})
	end,
}
