vim.opt.termguicolors = true

vim.opt.nu = true
vim.opt.relativenumber = true

-- indentation
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true

vim.opt.wrap = false

-- backup and undo
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = vim.fn.stdpath("data") .. "/undodir"
vim.opt.undofile = true

-- search
vim.opt.inccommand = "split"
vim.opt.hlsearch = false
vim.opt.incsearch = true

-- UI
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"

-- folding (for nvim-ufo)
vim.o.foldenable = true
vim.o.foldmethod = "manual"
vim.o.foldlevel = 99
vim.o.foldcolumn = "0"

-- window splits
vim.opt.splitright = true
vim.opt.splitbelow = true

-- misc
vim.opt.guicursor = ""
vim.opt.isfname:append("@-@")
vim.opt.updatetime = 50
vim.opt.colorcolumn = "100"
vim.opt.mouse = 'a'
vim.opt.encoding = "UTF-8"
vim.opt.keywordprg = ":help"

-- Sync clipboard between OS and Neovim.
vim.opt.clipboard = "unnamedplus"

-- Reload files changed outside neovim
vim.opt.autoread = true
vim.opt.updatetime = 300
-- " When a file is changed outside of Neovim and it is the current buffer, automatically reload it.
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  pattern = "*",
  command = "silent! checktime",
})
