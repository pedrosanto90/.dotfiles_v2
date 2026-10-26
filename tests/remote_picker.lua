vim.opt.rtp:prepend(vim.fn.getcwd() .. "/configs/nvim")
local paths = require("pedro.utils.remote-paths")
local temp = vim.fn.tempname()
vim.fn.mkdir(temp .. "/.ssh/conf.d", "p")
local original_home = vim.env.HOME
vim.env.HOME = temp
local function write(path, lines)
	vim.fn.writefile(lines, path)
end
write(temp .. "/.ssh/config", {
	"Host dev other dev *.bad !excluded bad? -option",
	'Include "conf.d/*.conf"',
	'Host = "quoted-host" # comment',
})
write(temp .. "/.ssh/conf.d/nested.conf", { "host nested", "Include config", "Host *.wild" })
assert(
	vim.deep_equal(
		paths.hosts({ { path = temp .. "/.ssh/config", base = temp .. "/.ssh" } }),
		{ "dev", "nested", "other", "quoted-host" }
	)
)
assert(paths.parent("/home/user") == "/home")
assert(paths.parent("/home") == "/")
assert(paths.parent("/") == "/")
assert(not paths.alias("$(touch /tmp/unsafe)"))
assert(not paths.parse_listing("banner\nREMOTE_DIRS\0/\0"))
assert(not paths.parse_listing("REMOTE_DIRS\0/\0../evil\0"))
assert(not paths.parse_listing("REMOTE_DIRS\0/\0unterminated"))
local directory = temp .. "/space ' unicode ç ; $(echo bad)"
vim.fn.mkdir(directory .. "/.hidden", "p")
vim.fn.mkdir(directory .. "/child space")
vim.uv.fs_symlink(directory .. "/child space", directory .. "/link")
local result = vim.system({ "sh", "-c", paths.list_command(directory) }):wait()
assert(result.code == 0, result.stderr)
local listing = assert(paths.parse_listing(result.stdout))
assert(listing.path == directory)
assert(vim.deep_equal(listing.names, { ".hidden", "child space", "link" }))
local empty = vim.system({ "sh", "-c", paths.list_command(directory .. "/child space") }):wait()
assert(#assert(paths.parse_listing(empty.stdout)).names == 0)
assert(vim.system({ "sh", "-c", paths.list_command(temp .. "/missing") }):wait().code ~= 0)
assert(paths.mount_present("/test mount", "1 2 3:4 / /test\\040mount rw - fuse.sshfs dev:/ rw\n"))
assert(not paths.mount_present("/test", "1 2 3:4 / /test rw - ext4 /dev/sda rw\n"))

-- Exercise UI actions and asynchronous lifecycle without SSH, FUSE or real config.
local requests, notices, timers, pickers, connects = {}, {}, {}, {}, {}
local table_mount = ""
local real_open, real_system = io.open, vim.system
io.open = function(file, ...)
	if file == "/proc/self/mountinfo" then
		return {
			read = function()
				return table_mount
			end,
			close = function() end,
		}
	end
	return real_open(file, ...)
end
vim.notify = function(msg)
	notices[#notices + 1] = msg
end
vim.defer_fn = function(callback)
	timers[#timers + 1] = callback
end
vim.system = function(argv, opts, callback)
	assert(opts.timeout == 20000)
	local job = {
		argv = argv,
		callback = callback,
		kill = function(self)
			self.killed = true
		end,
	}
	requests[#requests + 1] = job
	return job
end
local function reply(code, stdout, stderr)
	requests[#requests].callback({ code = code, stdout = stdout or "", stderr = stderr or "" })
	vim.wait(10, function()
		return false
	end)
end
local selected
package.loaded["telescope.actions.state"] = {
	get_selected_entry = function()
		return { value = selected }
	end,
}
local select_action = {}
function select_action:replace(callback)
	self.callback = callback
end
package.loaded["telescope.actions"] = {
	select_default = select_action,
	close = function(buf)
		vim.api.nvim_buf_delete(buf, { force = true })
	end,
}
package.loaded["telescope.finders"] = {
	new_table = function(opts)
		return opts
	end,
}
package.loaded["telescope.config"] = { values = { generic_sorter = function() end, file_sorter = function() end } }
package.loaded["telescope.sorters"] = { highlighter_only = function() end }
package.loaded["telescope.make_entry"] = {
	gen_from_vimgrep = function()
		return function(line)
			return { value = line }
		end
	end,
}
package.loaded["telescope.pickers"] = {
	new = function(_, opts)
		local instance = {
			opts = opts,
			entries = opts.finder.results,
			maps = {},
			results_border = { change_title = function() end },
		}
		function instance:find()
			self.buf = vim.api.nvim_create_buf(false, true)
			if opts.attach_mappings then
				opts.attach_mappings(self.buf, function(mode, key, fn)
					self.maps[mode .. key] = fn
				end)
			end
		end
		function instance:refresh(finder)
			self.entries = finder.results
		end
		function instance:set_selection() end
		pickers[#pickers + 1] = instance
		return instance
	end,
}
local plugin_options
package.loaded["remote-sshfs"] = {
	setup = function(opts)
		plugin_options = opts
	end,
}
package.loaded["remote-sshfs.handler"] = {}
package.loaded["remote-sshfs.connections"] = {
	connect = function(host)
		connects[#connects + 1] = host
	end,
}
package.loaded["remote-sshfs.api"] = {
	disconnect = function()
		table_mount = ""
	end,
}
local explorer = require("pedro.utils.remote-picker")
explorer.setup()
local original_cwd = vim.fn.getcwd()
explorer.open()
selected = { label = "dev" }
select_action.callback()
vim.wait(10, function()
	return false
end)
assert(requests[#requests].argv[1] == "ssh")
assert(vim.tbl_contains(requests[#requests].argv, "BatchMode=yes"))
assert(vim.tbl_contains(requests[#requests].argv, "StrictHostKeyChecking=yes"))
reply(0, "REMOTE_DIRS\0/home/user\0project space\0.hidden\0")
local browser = pickers[#pickers]
assert(#browser.entries == 5)
selected = browser.entries[5]
select_action.callback()
assert(requests[#requests].argv[#requests[#requests].argv]:find("project space", 1, true))
reply(0, "REMOTE_DIRS\0/home/user/project space\0")
browser.maps["i<C-h>"]()
reply(0, "REMOTE_DIRS\0/home/user\0")
browser.maps["i<C-r>"]()
reply(0, "REMOTE_DIRS\0/\0")
browser.maps["i<C-y>"]()
assert(requests[#requests].argv[2] == "-G")
reply(0, "hostname server.example\nport 2222\nuserknownhostsfile " .. temp .. "/known_hosts\n")
assert(requests[#requests].argv[3] == "[server.example]:2222")
reply(0, "# Host found: line 1\n")
assert(connects[1].Name == "dev" and connects[1].Path == "/")
assert(vim.fn.getcwd() == original_cwd, "changed cwd before mount")
package.loaded["remote-sshfs.handler"].authenticated_handler()
assert(vim.fn.getcwd() == original_cwd, "authentication is not mount success")
local mount = plugin_options.mounts.base_dir .. "dev"
vim.fn.mkdir(mount, "p")
table_mount = "1 2 3:4 / " .. mount .. " rw - fuse.sshfs dev:/ rw\n"
table.remove(timers, 1)()
assert(vim.fn.getcwd() == mount)
explorer.open()
selected = { label = "dev" }
select_action.callback()
vim.wait(10, function()
	return false
end)
reply(0, "REMOTE_DIRS\0/\0")
pickers[#pickers].maps["i<C-y>"]()
assert(#connects == 1, "duplicate mount")
explorer.search(true)
reply(0)
local search = pickers[#pickers].opts.finder
local completed = false
search("'; touch /tmp/UNSAFE; #", function() end, function()
	completed = true
end)
local command = requests[#requests].argv[#requests[#requests].argv]
assert(command:find(paths.quote(paths.quote("'; touch /tmp/UNSAFE; #")):sub(2, -2), 1, true))
reply(1)
assert(completed, "empty grep should finish")
search("example", function() end, function() end)
reply(255, "", "Connection lost")
assert(notices[#notices]:find("Connection lost", 1, true))
search("cancel", function()
	error("cancelled search emitted results")
end, function() end)
search.close()
assert(requests[#requests].killed)
reply(0, "unwanted\n")
local saved_buffer = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(saved_buffer, 0, -1, false, { "unsaved work" })
explorer.disconnect()
assert(vim.fn.getcwd() == original_cwd)
assert(vim.api.nvim_buf_is_valid(saved_buffer))
explorer.open()
selected = { label = "dev" }
select_action.callback()
vim.wait(10, function()
	return false
end)
local cancelled = requests[#requests]
pickers[#pickers].maps["i<Esc>"]()
assert(cancelled.killed)
reply(0, "REMOTE_DIRS\0/should-not-open\0")
assert(#connects == 1)
-- A mount timeout must not change cwd or claim success.
explorer.open()
selected = { label = "dev" }
select_action.callback()
vim.wait(10, function()
	return false
end)
reply(0, "REMOTE_DIRS\0/missing\0")
pickers[#pickers].maps["i<C-y>"]()
reply(0, "hostname server.example\nport 22\nuserknownhostsfile " .. temp .. "/known_hosts\n")
reply(0, "found")
for _ = 1, 155 do
	if #timers > 0 then
		table.remove(timers, 1)()
	end
end
assert(vim.fn.getcwd() == original_cwd)
assert(table.concat(notices, "\n"):find("within 15 seconds", 1, true))
explorer.open()
selected = { label = "dev" }
select_action.callback()
vim.wait(10, function()
	return false
end)
reply(255, "", "Permission denied (publickey)")
assert(notices[#notices]:find("Permission denied", 1, true))
pickers[#pickers].maps["i<Esc>"]()
io.open, vim.system, vim.env.HOME = real_open, real_system, original_home
vim.fn.delete(temp, "rf")
print("remote explorer checks passed")
