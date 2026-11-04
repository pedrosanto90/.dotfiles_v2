return {
	"stevearc/conform.nvim",
	opts = {
		formatters_by_ft = {
			lua = { "stylua" },
			-- Conform will run multiple formatters sequentially
			-- python = { "isort", "black", "autoflake" },
			-- You can customize some of the format options for the filetype (:help conform.format)
			-- rust = { "rustfmt" },
			-- Conform will run the first available formatter
			javascript = { "biome-check" },
			javascriptreact = { "biome-check" },
			typescript = { "biome-check" },
			typescriptreact = { "biome-check" },
			-- HTML/Angular/Astro use the language server fallback below.
			css = { "biome-check" },
			graphql = { "biome-check" },
			htmldjango = { "djlint" },
			go = { "gofmt" },
			php = { "duster" },
			json = { "biome-check" },
			jsonc = { "biome-check" },
			python = { "black" },
		},
		format_on_save = {
			-- These options will be passed to conform.format()
			timeout_ms = 500,
			lsp_format = "fallback",
		},
	},
}
