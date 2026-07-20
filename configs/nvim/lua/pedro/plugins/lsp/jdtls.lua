return {
	"mfussenegger/nvim-jdtls",
	ft = "java",
	config = function()
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "java",
			callback = function()
				local jdtls = require("jdtls")
				local root_markers = { ".git", "mvnw", "gradlew", "pom.xml", "build.gradle" }
				local root_dir = require("jdtls.setup").find_root(root_markers)
				if not root_dir then
					return
				end

				local workspace_dir = vim.fn.stdpath("data")
					.. "/jdtls-workspace/"
					.. vim.fn.fnamemodify(root_dir, ":p:h:t")

				local config = {
					cmd = { "jdtls", "-data", workspace_dir },
					root_dir = root_dir,
					capabilities = require("blink.cmp").get_lsp_capabilities(),
				}

				jdtls.start_or_attach(config)
			end,
		})
	end,
}
