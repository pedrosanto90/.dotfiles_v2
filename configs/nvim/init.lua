if vim.g.vscode then
	require("pedro.vscode")
	return
end

require("vim._core.ui2").enable({})
require("pedro.core")
require("pedro.lazy")
pcall(require, "current-theme")
require("pedro.core.desktop-theme").setup()
