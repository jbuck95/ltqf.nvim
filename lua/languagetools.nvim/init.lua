-- /home/jan/.config/nvim/lua/languagetools/init.lua
local M = {}

local config = require("languagetools.config")
local ui = require("languagetools.ui")
local filter = require("languagetools.filter")

M.filter = filter

local function url_encode(str)
	str = string.gsub(str, "([^%w%._~-])", function(c) return string.format("%%%02X", string.byte(c)) end)
	return str
end

local job_id
local matches = {}
local server_is_running = false
local _current_opts = {}

local ignored_words_path

local function load_ignored_words()
	local f = io.open(ignored_words_path, "r")
	if not f then return {} end
	local words = {}
	for line in f:lines() do
		if line and line ~= "" then
			words[line] = true
		end
	end
	f:close()
	return words
end

local function save_ignored_word(word)
	local words = load_ignored_words()
	if words[word] then return end
	
	local f = io.open(ignored_words_path, "a")
	if f then
		f:write(word .. "\n")
		f:close()
	end
end

local function get_pos_from_offset(bufnr, char_offset_global)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local current_global_char_count = 0
	for i, line in ipairs(lines) do
		local line_char_count = vim.fn.strchars(line)
		local line_with_newline_char_count = line_char_count + 1
		if current_global_char_count + line_with_newline_char_count > char_offset_global then
			return i - 1, char_offset_global - current_global_char_count
		end
		current_global_char_count = current_global_char_count + line_with_newline_char_count
	end
	return #lines - 1, vim.fn.strchars(lines[#lines])
end

local function get_pos_from_offset_on_lines(lines, offset)
	local total_chars = 0
	for i, line in ipairs(lines) do
		local line_length = vim.fn.strchars(line) + 1
		if total_chars + line_length > offset then
			return i - 1, offset - total_chars
		end
		total_chars = total_chars + line_length
	end
	local last_line = #lines
	return last_line - 1, #lines[last_line] or 0
end

local function get_word_from_match(match)
	local ctx = match.context
	if not ctx or not ctx.text then return nil end
	local start_byte = vim.fn.byteidx(ctx.text, ctx.offset)
	local end_byte = vim.fn.byteidx(ctx.text, ctx.offset + ctx.length)
	if start_byte ~= -1 and end_byte ~= -1 then
		return ctx.text:sub(start_byte + 1, end_byte)
	end
	return nil
end

local quickfix_mode_state = {
	is_active = false,
	current_index = 0,
	matches = {},
	undo_stack = {},
}

function M.undo_last_fix()
	if not quickfix_mode_state.is_active or #quickfix_mode_state.undo_stack == 0 then
		vim.notify("LanguageTool: Nichts zum Rückgängigmachen.", vim.log.levels.WARN)
		vim.defer_fn(M.quickfix_next_error, 50)
		return
	end

	local last_state = table.remove(quickfix_mode_state.undo_stack)

	if last_state.type == "fix" then
		vim.api.nvim_buf_call(last_state.bufnr, function()
			vim.cmd("undo")
		end)
	end

	matches = last_state.matches
	quickfix_mode_state.matches = last_state.qf_matches
	quickfix_mode_state.current_index = last_state.index

	M.highlight_errors(last_state.bufnr)
	vim.defer_fn(M.quickfix_next_error, 50)
end

function M.go_back_without_undo()
	if not quickfix_mode_state.is_active or quickfix_mode_state.current_index <= 1 then
		vim.notify("LanguageTool: Bereits beim ersten Fehler.", vim.log.levels.WARN)
		vim.defer_fn(M.quickfix_next_error, 50)
		return
	end
	
	quickfix_mode_state.current_index = quickfix_mode_state.current_index - 1
	vim.defer_fn(M.quickfix_next_error, 50)
end

function M.check_visual()
	local conf = config.get(_current_opts)
	local bufnr = vim.api.nvim_get_current_buf()
	local start_line, end_line = vim.fn.line("'<"), vim.fn.line("'>")
	local lines_to_check = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

	local text = url_encode(table.concat(lines_to_check, "\n"))
	local payload = "language=" .. conf.language .. "&text=" .. text

	local command = { "curl", "-s", "-X", "POST", "--data-binary", "@-", "http://localhost:8081/v2/check" }

	vim.notify("LanguageTool: Checking selection...", vim.log.levels.INFO, { title = "LanguageTool" })
	local stdout_chunks = {}

	local job = vim.fn.jobstart(command, {
		on_stdout = function(_, data) if data then table.insert(stdout_chunks, data) end end,
		on_stderr = function(_, data)
			if data and data[1] then vim.notify("LT Error: " .. table.concat(data, "\n"), vim.log.levels.ERROR) end
		end,
		on_exit = function()
			local raw_response = table.concat(vim.tbl_flatten(stdout_chunks) or {})
			if raw_response == "" then return end
			local ok, response = pcall(vim.fn.json_decode, raw_response)
			if not ok or not response or not response.matches then return end
			local qflist = {}
			for _, match in ipairs(response.matches) do
				local lnum_relative, col = get_pos_from_offset_on_lines(lines_to_check, match.offset)
				table.insert(qflist, { bufnr = bufnr, lnum = lnum_relative + start_line, col = col + 1, text = match.message })
			end
			if #qflist > 0 then
				vim.fn.setqflist(qflist)
				vim.cmd("copen")
				vim.notify("LanguageTool: Found " .. #qflist .. " issues in selection.", vim.log.levels.INFO)
			else
				vim.notify("LanguageTool: No issues found in selection.", vim.log.levels.INFO)
			end
		end,
	})

	if job > 0 then
		vim.api.nvim_chan_send(job, payload)
		vim.fn.chanclose(job, "stdin")
	end
end

function M.check(bufnr, on_complete_callback)
	local conf = config.get(_current_opts)
	local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local content_start_line_idx, frontmatter_char_offset = 0, 0
	if #all_lines > 1 and all_lines[1] == "---" then
		for i = 2, #all_lines do
			if all_lines[i] == "---" then
				content_start_line_idx = i
				break
			end
		end
		if content_start_line_idx > 0 then
			for i = 1, content_start_line_idx do
				frontmatter_char_offset = frontmatter_char_offset + vim.fn.strchars(all_lines[i]) + 1
			end
		end
	end
	local lines_to_check
	if content_start_line_idx > 0 then
		lines_to_check = {}
		for i = content_start_line_idx + 1, #all_lines do table.insert(lines_to_check, all_lines[i]) end
	else
		lines_to_check = all_lines
	end

	local original_lines = vim.list_extend({}, lines_to_check)
	
	local block_filtered = {}
	local block_map = {}
	local is_checking = (not conf.check_start_token) or conf.check_start_token == ""
	
	for i, line in ipairs(lines_to_check) do
		if conf.check_end_token and conf.check_end_token ~= "" and line:match(conf.check_end_token) then
			is_checking = false
		end
		if conf.check_start_token and conf.check_start_token ~= "" and line:match(conf.check_start_token) then
			is_checking = true
		end
		if is_checking then
			table.insert(block_filtered, line)
			table.insert(block_map, i)
		end
	end

	local filtered_lines = {}
	local line_map = {}
	for i, line in ipairs(block_filtered) do
		if filter.should_check_line(line, conf.exclude_patterns) then
			table.insert(filtered_lines, line)
			table.insert(line_map, block_map[i])
		end
	end

	if #filtered_lines == 0 then
		vim.notify("LanguageTool: No content to check after filtering.", vim.log.levels.INFO)
		return
	end

	local text_to_check = table.concat(filtered_lines, "\n")
	local cleaned_text, removals = filter.remove_inline_patterns(text_to_check, conf.inline_exclude_patterns)

	local text = url_encode(cleaned_text)
	local payload = "language=" .. conf.language .. "&text=" .. text

	local command = { "curl", "-s", "-X", "POST", "--data-binary", "@-", "http://localhost:8081/v2/check" }

	local stdout_chunks = {}
	local job = vim.fn.jobstart(command, {
		on_stdout = function(_, data) if data then table.insert(stdout_chunks, data) end end,
		on_stderr = function(_, data) if data and data[1] and data[1] ~= "" then vim.notify("LT Error: " .. table.concat(data, "\n"), vim.log.levels.ERROR) end end,
		on_exit = function()
			local raw_response = table.concat(vim.tbl_flatten(stdout_chunks) or {})
			if raw_response == "" then
				matches = {}
				vim.notify("LT: Empty response from server. Is it running?", vim.log.levels.ERROR)
				return
			end
			local ok, response = pcall(vim.fn.json_decode, raw_response)
			if not ok or not response or not response.matches then
				matches = {}
				vim.notify("LT: Failed to parse JSON.", vim.log.levels.ERROR)
				return
			end
			local ignored = load_ignored_words()
			local corrected_matches = {}
			for _, match in ipairs(response.matches) do
				local word = get_word_from_match(match)
				
				if not (word and ignored[word]) then
					local offset_with_inline = filter.adjust_offset_for_removals(match.offset, removals)
					local adjusted_offset = filter.adjust_offset(offset_with_inline, line_map, original_lines, filtered_lines)
					match.offset = adjusted_offset + frontmatter_char_offset
					table.insert(corrected_matches, match)
				end
			end
			matches = corrected_matches
			M.highlight_errors(bufnr)
			local qflist_items = {}
			for _, match in ipairs(matches) do
				local lnum, col = get_pos_from_offset(bufnr, match.offset)
				table.insert(qflist_items, { bufnr = bufnr, lnum = lnum + 1, col = col + 1, text = match.message })
			end
			vim.fn.setqflist(qflist_items)
			if on_complete_callback then
				on_complete_callback(matches)
			end
		end,
	})

	if job > 0 then
		vim.api.nvim_chan_send(job, payload)
		vim.fn.chanclose(job, "stdin")
	end
end

function M.quickfix_next_error()
	if not quickfix_mode_state.is_active then return end
	if quickfix_mode_state.current_index > #quickfix_mode_state.matches then
		vim.notify("LanguageTool: All errors processed. Quickfix mode finished.", vim.log.levels.INFO)
		M.toggle_quickfix_mode()
		return
	end
	local bufnr = vim.api.nvim_get_current_buf()
	local match = quickfix_mode_state.matches[quickfix_mode_state.current_index]
	local lnum, col = get_pos_from_offset(bufnr, match.offset)
	vim.api.nvim_win_set_cursor(0, { lnum + 1, col })
	vim.cmd("normal! zz")

	local function on_popup_close()
		if quickfix_mode_state.is_active then
			quickfix_mode_state.current_index = quickfix_mode_state.current_index + 1
			vim.defer_fn(M.quickfix_next_error, 50)
		end
	end

	local function ignore_current(error_match)
		table.insert(quickfix_mode_state.undo_stack, {
			type = "ignore",
			bufnr = bufnr,
			matches = vim.deepcopy(matches),
			qf_matches = vim.deepcopy(quickfix_mode_state.matches),
			index = quickfix_mode_state.current_index,
		})

		local word = get_word_from_match(error_match)
		
		if not word or word == "" then return end
		save_ignored_word(word)
		vim.notify('LanguageTool: Ignored "' .. word .. '"', vim.log.levels.INFO)
		
		local new_matches = {}
		local removed_before_current = 0
		for i, m in ipairs(matches) do
			local mword = get_word_from_match(m)
			
			if mword ~= word then
				table.insert(new_matches, m)
			elseif i < quickfix_mode_state.current_index then
				removed_before_current = removed_before_current + 1
			end
		end
		matches = new_matches
		M.highlight_errors(bufnr)
		quickfix_mode_state.matches = new_matches
		quickfix_mode_state.current_index = quickfix_mode_state.current_index - removed_before_current
		vim.defer_fn(M.quickfix_next_error, 50)
	end

	ui.show_popup_for_quickfix(bufnr, match, M.apply_fix, on_popup_close, ignore_current, M.undo_last_fix, M.go_back_without_undo)
end

function M.toggle_quickfix_mode()
	if quickfix_mode_state.is_active then
		quickfix_mode_state.is_active = false
		quickfix_mode_state.current_index = 0
		quickfix_mode_state.matches = {}
		quickfix_mode_state.undo_stack = {}
		vim.notify("LanguageTool: Quickfix mode deactivated.", vim.log.levels.INFO)
		return
	end
	if not matches or #matches == 0 then
		vim.notify("LanguageTool: No errors found. Run :LanguageToolCheck first.", vim.log.levels.WARN)
		return
	end
	quickfix_mode_state.is_active = true
	quickfix_mode_state.matches = matches
	quickfix_mode_state.current_index = 1
	quickfix_mode_state.undo_stack = {}
	vim.notify("LanguageTool: Quickfix mode activated with " .. #matches .. " errors.", vim.log.levels.INFO)
	M.quickfix_next_error()
end

function M.highlight_errors(bufnr)
	local ns = vim.api.nvim_create_namespace("languagetool")
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
	if not matches or #matches == 0 then return end
	local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local function get_byte_offsets(line, char_start, char_len)
		local start_byte = vim.fn.byteidx(line, char_start)
		local end_byte = vim.fn.byteidx(line, char_start + char_len)
		return start_byte, end_byte
	end
	for _, match in ipairs(matches) do
		local lnum_char, col_char = get_pos_from_offset(bufnr, match.offset)
		local line_content = all_lines[lnum_char + 1]
		if line_content then
			local byte_start_col, byte_end_col = get_byte_offsets(line_content, col_char, match.length)
			local group = "LanguageToolGrammarError"
			if match.rule and match.rule.issueType == "misspelling" then group = "LanguageToolSpellingError" end
			if byte_start_col > -1 and byte_end_col > -1 and byte_start_col < byte_end_col then
				vim.api.nvim_buf_add_highlight(bufnr, ns, group, lnum_char, byte_start_col, byte_end_col)
			end
		end
	end
end

function M.clear()
	matches = {}
	local bufnr = vim.api.nvim_get_current_buf()
	local ns = vim.api.nvim_create_namespace("languagetool")
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
	vim.fn.setqflist({})
	vim.cmd("cclose")
end

function M.apply_fix(bufnr, error_match, suggestion_nr)
	if not error_match or not error_match.replacements[suggestion_nr] then return end

	if quickfix_mode_state.is_active then
		table.insert(quickfix_mode_state.undo_stack, {
			type = "fix",
			bufnr = bufnr,
			matches = vim.deepcopy(matches),
			qf_matches = vim.deepcopy(quickfix_mode_state.matches),
			index = quickfix_mode_state.current_index,
		})
	end

	local replacement = error_match.replacements[suggestion_nr].value
	local char_length_diff = vim.fn.strchars(replacement) - error_match.length
	local start_lnum_char, start_col_char = get_pos_from_offset(bufnr, error_match.offset)
	local end_lnum_char, end_col_char = get_pos_from_offset(bufnr, error_match.offset + error_match.length)
	local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local start_line_content = all_lines[start_lnum_char + 1]
	local end_line_content = (start_lnum_char == end_lnum_char) and start_line_content or all_lines[end_lnum_char + 1]
	if not start_line_content or not end_line_content then return end
	local start_col_byte = vim.fn.byteidx(start_line_content, start_col_char)
	local end_col_byte = vim.fn.byteidx(end_line_content, end_col_char)
	
	vim.api.nvim_buf_set_text(bufnr, start_lnum_char, start_col_byte, end_lnum_char, end_col_byte, { replacement })

	if quickfix_mode_state.is_active then
		local new_matches = {}
		for _, m in ipairs(matches) do
			if m ~= error_match then
				if m.offset > error_match.offset then
					local updated = vim.tbl_extend("force", {}, m)
					updated.offset = m.offset + char_length_diff
					table.insert(new_matches, updated)
				else
					table.insert(new_matches, m)
				end
			end
		end
		matches = new_matches
		M.highlight_errors(bufnr)
		quickfix_mode_state.matches = new_matches
		vim.defer_fn(M.quickfix_next_error, 50)
	else
		vim.notify("LanguageTool: Fix applied. Re-checking...", vim.log.levels.INFO)
		vim.defer_fn(function() M.check(bufnr, nil) end, 100)
	end
end

function M.show_error_at_point()
	local bufnr = vim.api.nvim_get_current_buf()
	
	local function ignore_at_point(error_match)
		local raw_word = get_word_from_match(error_match)
		if not raw_word or raw_word == "" then return end
		save_ignored_word(raw_word)
		vim.notify('LanguageTool: Ignored "' .. raw_word .. '"', vim.log.levels.INFO)
		
		local new_matches = {}
		for _, m in ipairs(matches) do
			local mword = get_word_from_match(m)
			if mword ~= raw_word then
				table.insert(new_matches, m)
			end
		end
		matches = new_matches
		M.highlight_errors(bufnr)
	end

	ui.show_error_at_point(matches, M.apply_fix, ignore_at_point)
end

local function start_server()
	if server_is_running then return end
	local conf = config.get(_current_opts)
	local command = conf.languagetool_server_command
	if not command or command == "" then
		local dir = vim.fn.fnamemodify(conf.languagetool_server_jar, ":h")
		command = "java -cp '" .. dir .. "/*' org.languagetool.server.HTTPServer"
	end
	if vim.fn.filereadable(vim.fn.expand(conf.languagetool_server_jar)) == 0 and (not conf.languagetool_server_command or conf.languagetool_server_command == "") then
		vim.notify("LT: Cannot find languagetool-server.jar", vim.log.levels.ERROR)
		return
	end
	job_id = vim.fn.jobstart(command, {
		on_stderr = function(_, data) end,
		on_exit = function()
			server_is_running = false
			job_id = nil
		end
	})
	if job_id > 0 then
		server_is_running = true
		vim.defer_fn(function()
			M.check(vim.api.nvim_get_current_buf())
		end, 1000)
	end
end

local function stop_server()
	if job_id then
		vim.fn.jobstop(job_id)
		job_id = nil
		server_is_running = false
	end
end

function M.setup(opts)
	_current_opts = opts or {}
	ignored_words_path = _current_opts.ignored_words_path
		or (vim.fn.stdpath("data") .. "/languagetool_ignored.txt")

	vim.api.nvim_set_hl(0, "LanguageToolGrammarError", { bg = "#440000", underline = true })
	vim.api.nvim_set_hl(0, "LanguageToolSpellingError", { bg = "#444400", underline = true })

	vim.api.nvim_create_user_command("LanguageToolCheck",        function() M.check(vim.api.nvim_get_current_buf()) end, {})
	vim.api.nvim_create_user_command("LanguageToolClear",        M.clear, {})
	vim.api.nvim_create_user_command("LanguageToolStartServer",  start_server, {})
	vim.api.nvim_create_user_command("LanguageToolStopServer",   stop_server, {})
	vim.api.nvim_create_user_command("LanguageToolErrorAtPoint", M.show_error_at_point, {})
	vim.api.nvim_create_user_command("LanguageToolQuickfixMode", M.toggle_quickfix_mode, {})
	vim.api.nvim_create_user_command("LanguageToolCheckVisual",  M.check_visual, { range = true })

	vim.keymap.set("n", "<Plug>(LTCheck)",       function() M.check(vim.api.nvim_get_current_buf()) end)
	vim.keymap.set("n", "<Plug>(LTClear)",        M.clear)
	vim.keymap.set("n", "<Plug>(LTStartServer)",  start_server)
	vim.keymap.set("n", "<Plug>(LTStopServer)",   stop_server)
	vim.keymap.set("n", "<Plug>(LTErrorAtPoint)", M.show_error_at_point)
	vim.keymap.set("n", "<Plug>(LTQuickfix)",     M.toggle_quickfix_mode)
	vim.keymap.set("v", "<Plug>(LTCheckVisual)",  M.check_visual)

	vim.api.nvim_create_augroup("LanguageTool", { clear = true })
	vim.api.nvim_create_autocmd("VimLeave", { pattern = "*", group = "LanguageTool", callback = stop_server })
end

return M
