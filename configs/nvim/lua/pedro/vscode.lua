local vscode = require("vscode")

vim.g.mapleader = " "
vim.opt.clipboard = "unnamedplus"
vim.opt.hlsearch = false

vim.keymap.set("x", "<", function()
	vscode.action("editor.action.outdentLines")
end, { desc = "Outdent while preserving the selection" })

vim.keymap.set("x", ">", function()
	vscode.action("editor.action.indentLines")
end, { desc = "Indent while preserving the selection" })

vim.keymap.set("x", "K", function()
	if vim.fn.mode() == "V" then
		vscode.action("editor.action.moveLinesUpAction")
		return "<Ignore>"
	end
	return "K"
end, { desc = "Move selected lines up", expr = true })

vim.keymap.set("x", "J", function()
	if vim.fn.mode() == "V" then
		vscode.action("editor.action.moveLinesDownAction")
		return "<Ignore>"
	end
	return "J"
end, { desc = "Move selected lines down", expr = true })

vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking text",
	callback = function()
		vim.hl.on_yank()
	end,
})
