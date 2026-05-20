---@class ltqf.Config
---@field language? string
---@field languagetool_server_jar? string
---@field languagetool_server_command? string
---@field ignored_words_path? string
---@field summary_pp_flags? string
---@field preview_pp_flags? string
---@field disabledRules? string
---@field enabledRules? string
---@field disabledCategories? string
---@field enabledCategories? string
---@field exclude_patterns? string[]
---@field inline_exclude_patterns? string[]
---@field check_start_token? string
---@field check_end_token? string

local M = {}

---@type ltqf.Config
M.default_config = {
  languagetool_server_jar = vim.fn.expand("$HOME") .. "/LanguageTool-6.6/languagetool-server.jar",
  languagetool_server_command = "java --enable-native-access=ALL-UNNAMED -cp '"
    .. vim.fn.expand("$HOME")
    .. "/LanguageTool-6.6/*' org.languagetool.server.HTTPServer &> /dev/null",
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
    "%[%^%d+%]",
    "\\newpage",
  },
  check_start_token = "",
  check_end_token = "",
}

---@param user_opts? ltqf.Config
---@return ltqf.Config
function M.get(user_opts)
  local conf = vim.tbl_deep_extend("force", M.default_config, user_opts or {})

  if vim.g.languagetool then
    conf = vim.tbl_deep_extend("force", conf, vim.g.languagetool)
  end

  local ok, err = pcall(vim.validate, {
    languagetool_server_jar = { conf.languagetool_server_jar, "string" },
    languagetool_server_command = { conf.languagetool_server_command, "string" },
    language = { conf.language, "string" },
    exclude_patterns = { conf.exclude_patterns, "table" },
    inline_exclude_patterns = { conf.inline_exclude_patterns, "table" },
    check_start_token = { conf.check_start_token, "string" },
    check_end_token = { conf.check_end_token, "string" },
  })
  if not ok then
    vim.notify("ltqf: Invalid config: " .. tostring(err), vim.log.levels.ERROR)
  end

  if conf.language == "auto" then
    local lang = vim.o.spelllang
    if lang == "" then
      lang = vim.v.lang
    end
    if lang == "" then
      vim.notify("ltqf: Failed to guess language from spelllang or v:lang. Defaulting to en-US.", vim.log.levels.WARN)
      lang = "en-US"
    end
    conf.language = lang
  end

  return conf
end

return M
