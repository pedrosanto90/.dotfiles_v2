-- Hightlight yanking
vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Highlight when yanking (copying) text",
    callback = function()
        vim.hl.on_yank()
    end,
})

-- when nvim is opened with a directory arg (e.g. `nvim .`), open Telescope find_files
vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		if vim.fn.argc() ~= 1 then
			return
		end
		local arg = vim.fn.argv(0)
		if vim.fn.isdirectory(arg) ~= 1 then
			return
		end
		vim.cmd.cd(arg)
		vim.cmd("bd!")
		vim.schedule(function()
			require("telescope.builtin").find_files()
		end)
	end,
})

-- restore cursor to file position in previous editing session
vim.api.nvim_create_autocmd("BufReadPost", {
	callback = function(args)
		local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
		local line_count = vim.api.nvim_buf_line_count(args.buf)
		if mark[1] > 0 and mark[1] <= line_count then
			vim.api.nvim_win_set_cursor(0, mark)
			-- defer centering slightly so it's applied after render
			vim.schedule(function()
				vim.cmd("normal! zz")
			end)
		end
	end,
})

-- compile java projects when saving
vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "*.java",
    callback = function()
      vim.fn.jobstart({"./mvnw", "compile", "-o", "-q"}, { detach = true })
    end,
  })
