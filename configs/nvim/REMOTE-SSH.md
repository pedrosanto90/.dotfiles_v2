# Remote projects

Neovim runs locally; only the selected directory is mounted. Telescope, Neo-tree,
buffers and local language servers continue to use the existing configuration.
Local LSPs, terminals, builds and debuggers still run **locally**. Remote runtimes,
virtual environments and databases are not automatically forwarded like VS Code.

## Setup

The installer includes `openssh-client` and `sshfs`. On another Debian machine:

```sh
sudo apt install openssh-client sshfs
```

Lazy installs `nosduco/remote-sshfs.nvim` with the existing Telescope and Plenary.
The lockfile records the installed revision used to verify the adapter; no version
constraint was added to the plugin specification. Remote Linux hosts need a POSIX
`sh` and GNU `find`; remote search additionally needs `rg` (Debian: `ripgrep`).

Configure normal SSH aliases, keys/ssh-agent, ports and proxies in OpenSSH config.
Connect once using terminal SSH to verify a new host's fingerprint. Explorer
requests use `BatchMode=yes`, strict host-key checking and timeouts. Password and
interactive MFA prompts are deliberately unavailable. SSH config is never edited.

## Keys and navigation

| Key | Action |
| --- | --- |
| `<leader>rp` | Select an SSH host, then browse its remote home |
| `<leader>rd` | Cancel pending work / disconnect the current project |
| `<leader>rf` | Find files on the server, scoped to the mounted project |
| `<leader>rg` | Live grep on the server, scoped to the mounted project |
| Enter (browser) | Enter selected directory or activate the selected action |
| Ctrl+h (browser) | Parent directory |
| Ctrl+r (browser) | Filesystem root |
| Ctrl+y (browser) | Mount the current directory |
| Esc / Ctrl+c | Cancel the picker without mounting |

The browser includes hidden directories and follows directory symlinks. Empty
directories still show the mount/parent/root actions. Failed listings leave the
last successful view available. Paths with spaces, quotes and Unicode are quoted
for SSH and passed as one SSHFS argument. Control characters are rejected at mount
time; they can still be displayed safely during browsing.

Mounts live under `~/.sshfs/projects/<project-hash>/<alias>`. The hash separates
different projects on the same host so old buffers cannot silently reference a
different project's files. One project is connected per Neovim process. Switching
disconnects the old project but retains its buffers, including unsaved edits.
Save remote buffers before switching/disconnecting if you want to write them to
the server; reopening the same project restores their original mount paths.
Mounts owned by another Neovim session are rejected. The working directory changes
only after `/proc/self/mountinfo` confirms an SSHFS mount. Disconnect restores the
previous local cwd when the current cwd is inside the mount.

## Upstream compatibility and limitations

Verified against upstream [documentation and source](https://github.com/nosduco/remote-sshfs.nvim)
at `7a12a1677bbe96ca98f0c713448ac1f518ba09b7`:

- The documented `RemoteSSHFSConnect` command cannot accept resolved known-host
  metadata. A small adapter calls `connections.connect` with the original alias,
  selected path and prevalidated lookup metadata. Native SSHFS process management
  is retained. Authentication alone is not mount success, so the adapter suppresses
  the upstream authentication-success handler and checks the Linux mount table.
  These two internal interfaces need rechecking after upstream updates.
- Browsing, configuration resolution and key lookup are asynchronous. Upstream
  still performs a short synchronous **local** `ssh-keygen` lookup and local
  unmount commands. The precheck avoids its blocking network `ssh-keyscan` path.
  A known-host file entry is required; KnownHostsCommand-only trust is unsupported.
  `~` and `%d` expansion in known-host filenames are supported; other tokens are not.
- Host discovery supports multiple literal aliases, deduplication, quoted tokens
  and recursive/glob `Include` directives (16 levels, cycles ignored). Relative
  Includes use `~/.ssh` or `/etc/ssh` as OpenSSH does. Conditional `Host`/`Match`
  blocks are not evaluated during enumeration, so their aliases can appear even
  when inactive. OpenSSH resolves all actual connection settings. Include paths
  with environment/token expansion and exotic aliases outside letters, digits,
  underscore, dot and hyphen are not enumerated.
- `RemoteSSHFSFindFiles` and `RemoteSSHFSLiveGrep` exist upstream, but that revision
  searches the remote home and does not safely quote grep input. Use the new
  `<leader>rf` / `<leader>rg` mappings, which issue quoted, project-scoped SSH
  commands. Local `<leader>pf` / `<leader>ps` remain unchanged. Search has no file
  previews, uses newline-based results (filenames containing newlines are not
  supported), and limits each request to 20 seconds. Errors are reported.
- The directory browser does not cache listings. A disconnected SSHFS mount can
  take up to the SSH keepalive interval/count to disappear. Existing mounts can
  still exhibit normal SSHFS I/O delays during network outages.
- No persistent recent-project history or automatic reconnect was added. Reopen
  with `<leader>rp`. Do not mix the raw upstream connect/disconnect commands with
  explorer-managed mounts; use the mappings for this workflow.

## Validation

```sh
python3 -m unittest discover -s tests -p test_remote_picker.py -v
```

The isolated Neovim test checks Include discovery, special-character paths using
real local shell/find commands, hidden/empty/symlink directories, malformed output,
navigation, cancellation, SSH failure, mount confirmation and buffer preservation
using simulated SSH/plugin responses. It never connects to a server or mounts a
filesystem. Actual authentication, FUSE mounting, proxy connections and remote
search performance require a trusted development server for end-to-end testing.
