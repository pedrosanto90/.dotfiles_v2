-- @keybind neovim|Git|] C / [ C|Go to the next or previous hunk
-- @keybind neovim|Git|Space H S / Space H R|Stage or reset the current hunk
-- @keybind neovim|Git|Space H Shift+S / Space H Shift+R|Stage or reset the buffer
-- @keybind neovim|Git|Space H P|Preview the current hunk
-- @keybind neovim|Git|Space H B|Show blame for the current line
-- @keybind neovim|Git|Space H D|Diff the current file
-- @keybind neovim|Git|Space G D|Open the diff view
-- @keybind neovim|Git|Space G Shift+D|Open the staged diff view
-- @keybind neovim|Git|Space G H|Show the current file history
-- @keybind neovim|Git|Space G Shift+H|Show the repository history
-- @keybind neovim|Git|Space G Q|Close the diff view
-- @keybind neovim|Git|Space G G|Open Neogit status
return {
  {
    "lewis6991/gitsigns.nvim",
    event = "BufReadPre",
    opts = {
      current_line_blame = true,
      current_line_blame_opts = {
        delay = 300,
        virt_text_pos = "eol",
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns

        local map = function(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end

        map("n", "]c", gs.next_hunk, "Next git hunk")
        map("n", "[c", gs.prev_hunk, "Previous git hunk")
        map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
        map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
        map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")
        map("n", "<leader>hR", gs.reset_buffer, "Reset buffer")
        map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
        map("n", "<leader>hb", gs.blame_line, "Git blame line")
        map("n", "<leader>hd", gs.diffthis, "Diff this file")
      end,
    },
  },

  {
    "sindrets/diffview.nvim",
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewFileHistory",
    },
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Git diff view" },
      { "<leader>gD", "<cmd>DiffviewOpen --staged<cr>", desc = "Git staged diff" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Git file history" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Git repo history" },
      { "<leader>gq", "<cmd>DiffviewClose<cr>", desc = "Close diff view" },
    },
  },

  {
    "NeogitOrg/neogit",
    cmd = "Neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "nvim-telescope/telescope.nvim",
    },
    opts = {
      integrations = {
        diffview = true,
        telescope = true,
      },
    },
    keys = {
      { "<leader>gg", "<cmd>Neogit<cr>", desc = "Git status" },
    },
  },
}
