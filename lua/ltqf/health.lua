local M = {}

function M.check()
  vim.health.start("ltqf")

  -- External dependencies
  if vim.fn.executable("java") == 1 then
    local version = vim.fn.system("java -version 2>&1 | head -1")
    vim.health.ok("java: " .. vim.trim(version))
  else
    vim.health.error("java not found (required for LanguageTool server)")
  end

  if vim.fn.executable("curl") == 1 then
    vim.health.ok("curl")
  else
    vim.health.error("curl not found (required for LanguageTool API calls)")
  end

  -- Config validation
  local ok, config = pcall(require, "ltqf.config")
  if not ok then
    vim.health.error("Failed to load ltqf config: " .. tostring(config))
    return
  end

  local conf = config.get()
  local jar_path = vim.fn.expand(conf.languagetool_server_jar)
  if vim.fn.filereadable(jar_path) == 1 then
    vim.health.ok("LanguageTool JAR: " .. jar_path)
  else
    vim.health.error("LanguageTool server JAR not found: " .. jar_path)
  end

  if conf.language and conf.language ~= "" then
    vim.health.ok("language: " .. conf.language)
  else
    vim.health.error("language not set in config")
  end

  -- Check if server is running (via curl to localhost)
  local ret = vim.fn.system("curl -s -o /dev/null -w '%{http_code}' http://localhost:8081/v2/languages 2>/dev/null")
  if vim.trim(ret) == "200" then
    vim.health.ok("LanguageTool server responding at localhost:8081")
  else
    vim.health.info("LanguageTool server not running (use :LanguageTool start)")
  end

  -- Plugin initialization
  if vim.g.loaded_ltqf then
    vim.health.ok("Plugin initialized (vim.g.loaded_ltqf set)")
  else
    vim.health.warn("Plugin not initialized — has plugin/ltqf.lua been loaded?")
  end

  -- Ignored words file
  local ignored_path = vim.fn.stdpath("data") .. "/languagetool_ignored.txt"
  if vim.fn.filereadable(ignored_path) == 1 then
    vim.health.ok("Ignored words file: " .. ignored_path)
  else
    vim.health.info("Ignored words file will be auto-created at " .. ignored_path)
  end
end

return M
