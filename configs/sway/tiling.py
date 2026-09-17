"""Workspace tiling presets, illustrated Wofi picker, and Sway event listener."""

import argparse
from contextlib import contextmanager
import fcntl
import html
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

import i3ipc


BASE = Path(__file__).resolve().parent
STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "debian-sway-dev/tiling.json"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "debian-sway-dev/tiling"
PRESETS = {
    "2x1": ("2 × 1", "2 janelas · Colunas", 2, 2),
    "3x1": ("3 × 1", "3 janelas · Colunas", 3, 3),
    "2x2": ("2 × 2", "4 janelas · Grelha", 2, 4),
    "master": ("1 + 4", "5 janelas · Principal", 2, 5),
    "3x2": ("3 × 2", "6 janelas · Grelha larga", 3, 6),
    "2x3": ("2 × 3", "6 janelas · Grelha alta", 2, 6),
    "4x2": ("4 × 2", "8 janelas · Grelha larga", 4, 8),
    "alternate": ("Alternado", "Direita / baixo", 0, 6),
}


@contextmanager
def lock(name, blocking=True):
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))
    socket = Path(os.environ.get("SWAYSOCK", "default")).name
    path = runtime / f"debian-sway-dev-{name}-{os.getuid()}-{socket}.lock"
    with path.open("a") as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | (0 if blocking else fcntl.LOCK_NB))
        except BlockingIOError:
            yield False
            return
        yield True


def read_state():
    try:
        state = json.loads(STATE.read_text())
        return state if isinstance(state, dict) else {}
    except (FileNotFoundError, ValueError):
        return {}


def choice(workspace):
    value = read_state().get(workspace.name, "alternate")
    return value if value in PRESETS else "alternate"


def save_choice(workspace, preset):
    STATE.parent.mkdir(parents=True, exist_ok=True)
    with lock("tiling-state"):
        state = read_state()
        state[workspace.name] = preset
        with tempfile.NamedTemporaryFile(mode="w", dir=STATE.parent, delete=False) as file:
            json.dump(state, file, ensure_ascii=False, indent=2)
            file.write("\n")
        os.replace(file.name, STATE)


def tiled(node):
    yield node
    for child in node.nodes:
        yield from tiled(child)


def windows(workspace):
    return [node for node in tiled(workspace)
            if not node.nodes and node.type == "con" and (node.app_id or node.window)]


def manual_layout(workspace):
    return any(node.layout in ("tabbed", "stacked") for node in tiled(workspace))


def command(ipc, commands):
    if not commands:
        return
    replies = ipc.command("; ".join(commands))
    errors = [reply.error for reply in replies if not reply.success]
    if errors:
        raise RuntimeError("; ".join(errors))


def groups(preset, ids):
    if preset == "master":
        return [ids[:1], ids[1:]] if len(ids) > 1 else [ids]
    columns = min(PRESETS[preset][2], len(ids))
    return [ids[column::columns] for column in range(columns)]


def arrange(ipc, workspace_id, preset):
    """Rebuild inside the workspace, preserving window identity, marks and focus."""
    with lock("tiling-apply"):
        tree = ipc.get_tree()
        workspace = tree.find_by_id(workspace_id)
        if workspace is None or workspace.type != "workspace":
            return
        leaves = windows(workspace)
        if not leaves:
            return
        ids = sorted(node.id for node in leaves)
        focused = tree.find_focused()
        restore = focused.id if focused else None
        mark = f"__dotfiles_tiling_{os.getpid()}"
        # Reuse the topmost group so repeated changes do not grow nested wrappers.
        anchor = workspace.nodes[0]
        commands = [f"[con_id={anchor.id}] mark --add {mark}"]
        if anchor.nodes:
            commands.extend(f"[con_id={wid}] move container to mark {mark}" for wid in ids)
        else:
            commands.extend(f"[con_id={wid}] move container to mark {mark}"
                            for wid in reversed(ids) if wid != anchor.id)
            if anchor.id != ids[0]:
                commands.extend([
                    f"[con_id={ids[0]}] mark --add {mark}",
                    *[f"[con_id={wid}] move container to mark {mark}" for wid in reversed(ids[1:])],
                ])
        commands.append(f"[con_id={ids[0]}] layout splith")
        if preset == "alternate":
            for index in range(2, len(ids)):
                target = ids[index - 1]
                direction = "splitv" if index % 2 == 0 else "splith"
                commands.extend([
                    f"[con_id={target}] {direction}, mark --add {mark}",
                    f"[con_id={ids[index]}] move container to mark {mark}",
                ])
        else:
            for column in groups(preset, ids):
                if len(column) > 1:
                    commands.append(f"[con_id={column[0]}] splitv, mark --add {mark}")
                    commands.extend(f"[con_id={wid}] move container to mark {mark}"
                                    for wid in reversed(column[1:]))
        commands.append(f"unmark {mark}")
        if restore is not None:
            commands.append(f"[con_id={restore}] focus")
        try:
            command(ipc, commands)
            equalize(ipc, workspace_id)
        finally:
            ipc.command(f"unmark {mark}")


def equalize(ipc, workspace_id):
    def balance(node_id):
        for _ in range(12):
            node = ipc.get_tree().find_by_id(node_id)
            if node is None:
                return
            if len(node.nodes) < 2 or node.layout not in ("splith", "splitv"):
                break
            axis = "width" if node.layout == "splith" else "height"
            sizes = [getattr(child.rect, axis) for child in node.nodes]
            if max(sizes) - min(sizes) <= 2:
                break
            size = round(sum(sizes) / len(sizes))
            # Tiled resizing redistributes space to siblings. Recheck after each
            # batch, using pixels because Sway only accepts integer percentages.
            command(ipc, [f"[con_id={child.id}] resize set {axis} {size} px"
                          for child in node.nodes])
        for child in node.nodes:
            if child.nodes:
                balance(child.id)

    balance(workspace_id)


def alternate_new(ipc, window_id):
    with lock("tiling-apply"):
        tree = ipc.get_tree()
        window = tree.find_by_id(window_id)
        workspace = window.workspace() if window else None
        if not workspace or workspace.name == "__i3_scratch" or manual_layout(workspace):
            return
        leaves = windows(workspace)
        if window_id not in [node.id for node in leaves]:
            return
        previous = [node for node in leaves if node.id < window_id]
        if not previous:
            command(ipc, [f"[con_id={window_id}] splith"])
            return
        target = max(previous, key=lambda node: node.id)
        direction = "splith" if len(previous) == 1 else "split toggle"
        mark = f"__dotfiles_tiling_{os.getpid()}"
        focused = tree.find_focused()
        commands = [
            f"[con_id={target.id}] {direction}, mark --add {mark}",
            f"[con_id={window_id}] move container to mark {mark}",
            f"unmark {mark}",
        ]
        if focused:
            commands.append(f"[con_id={focused.id}] focus")
        try:
            command(ipc, commands)
        finally:
            ipc.command(f"unmark {mark}")


def watch(ipc):
    with lock("autotiling", blocking=False) as acquired:
        if not acquired:
            return
        membership = {}

        def refresh(connection, event=None):
            nonlocal membership
            tree = connection.get_tree()
            workspaces = [ws for ws in tree.workspaces() if ws.name != "__i3_scratch"]
            current = {ws.id: tuple(sorted(node.id for node in windows(ws))) for ws in workspaces}
            previous, membership = membership, current
            for ws in workspaces:
                preset = choice(ws)
                if preset != "alternate" and previous.get(ws.id) != current[ws.id] and not manual_layout(ws):
                    arrange(connection, ws.id, preset)
            if event and event.change == "new":
                node = tree.find_by_id(event.container.id)
                ws = node.workspace() if node else None
                if ws and choice(ws) == "alternate":
                    alternate_new(connection, node.id)

        def on_window(connection, event):
            try:
                refresh(connection, event)
            except (OSError, RuntimeError) as error:
                print(f"[sway-autotiling] {error}", file=sys.stderr, flush=True)

        for event in (i3ipc.Event.WINDOW_NEW, i3ipc.Event.WINDOW_CLOSE,
                      i3ipc.Event.WINDOW_MOVE, i3ipc.Event.WINDOW_FLOATING):
            ipc.on(event, on_window)
        refresh(ipc)
        ipc.main()


def active_workspace(ipc):
    focused = ipc.get_tree().find_focused()
    workspace = focused.workspace() if focused else None
    if workspace is None:
        raise RuntimeError("Não foi possível identificar o workspace atual.")
    return workspace


def status(ipc):
    workspace = active_workspace(ipc)
    preset = choice(workspace)
    label = PRESETS[preset][0]
    print(json.dumps({
        "text": "󰕰" if preset == "alternate" else f"󰕰 {label}",
        "tooltip": f"Layout: {label}\nWorkspace {workspace.name}\nClicar para escolher um padrão",
        "class": preset,
    }, ensure_ascii=False))


def palette():
    colors = {"blue": "#7aa2f7", "foreground": "#c0caf5", "tooltip_background": "#1a1b26", "border": "#3b4261"}
    path = BASE.parent / "waybar/colors.css"
    seen = set()
    while path.exists() and path not in seen:
        seen.add(path)
        css = path.read_text()
        colors.update(re.findall(r"@define-color\s+(\w+)\s+(#[\da-fA-F]+)\s*;", css))
        imported = re.search(r'@import\s+"([^\"]+)"', css)
        if not imported:
            break
        path = path.parent / imported[1]
    return colors


def preview(preset, colors):
    count = PRESETS[preset][3]
    rectangles = []
    if preset == "alternate":
        x = y = 0.0
        width = height = 1.0
        for index in range(count - 1):
            if index % 2 == 0:
                width /= 2
                rectangles.append((index + 1, x, y, width, height))
                x += width
            else:
                height /= 2
                rectangles.append((index + 1, x, y, width, height))
                y += height
        rectangles.append((count, x, y, width, height))
    else:
        columns = groups(preset, list(range(1, count + 1)))
        for column, ids in enumerate(columns):
            for row, wid in enumerate(ids):
                rectangles.append((wid, column / len(columns), row / len(ids), 1 / len(columns), 1 / len(ids)))
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="144" height="94" viewBox="0 0 144 94">']
    svg.append(f'<rect width="144" height="94" rx="7" fill="{colors["tooltip_background"]}"/>')
    for wid, x, y, width, height in rectangles:
        x, y, width, height = 5 + x * 136, 5 + y * 86, width * 136 - 4, height * 86 - 4
        svg.append(f'<rect x="{x:g}" y="{y:g}" width="{width:g}" height="{height:g}" rx="2" fill="{colors["blue"]}" fill-opacity=".20" stroke="{colors["blue"]}"/>')
        if width > 18 and height > 15:
            svg.append(f'<text x="{x + width / 2:g}" y="{y + height / 2 + 4:g}" fill="{colors["foreground"]}" font-family="sans-serif" font-size="11" text-anchor="middle">{wid}</text>')
    return "\n".join([*svg, "</svg>"])


def menu(ipc):
    with lock("tiling-menu", blocking=False) as acquired:
        if not acquired:
            return
        workspace = active_workspace(ipc)
        selected = choice(workspace)
        CACHE.mkdir(parents=True, exist_ok=True)
        colors = palette()
        # Wofi loads CSS as text, so relative @imports have no file base.
        style = CACHE / "picker.css"
        definitions = "\n".join(f"@define-color {name} {value};" for name, value in colors.items())
        style.write_text(definitions + "\n" + (BASE / "tiling.css").read_text())
        entries = []
        keys = list(PRESETS)
        for key, (label, description, _, _) in PRESETS.items():
            path = CACHE / f"{key}.svg"
            path.write_text(preview(key, colors))
            active = " ✓" if key == selected else ""
            text = f"<b>{html.escape(label + active)}</b>&#10;<small>{html.escape(description)}</small>"
            entries.append(f"img:{path}:text:{text}")
        result = subprocess.run([
            "wofi", "--dmenu", "--conf", "/dev/null", "--style", str(style),
            "--prompt", f"Layout · Workspace {workspace.name}", "--width", "800", "--height", "620",
            "--columns", "2", "--allow-images", "--allow-markup", "--insensitive", "--parse-search",
            "--hide-scroll", "--cache-file", "/dev/null", "--define", "image_size=144",
            "--define", "dmenu-print_line_num=true",
        ], input="\n".join(entries), text=True, capture_output=True)
        if result.returncode != 0:
            return
        try:
            index = int(result.stdout.strip())
            if not 0 <= index < len(keys):
                return
        except ValueError:
            return
        preset = keys[index]
        save_choice(workspace, preset)
        arrange(ipc, workspace.id, preset)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("menu", "status", "watch", "apply"), nargs="?", default="menu")
    parser.add_argument("preset", choices=PRESETS, nargs="?")
    args = parser.parse_args()
    if args.action == "apply" and not args.preset:
        parser.error("apply requires a preset")
    if not os.environ.get("SWAYSOCK"):
        raise RuntimeError("Este comando requer uma sessão Sway ativa.")
    ipc = i3ipc.Connection(socket_path=os.environ["SWAYSOCK"])
    if args.action == "apply":
        workspace = active_workspace(ipc)
        save_choice(workspace, args.preset)
        arrange(ipc, workspace.id, args.preset)
    else:
        {"menu": menu, "status": status, "watch": watch}[args.action](ipc)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError) as error:
        print(f"[sway-layout] {error}", file=sys.stderr)
        sys.exit(1)
