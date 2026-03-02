-- /home/jan/.config/nvim/lua/languagetools/ui.lua
local M = {}

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

local function create_popup_for_error(bufnr, error_match, apply_fix_func, on_close_callback, ignore_func, undo_func, go_back_func)
	local content = { error_match.message, "---", "Suggestions:" }
	for i, suggestion in ipairs(error_match.replacements) do
		if i > 9 then break end
		table.insert(content, i .. ". " .. suggestion.value)
	end
	
	if ignore_func or undo_func or go_back_func then
		table.insert(content, "---")
	end
	if ignore_func then
		table.insert(content, "i. ignore word")
	end
	if undo_func then
		table.insert(content, "u. undo & go back")
	end
	if go_back_func then
		table.insert(content, "b. go back")
	end

	local width = 0
	for _, line in ipairs(content) do
		if #line > width then width = #line end
	end
	local height = #content
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
	local win_row = vim.fn.winline()
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "win",
		width = width,
		height = height,
		col = 4,
		row = win_row,
		style = "minimal",
		border = "single",
	})

	local function fix_and_close(suggestion_nr)
		apply_fix_func(bufnr, error_match, suggestion_nr)
		if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
	end

	local function just_close()
		if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
		if on_close_callback then on_close_callback() end
	end

	local function ignore_and_close()
		if ignore_func then ignore_func(error_match) end
		if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
	end

	local function undo_and_close()
		if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
		if undo_func then undo_func() end
	end

	local function go_back_and_close()
		if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
		if go_back_func then go_back_func() end
	end

	vim.keymap.set("n", "q", just_close, { buffer = buf, silent = true, nowait = true })
	for i = 1, 9 do
		vim.keymap.set("n", tostring(i), function() fix_and_close(i) end, { buffer = buf, silent = true, nowait = true })
	end
	if ignore_func then
		vim.keymap.set("n", "i", ignore_and_close, { buffer = buf, silent = true, nowait = true })
	end
	if undo_func then
		vim.keymap.set("n", "u", undo_and_close, { buffer = buf, silent = true, nowait = true })
	end
	if go_back_func then
		vim.keymap.set("n", "b", go_back_and_close, { buffer = buf, silent = true, nowait = true })
	end
end

function M.show_error_at_point(matches, apply_fix_func, ignore_func)
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local error_at_point
	for _, match in ipairs(matches) do
		local lnum, col = get_pos_from_offset(bufnr, match.offset)
		if cursor[1] == lnum + 1 and cursor[2] >= col and cursor[2] < col + match.length then
			error_at_point = match
			break
		end
	end
	if error_at_point then
		create_popup_for_error(bufnr, error_at_point, apply_fix_func, nil, ignore_func, nil, nil)
	else
		vim.notify("LanguageTool: No error found at cursor position.", vim.log.levels.INFO)
	end
end

function M.show_popup_for_quickfix(bufnr, match, apply_fix_func, on_close_callback, ignore_func, undo_func, go_back_func)
	create_popup_for_error(bufnr, match, apply_fix_func, on_close_callback, ignore_func, undo_func, go_back_func)
end

return M
