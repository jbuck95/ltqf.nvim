-- /home/jan/.config/nvim/lua/dev/ltqf.nvim/lua/ltqf.nvim/config.lua
local M = {}

M.default_config = {
  languagetool_server_jar = vim.fn.expand("$HOME") .. "/LanguageTool-6.6/languagetool-server.jar",
  languagetool_server_command = "java --enable-native-access=ALL-UNNAMED -cp '" .. vim.fn.expand("$HOME") .. "/LanguageTool-6.6/*' org.languagetool.server.HTTPServer &> /dev/null",
  summary_pp_flags = "",
  preview_pp_flags = "",
  disabledRules = "WHITESPACE_RULE,EN_QUOTES",
  enabledRules = "",
  disabledCategories = "",
  enabledCategories = "",
  language = "de-DE",
  exclude_patterns = {
    "^>",
  },
  inline_exclude_patterns = {
    "%[%^%d+%]",  -- obsidian/md footnotes like [^67]
    "\\newpage",
  },
  check_start_token = "",
  check_end_token = "",
}

function M.get(user_opts)
  local conf = vim.tbl_extend("force", M.default_config, user_opts or {})
  
  if vim.g.languagetool then
    conf = vim.tbl_extend("force", conf, vim.g.languagetool)
  end

  if conf.language == "auto" then
    local lang = vim.o.spelllang
    if lang == "" then
      -- Fehlerbehebung: vim.v.lang als Variable auslesen
      lang = vim.v.lang
    end
    if lang == "" then
      vim.notify("LanguageTool: Failed to guess language from spelllang or v:lang. Defaulting to en-US.", vim.log.levels.WARN)
      lang = "en-US"
    end
    conf.language = lang
  end

  return conf
end

return M
