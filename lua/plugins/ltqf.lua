-- Example lazy.nvim spec for ltqf.nvim
-- Copy this to your own lua/plugins/ltqf.lua and adjust as needed.
return {
  "jbuck95/ltqf.nvim",
  ft = { "markdown", "text" },
  cmd = "LanguageTool",
  keys = {
    { "<Plug>(LTCheck)" },
    { "<Plug>(LTClear)" },
    { "<Plug>(LTStartServer)" },
    { "<Plug>(LTStopServer)" },
    { "<Plug>(LTErrorAtPoint)" },
    { "<Plug>(LTQuickfix)" },
    { "<Plug>(LTCheckVisual)", mode = "v" },
  },

  ---@type ltqf.Config
  opts = {
    language = "de-DE",
    languagetool_server_jar = vim.fn.expand("~/LanguageTool-6.6/languagetool-server.jar"),
    languagetool_server_command = "java --enable-native-access=ALL-UNNAMED -cp '"
      .. vim.fn.expand("~/LanguageTool-6.6/*")
      .. "' org.languagetool.server.HTTPServer &> /dev/null",
    ignored_words_path = vim.fn.stdpath("data") .. "/ltqf_ignored.txt",
    inline_exclude_patterns = {
      "%[%^%d+%]",
      "\\newpage",
      "\\pagebreak",
      "\\medskip",
    },
    exclude_patterns = {
      "^>",
      "^%s*>",
    },
    -- check_start_token = "^# Introduction",
    -- check_end_token = "^# Literature",
  },

  config = function(_, opts)
    require("ltqf").setup(opts)
  end,

  -- Optional: define your own keymaps
  -- init = function()
  --   local map = vim.keymap.set
  --   map("n", "<leader>ls", "<Plug>(LTStartServer)",  { desc = "LT: Start server" })
  --   map("n", "<leader>lc", "<Plug>(LTCheck)",        { desc = "LT: Check buffer" })
  --   map("n", "<leader>lq", "<Plug>(LTQuickfix)",     { desc = "LT: Quickfix mode" })
  --   map("n", "<leader>le", "<Plug>(LTErrorAtPoint)", { desc = "LT: Error at point" })
  --   map("n", "<leader>lx", "<Plug>(LTClear)",        { desc = "LT: Clear" })
  --   map("v", "<leader>lv", "<Plug>(LTCheckVisual)",  { desc = "LT: Check visual" })
  -- end,
}
