if vim.g.loaded_ltqf then
  return
end
vim.g.loaded_ltqf = true

local diag_ns = vim.api.nvim_create_namespace("languagetool_diag")

local function set_highlights()
  vim.api.nvim_set_hl(0, "LanguageToolGrammarError", { bg = "#440000" })
  vim.api.nvim_set_hl(0, "LanguageToolSpellingError", { bg = "#444400" })
end
set_highlights()

local augroup = vim.api.nvim_create_augroup("ltqf", { clear = true })
vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
  group = augroup,
  callback = set_highlights,
})

vim.diagnostic.config({
  underline = false,
  virtual_text = false,
  signs = false,
}, diag_ns)

vim.api.nvim_create_user_command("LanguageTool", function(opts)
  require("ltqf").dispatch(opts)
end, {
  nargs = 1,
  range = true,
  complete = function(arg_lead)
    local subcmds = { "check", "clear", "start", "stop", "error", "quickfix", "check-visual" }
    return vim.tbl_filter(function(s)
      return s:find(arg_lead, 1, true) == 1
    end, subcmds)
  end,
})

vim.keymap.set("n", "<Plug>(LTCheck)", function()
  require("ltqf").check(vim.api.nvim_get_current_buf())
end)
vim.keymap.set("n", "<Plug>(LTClear)", function()
  require("ltqf").clear()
end)
vim.keymap.set("n", "<Plug>(LTStartServer)", function()
  require("ltqf").start_server()
end)
vim.keymap.set("n", "<Plug>(LTStopServer)", function()
  require("ltqf").stop_server()
end)
vim.keymap.set("n", "<Plug>(LTErrorAtPoint)", function()
  require("ltqf").show_error_at_point()
end)
vim.keymap.set("n", "<Plug>(LTQuickfix)", function()
  require("ltqf").toggle_quickfix_mode()
end)
vim.keymap.set("v", "<Plug>(LTCheckVisual)", function()
  require("ltqf").check_visual()
end)

vim.api.nvim_create_autocmd("VimLeave", {
  pattern = "*",
  group = augroup,
  callback = function()
    require("ltqf").stop_server()
  end,
})
