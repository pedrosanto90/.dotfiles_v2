local M = {}
local paths = require("pedro.utils.remote-paths")
local active, pending, browser
local options = {
	connections = {
		ssh_configs = {}, -- Our picker enumerates Includes without synchronous ssh -G calls.
		sshfs_args = {
			"-o BatchMode=yes",
			"-o StrictHostKeyChecking=yes",
			"-o ConnectTimeout=10",
			"-o ServerAliveInterval=15",
			"-o ServerAliveCountMax=3",
		},
	},
	mounts = { unmount_on_exit = true },
	handlers = { on_connect = { change_dir = false } },
	ui = { picker = "telescope", confirm = { connect = false } },
}

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "Remote projects" })
end

local function run(argv, callback)
	local ok, process = pcall(vim.system, argv, { timeout = 20000 }, vim.schedule_wrap(callback))
	if not ok then
		vim.schedule(function()
			callback({ code = -1, stdout = "", stderr = tostring(process) })
		end)
		return nil
	end
	return process
end

local function ssh(host, command)
	return {
		"ssh",
		"-T",
		"-o",
		"BatchMode=yes",
		"-o",
		"StrictHostKeyChecking=yes",
		"-o",
		"ConnectTimeout=10",
		"-o",
		"ServerAliveInterval=5",
		"-o",
		"ServerAliveCountMax=2",
		host,
		command,
	}
end

local function failure(host, result)
	notify(
		host
			.. ": "
			.. (
				result.code == 124 and "SSH operation timed out"
				or vim.trim(result.stderr or "") ~= "" and vim.trim(result.stderr)
				or "SSH failed (" .. result.code .. ")"
			),
		vim.log.levels.ERROR
	)
end

local function mounted(dir)
	local file = io.open("/proc/self/mountinfo")
	if not file then
		return false
	end
	local contents = file:read("*a")
	file:close()
	return paths.mount_present(dir, contents)
end

local function picker(title, entries, select, attach)
	local actions = require("telescope.actions")
	local instance = require("telescope.pickers").new({}, {
		prompt_title = title,
		previewer = false,
		finder = require("telescope.finders").new_table({
			results = entries,
			entry_maker = function(entry)
				return { value = entry, display = vim.fn.strtrans(entry.label), ordinal = entry.label }
			end,
		}),
		sorter = require("telescope.config").values.generic_sorter({}),
		attach_mappings = function(buf, map)
			actions.select_default:replace(function()
				local entry = require("telescope.actions.state").get_selected_entry()
				if entry then
					select(entry.value, buf)
				end
			end)
			if attach then
				attach(buf, map)
			end
			return true
		end,
	})
	instance:find()
	return instance
end

function M.setup()
	require("remote-sshfs").setup(options)
	-- Upstream's callback fires on authentication, before SSHFS mounts. No public
	-- hook suppresses this false success; our mount-table check replaces it.
	require("remote-sshfs.handler").authenticated_handler = function() end
	require("remote-sshfs.handler").askpass_handler = function()
		notify("Use an SSH key/agent; interactive passwords are disabled", vim.log.levels.ERROR)
	end
end

local function cancel_browser()
	if browser then
		browser.cancelled = true
		if browser.process then
			browser.process:kill(15)
		end
		browser = nil
	end
end

function M.disconnect(done)
	cancel_browser()
	local project = pending or active
	if not project then
		notify("No remote project connected")
		return
	end
	project.cancelled = true
	if project.process then
		project.process:kill(15)
	end
	local was_mounted = mounted(project.mount)
	if active then
		local cwd = vim.fn.getcwd()
		if cwd == active.mount or cwd:sub(1, #active.mount + 1) == active.mount .. "/" then
			local ok = pcall(vim.api.nvim_set_current_dir, active.previous_cwd)
			if not ok then
				vim.api.nvim_set_current_dir(vim.env.HOME)
			end
		end
	end
	-- Native disconnect owns the SSHFS process and its connection state.
	require("remote-sshfs.api").disconnect()
	local attempts = 0
	local function check()
		attempts = attempts + 1
		if mounted(project.mount) then
			if attempts < 30 then
				vim.defer_fn(check, 100)
				return
			end
			notify(
				"Unmount failed: " .. project.mount .. ". Close external users of the mount and retry.",
				vim.log.levels.ERROR
			)
			return
		end
		pending, active = nil, nil
		if was_mounted then
			notify("Disconnected " .. project.host)
		end
		if done then
			done()
		end
	end
	check()
end

-- The public command cannot carry resolved known-host metadata. This narrow
-- internal adapter keeps native process ownership, but avoids upstream keyscan
-- (blocking and incompatible with proxies/custom known-host files).
local function connect(project, lookup, known_file)
	options.connections.ssh_known_hosts = known_file
	options.mounts.base_dir = project.base .. "/"
	require("remote-sshfs").setup(options)
	local ok, err = pcall(
		require("remote-sshfs.connections").connect,
		{ Name = project.host, HostName = lookup, Path = project.path }
	)
	if not ok then
		notify("Could not start SSHFS: " .. tostring(err), vim.log.levels.ERROR)
		M.disconnect()
		return
	end
	local attempts = 0
	local function check()
		if project.cancelled or pending ~= project then
			return
		end
		attempts = attempts + 1
		if mounted(project.mount) then
			active, pending = project, nil
			local ok, err = pcall(vim.api.nvim_set_current_dir, project.mount)
			if not ok then
				notify("Mounted, but could not change directory: " .. err, vim.log.levels.ERROR)
				return
			end
			notify("Mounted " .. project.host .. ":" .. project.path)
			local function monitor()
				if active ~= project or project.cancelled then
					return
				end
				if not mounted(project.mount) then
					notify("Remote mount disconnected: " .. project.host, vim.log.levels.ERROR)
					M.disconnect()
				else
					vim.defer_fn(monitor, 2000)
				end
			end
			vim.defer_fn(monitor, 2000)
		elseif attempts >= 150 then
			notify(
				"SSHFS did not mount " .. project.host .. ":" .. project.path .. " within 15 seconds; disconnecting",
				vim.log.levels.ERROR
			)
			M.disconnect()
		else
			vim.defer_fn(check, 100)
		end
	end
	check()
end

local function mount(host, path)
	if pending then
		notify("A mount is in progress; <leader>rd cancels it", vim.log.levels.WARN)
		return
	end
	if path:sub(1, 1) ~= "/" or path:find("%c") then
		notify("Cannot mount this path: absolute paths without control characters are required", vim.log.levels.ERROR)
		return
	end
	if active and active.host == host and active.path == path and mounted(active.mount) then
		vim.api.nvim_set_current_dir(active.mount)
		notify("Project already mounted")
		return
	end
	if active then
		M.disconnect(function()
			mount(host, path)
		end)
		return
	end
	local base = vim.env.HOME .. "/.sshfs/projects/" .. vim.fn.sha256(host .. ":" .. path):sub(1, 20)
	local project =
		{ host = host, path = path, base = base, mount = base .. "/" .. host, previous_cwd = vim.fn.getcwd() }
	if mounted(project.mount) then
		notify("Project is mounted by another session: " .. project.mount, vim.log.levels.ERROR)
		return
	end
	local ok, err = pcall(vim.fn.mkdir, base, "p", 448)
	if not ok then
		notify("Cannot create mount directory: " .. tostring(err), vim.log.levels.ERROR)
		return
	end
	pending = project
	notify("Preparing mount for " .. host .. ":" .. path)
	project.process = run({ "ssh", "-G", host }, function(result)
		if project.cancelled then
			return
		end
		if result.code ~= 0 then
			pending = nil
			failure(host, result)
			return
		end
		local config = {}
		for line in result.stdout:gmatch("[^\n]+") do
			local key, value = line:match("^(%S+)%s+(.+)$")
			if key then
				config[key] = value
			end
		end
		local lookup = config.hostkeyalias
		if not lookup or lookup == "none" then
			lookup = config.hostname or host
			if config.port and config.port ~= "22" then
				lookup = "[" .. lookup .. "]:" .. config.port
			end
		end
		local files = paths.words(
			(config.userknownhostsfile or "~/.ssh/known_hosts") .. " " .. (config.globalknownhostsfile or "")
		) or {}
		local index = 0
		local function verify()
			if project.cancelled then
				return
			end
			index = index + 1
			if not files[index] then
				pending = nil
				notify(
					"No known-host file entry for "
						.. lookup
						.. ". Verify this host with terminal SSH first. KnownHostsCommand-only trust is not supported by remote-sshfs.",
					vim.log.levels.ERROR
				)
				return
			end
			local file = files[index]:gsub("^~/", vim.env.HOME .. "/"):gsub("%%d", vim.env.HOME)
			project.process = run({ "ssh-keygen", "-F", lookup, "-f", file }, function(key)
				if project.cancelled then
					return
				end
				if key.code == 0 and key.stdout:find("found", 1, true) then
					connect(project, lookup, file)
				else
					verify()
				end
			end)
		end
		verify()
	end)
end

local function browse(host)
	cancel_browser()
	local session = { host = host }
	browser = session
	local instance, prompt, current, generation = nil, nil, nil, 0
	local function listing(path)
		generation = generation + 1
		local request = generation
		if session.process then
			session.process:kill(15)
		end
		session.loading = true
		notify("Listing " .. host .. ":" .. (path or "~") .. " …")
		session.process = run(ssh(host, paths.list_command(path)), function(result)
			if session.cancelled or request ~= generation then
				return
			end
			session.loading = false
			if result.code ~= 0 then
				failure(host, result)
				return
			end
			local data, err = paths.parse_listing(result.stdout)
			if not data then
				notify(err, vim.log.levels.ERROR)
				return
			end
			current = data.path
			local entries = {
				{ label = "[Mount current directory]", mount = true },
				{ label = "../", path = paths.parent(current) },
				{ label = "[Filesystem root]", path = "/" },
			}
			for _, name in ipairs(data.names) do
				entries[#entries + 1] = { label = name .. "/", path = current:gsub("/$", "") .. "/" .. name }
			end
			instance:refresh(
				require("telescope.finders").new_table({
					results = entries,
					entry_maker = function(entry)
						return { value = entry, display = vim.fn.strtrans(entry.label), ordinal = entry.label }
					end,
				}),
				{ reset_prompt = true }
			)
			instance.results_title = vim.fn.strtrans(host .. ":" .. current)
			instance.results_border:change_title(instance.results_title)
			instance:set_selection(1)
		end)
	end
	instance = picker(host .. " — Enter: open | C-h: parent | C-r: root | C-y: mount", {}, function(entry, buf)
		if session.loading then
			return
		end
		if entry.mount then
			require("telescope.actions").close(buf)
			mount(host, current)
		else
			listing(entry.path)
		end
	end, function(buf, map)
		prompt = buf
		vim.api.nvim_create_autocmd("BufWipeout", {
			buffer = buf,
			once = true,
			callback = function()
				session.cancelled = true
				if session.process then
					session.process:kill(15)
				end
				if browser == session then
					browser = nil
				end
			end,
		})
		for _, mode in ipairs({ "i", "n" }) do
			map(mode, "<C-h>", function()
				if current then
					listing(paths.parent(current))
				end
			end)
			map(mode, "<C-r>", function()
				listing("/")
			end)
			map(mode, "<C-y>", function()
				if current and not session.loading then
					require("telescope.actions").close(buf)
					mount(host, current)
				end
			end)
			map(mode, "<Esc>", function()
				require("telescope.actions").close(buf)
			end)
		end
	end)
	if prompt then
		listing(nil)
	end
end

function M.open()
	for _, exe in ipairs({ "ssh", "sshfs", "ssh-keygen" }) do
		if vim.fn.executable(exe) == 0 then
			notify("Missing " .. exe .. "; install: sudo apt install openssh-client sshfs", vim.log.levels.ERROR)
			return
		end
	end
	if pending then
		notify("A mount is in progress; <leader>rd cancels it", vim.log.levels.WARN)
		return
	end
	cancel_browser()
	local hosts = paths.hosts({
		{ path = vim.env.HOME .. "/.ssh/config", base = vim.env.HOME .. "/.ssh" },
		{ path = "/etc/ssh/ssh_config", base = "/etc/ssh" },
	})
	if #hosts == 0 then
		notify("No literal SSH Host aliases found in OpenSSH config", vim.log.levels.WARN)
		return
	end
	local entries = {}
	for _, host in ipairs(hosts) do
		entries[#entries + 1] = { label = host }
	end
	picker("Remote SSH Hosts", entries, function(entry, buf)
		require("telescope.actions").close(buf)
		vim.schedule(function()
			browse(entry.label)
		end)
	end)
end

function M.search(grep)
	if not active or not mounted(active.mount) then
		notify("Mount a remote project first", vim.log.levels.WARN)
		return
	end
	local project = active
	-- Upstream search ignores host.Path and does not shell-quote grep prompts.
	-- Use Telescope's job finder with one quoted remote command scoped to the root.
	local opts = { cwd = project.mount }
	local make_entry = require("telescope.make_entry")
	local function command(query)
		return ssh(
			project.host,
			"sh -c "
				.. paths.quote(
					"cd -- "
						.. paths.quote(project.path)
						.. " && rg "
						.. (
							grep and "--vimgrep --color=never --smart-case -- " .. paths.quote(query) .. " ."
							or "--files --color=never"
						)
				)
		)
	end
	run(ssh(project.host, "command -v rg >/dev/null"), function(result)
		if active ~= project then
			return
		end
		if result.code ~= 0 then
			failure(project.host, result)
			notify("Remote search requires ripgrep on the server", vim.log.levels.ERROR)
			return
		end
		local process, generation = nil, 0
		local maker = grep and make_entry.gen_from_vimgrep(opts) or make_entry.gen_from_file(opts)
		local finder = setmetatable({
			close = function()
				generation = generation + 1
				if process then
					process:kill(15)
				end
			end,
		}, {
			__call = function(_, query, result_callback, complete)
				generation = generation + 1
				local request = generation
				if process then
					process:kill(15)
				end
				if grep and query == "" then
					complete()
					return
				end
				process = run(command(query), function(result)
					if generation ~= request then
						return
					end
					if result.code ~= 0 and not (grep and result.code == 1) then
						failure(project.host, result)
					end
					for line in result.stdout:gmatch("[^\n]+") do
						local entry = maker(line)
						if entry and result_callback(entry) then
							break
						end
					end
					complete()
				end)
			end,
		})
		require("telescope.pickers")
			.new(opts, {
				prompt_title = grep and "Remote project grep" or "Remote project files",
				finder = finder,
				previewer = false,
				sorter = grep and require("telescope.sorters").highlighter_only(opts)
					or require("telescope.config").values.file_sorter(opts),
			})
			:find()
	end)
end

return M
