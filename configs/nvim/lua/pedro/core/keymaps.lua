local opts = { noremap = true, silent = true }

vim.g.mapleader = " "

-- @keybind neovim|Editing (visual)|J / K|Move the selection down or up
-- @keybind neovim|Navigation|Ctrl+D / Ctrl+U|Scroll half a page and center the cursor
-- @keybind neovim|Search|n / N|Jump to a match and center the cursor
-- @keybind neovim|Editing (visual)|< / >|Indent while preserving the selection
-- @keybind neovim|Files|Space E|Toggle Neo-tree
-- @keybind neovim|Files|Space F P|Copy the current file path
-- @keybind neovim|Windows|Ctrl+H/J/K/L|Move focus between windows

-- global keymaps
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "moves lines down in visual selection" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "moves lines up in visual selection" })

-- vim.keymap.set("n", "J", "mzJ`z")
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "move down in buffer with cursor centered" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "move up in buffer with cursor centered" })
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

vim.keymap.set("v", "<", "<gv", opts)
vim.keymap.set("v", ">", ">gv", opts)

-- neo tree
vim.keymap.set("n", "<leader>e", ":Neotree toggle<CR>", { desc = "Toggle Neo-tree" })

-- Copy filepath to the clipboard
vim.keymap.set("n", "<leader>fp", function()
    local filePath = vim.fn.expand("%:~")
    vim.fn.setreg("+", filePath)
    print("File path copied to clipboard: " .. filePath)
end, { desc = "Copy file path to clipboard" })

-- Navigate between panes
vim.keymap.set("n", "<C-h>", "<C-w>h", { noremap = true, silent = true })
vim.keymap.set("n", "<C-j>", "<C-w>j", { noremap = true, silent = true })
vim.keymap.set("n", "<C-k>", "<C-w>k", { noremap = true, silent = true })
vim.keymap.set("n", "<C-l>", "<C-w>l", { noremap = true, silent = true })
