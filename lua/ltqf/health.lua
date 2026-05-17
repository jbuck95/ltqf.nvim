local M = {}

function M.check()
	vim.health.start("ltqf.nvim")

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

	if vim.fn.filereadable(vim.fn.expand("~/LanguageTool-6.6/languagetool-server.jar")) == 1 then
		vim.health.ok("~/LanguageTool-6.6/languagetool-server.jar")
	else
		vim.health.error("LanguageTool server JAR not found at ~/LanguageTool-6.6/")
	end

	if vim.fn.filereadable(vim.fn.expand("~/Documents/ltqf/ignored.txt")) == 1 then
		vim.health.ok("~/Documents/ltqf/ignored.txt")
	else
		vim.health.ok("ignored.txt will be auto-created")
	end
end

return M
