local M = {}

function M.quote(value)
	assert(not value:find("\0", 1, true), "NUL in shell argument")
	return "'" .. value:gsub("'", "'\\''") .. "'"
end

function M.alias(value)
	return value:match("^[%w_][%w_.-]*$") ~= nil
end

function M.parent(path)
	return path:match("^(.+)/[^/]+/*$") or "/"
end

function M.list_command(path)
	local target = path and M.quote(path) or '"${HOME:-/}"'
	-- A frame detects shell startup chatter instead of interpreting it as filenames.
	return "sh -c "
		.. M.quote(
			"cd -- "
				.. target
				.. (path and "" or " 2>/dev/null || cd /")
				.. " || exit; printf 'REMOTE_DIRS\\000%s\\000' \"$PWD\"; find -L . -mindepth 1 -maxdepth 1 -type d -printf '%f\\0'"
		)
end

function M.parse_listing(output)
	local parts = vim.split(output, "\0", { plain = true })
	if parts[1] ~= "REMOTE_DIRS" or not parts[2] or parts[2]:sub(1, 1) ~= "/" or parts[#parts] ~= "" then
		return nil, "Unexpected SSH output (check remote shell startup scripts)"
	end
	local names = {}
	for i = 3, #parts - 1 do
		if parts[i] == "" or parts[i]:find("/", 1, true) or parts[i] == "." or parts[i] == ".." then
			return nil, "Invalid directory name in SSH output"
		end
		names[#names + 1] = parts[i]
	end
	table.sort(names)
	return { path = parts[2], names = names }
end

-- OpenSSH has no alias enumeration command; parse only Host/Include, never settings.
function M.words(line)
	local words, word, quote = {}, "", nil
	local escaped = false
	for c in line:gmatch(".") do
		if escaped then
			word, escaped = word .. c, false
		elseif c == "\\" then
			escaped = true
		elseif quote then
			if c == quote then
				quote = nil
			else
				word = word .. c
			end
		elseif c == '"' or c == "'" then
			quote = c
		elseif c == "#" then
			break
		elseif c:match("%s") or (c == "=" and #words == 0) then
			if word ~= "" then
				words[#words + 1], word = word, ""
			end
		else
			word = word .. c
		end
	end
	if quote or escaped then
		return nil
	end
	if word ~= "" then
		words[#words + 1] = word
	end
	return words
end

function M.hosts(files)
	local hosts, seen = {}, {}
	local function read(path, base, depth)
		if seen[path] or depth > 16 then
			return
		end
		seen[path] = true
		local file = io.open(path)
		if not file then
			return
		end
		for line in file:lines() do
			local words = M.words(line)
			local key = words and words[1] and words[1]:lower()
			if key == "host" then
				for i = 2, #words do
					if M.alias(words[i]) then
						hosts[words[i]] = true
					end
				end
			elseif key == "include" then
				for i = 2, #words do
					local pattern = words[i]:gsub("^~/", vim.env.HOME .. "/")
					if pattern:sub(1, 1) ~= "/" then
						pattern = base .. "/" .. pattern
					end
					for _, included in ipairs(vim.fn.glob(pattern, false, true)) do
						read(included, base, depth + 1)
					end
				end
			end
		end
		file:close()
	end
	for _, file in ipairs(files) do
		read(file.path, file.base, 0)
	end
	local result = vim.tbl_keys(hosts)
	table.sort(result)
	return result
end

function M.mount_present(mount, contents)
	for line in contents:gmatch("[^\n]+") do
		local point = line:match("^%S+ %S+ %S+ %S+ (%S+) ")
		if point then
			point = point:gsub("\\(%d%d%d)", function(octal)
				return string.char(tonumber(octal, 8))
			end)
			if point == mount and line:find(" - fuse.sshfs ", 1, true) then
				return true
			end
		end
	end
	return false
end

return M
