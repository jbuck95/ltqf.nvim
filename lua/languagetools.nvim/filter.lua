local M = {}

function M.should_check_line(line, patterns)
	if not patterns or #patterns == 0 then return true end
	for _, pattern in ipairs(patterns) do
		if line:match(pattern) then return false end
	end
	return true
end

function M.remove_inline_patterns(text, patterns)
	if not patterns or #patterns == 0 then return text, {} end
	local removals = {}
	local result = text
	local cumulative_removed = 0
	for _, pattern in ipairs(patterns) do
		local byte_offset = 1
		while true do
			local start_byte, end_byte = result:find(pattern, byte_offset)
			if not start_byte then break end
			local char_start_in_modified = vim.fn.strchars(result:sub(1, start_byte - 1))
			local removed_text = result:sub(start_byte, end_byte)
			local removed_length = vim.fn.strchars(removed_text)
			table.insert(removals, {
				original_start = char_start_in_modified + cumulative_removed,
				length = removed_length,
			})
			result = result:sub(1, start_byte - 1) .. result:sub(end_byte + 1)
			cumulative_removed = cumulative_removed + removed_length
			byte_offset = start_byte
		end
	end
	table.sort(removals, function(a, b) return a.original_start < b.original_start end)
	return result, removals
end

function M.adjust_offset_for_removals(offset, removals)
	if not removals or #removals == 0 then return offset end
	
	local adjusted = offset
	for _, removal in ipairs(removals) do
		if removal.original_start < adjusted then
			adjusted = adjusted + removal.length
		end
	end
	
	return adjusted
end

function M.filter_lines_with_map(lines, patterns)
	if not patterns or #patterns == 0 then 
		return lines, nil
	end
	
	local filtered = {}
	local line_map = {}
	
	for i, line in ipairs(lines) do
		if M.should_check_line(line, patterns) then
			table.insert(filtered, line)
			table.insert(line_map, i)
		end
	end
	
	return filtered, line_map
end

function M.adjust_offset(offset, line_map, original_lines, filtered_lines)
	if not line_map then return offset end
	
	local filtered_char_count = 0
	local filtered_line_idx = 1
	for i, line in ipairs(filtered_lines) do
		local line_len = vim.fn.strchars(line) + 1
		if filtered_char_count + line_len > offset then
			filtered_line_idx = i
			break
		end
		filtered_char_count = filtered_char_count + line_len
	end
	
	local original_line_idx = line_map[filtered_line_idx]
	
	local original_offset = 0
	for i = 1, original_line_idx - 1 do
		original_offset = original_offset + vim.fn.strchars(original_lines[i]) + 1
	end
	
	local offset_in_line = offset - filtered_char_count
	original_offset = original_offset + offset_in_line
	
	return original_offset
end

return M
