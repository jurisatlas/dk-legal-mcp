# -*- coding: utf-8 -*-
"""JurisAtlas Interactive AI Client Selector & Setup Wizard (macOS GUI + CLI)."""
from __future__ import annotations

import argparse
import datetime
import json
import os
import pathlib
import queue
import re
import shutil
import subprocess
import tempfile
import threading
from typing import Callable

REPO_NAME = "dk-legal-mcp"
COUNTRY_NAME = "Denmark"
CITATION_EXAMPLE = "UfR 2024.123 H or LBK nr 100"
STARTER_PROMPT = (
    f"Verify {CITATION_EXAMPLE} in official {COUNTRY_NAME} legal registries, "
    "confirm whether it is a VERIFIED_OFFICIAL_RECORD or UNCONFIRMED_WEB_MATCH, "
    "and summarize the controlling rule with official links."
)

CLIENT_SPECS: list[tuple[str, str]] = [
    ("claude", "Claude Desktop & Claude Code CLI"),
    ("cursor", "Cursor Editor"),
    ("vscode", "VS Code (Copilot / Cline / Roo Code)"),
    ("windsurf", "Windsurf (Codeium)"),
    ("antigravity", "Google Antigravity & Gemini CLI"),
    ("lmstudio", "LM Studio"),
    ("codex", "OpenAI Codex CLI"),
    ("continue", "Continue.dev"),
]


def get_persistent_install_dir(repo_name: str = REPO_NAME, home: pathlib.Path | None = None) -> pathlib.Path:
    home_dir = home if home is not None else pathlib.Path.home()
    return home_dir / ".jurisatlas" / repo_name


def strip_jsonc(raw: str) -> str:
    """Strip // and /* */ comments and trailing commas outside string literals."""
    out: list[str] = []
    i = 0
    n = len(raw)
    in_str = False
    esc = False
    while i < n:
        ch = raw[i]
        if in_str:
            out.append(ch)
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
            i += 1
        else:
            if ch == '"':
                in_str = True
                out.append(ch)
                i += 1
            elif ch == "/" and i + 1 < n and raw[i + 1] == "/":
                i += 2
                while i < n and raw[i] not in ("\r", "\n"):
                    i += 1
            elif ch == "/" and i + 1 < n and raw[i + 1] == "*":
                i += 2
                while i + 1 < n and not (raw[i] == "*" and raw[i + 1] == "/"):
                    i += 1
                i += 2
            else:
                out.append(ch)
                i += 1

    no_comments = "".join(out)
    res: list[str] = []
    i = 0
    n = len(no_comments)
    in_str = False
    esc = False
    while i < n:
        ch = no_comments[i]
        if in_str:
            res.append(ch)
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
            i += 1
        else:
            if ch == '"':
                in_str = True
                res.append(ch)
                i += 1
            elif ch == ",":
                j = i + 1
                while j < n and no_comments[j] in " \t\r\n":
                    j += 1
                if j < n and no_comments[j] in ("}", "]"):
                    i += 1
                    continue
                res.append(ch)
                i += 1
            else:
                res.append(ch)
                i += 1
    return "".join(res)


def create_timestamped_backup(path: pathlib.Path) -> pathlib.Path:
    ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    bak = path.with_name(f"{path.name}.jurisatlas-bak-{ts}")
    idx = 1
    while bak.exists():
        bak = path.with_name(f"{path.name}.jurisatlas-bak-{ts}-{idx}")
        idx += 1
    shutil.copy2(path, bak)
    return bak


def atomic_write_text(path: pathlib.Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(
        dir=str(path.parent),
        prefix=f".{path.name}.",
        suffix=".tmp",
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp_name, path)
    except Exception:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise


def load_json_strict(path: pathlib.Path) -> dict[str, object]:
    if not path.exists() or path.stat().st_size == 0:
        return {}
    raw = path.read_text(encoding="utf-8-sig")
    if not raw.strip():
        return {}
    try:
        loaded = json.loads(strip_jsonc(raw))
    except Exception as exc:
        raise RuntimeError(
            f"Refusing to overwrite malformed JSON in '{path}': {exc}. "
            "Please repair or rename the file before retrying."
        ) from exc
    if not isinstance(loaded, dict):
        raise RuntimeError(f"Refusing to overwrite non-object JSON in '{path}'.")
    return loaded


def detect_installed_mac_clients(home: pathlib.Path | None = None) -> dict[str, bool]:
    home_dir = home if home is not None else pathlib.Path.home()
    app_support = home_dir / "Library" / "Application Support"
    apps = pathlib.Path("/Applications")
    return {
        "claude": any([
            (apps / "Claude.app").exists(),
            (app_support / "Claude").exists(),
            (home_dir / ".claude").exists(),
            (home_dir / ".claude.json").exists(),
            shutil.which("claude") is not None,
        ]),
        "cursor": any([
            (apps / "Cursor.app").exists(),
            (home_dir / ".cursor").exists(),
            (app_support / "Cursor").exists(),
        ]),
        "vscode": any([
            (apps / "Visual Studio Code.app").exists(),
            (app_support / "Code").exists(),
            shutil.which("code") is not None,
        ]),
        "windsurf": any([
            (apps / "Windsurf.app").exists(),
            (home_dir / ".codeium" / "windsurf").exists(),
            (app_support / "Windsurf").exists(),
        ]),
        "antigravity": any([
            (home_dir / ".gemini" / "antigravity").exists(),
            (home_dir / ".gemini" / "settings.json").exists(),
            shutil.which("gemini") is not None,
        ]),
        "lmstudio": any([
            (apps / "LM Studio.app").exists(),
            (home_dir / ".lmstudio").exists(),
        ]),
        "codex": any([
            (home_dir / ".codex").exists(),
            shutil.which("codex") is not None,
        ]),
        "continue": (home_dir / ".continue").exists(),
    }


def get_mac_client_targets(
    repo_name: str,
    home: pathlib.Path | None = None,
    for_uninstall: bool = False,
) -> dict[str, list[tuple[pathlib.Path, str, bool]]]:
    """Return client -> list of (config_path, root_key, is_vscode_stdio)."""
    home_dir = home if home is not None else pathlib.Path.home()
    app_support = home_dir / "Library" / "Application Support"

    claude_targets: list[tuple[pathlib.Path, str, bool]] = [
        (app_support / "Claude" / "claude_desktop_config.json", "mcpServers", False),
    ]
    if for_uninstall or (home_dir / ".claude.json").exists() or (home_dir / ".claude").exists() or shutil.which("claude"):
        claude_targets.append((home_dir / ".claude.json", "mcpServers", False))

    vscode_targets: list[tuple[pathlib.Path, str, bool]] = [
        (app_support / "Code" / "User" / "mcp.json", "servers", True),
    ]
    cline_dir = app_support / "Code" / "User" / "globalStorage" / "saoudrizwan.claude-dev"
    if for_uninstall or cline_dir.exists():
        vscode_targets.append((cline_dir / "settings" / "cline_mcp_settings.json", "mcpServers", False))
    roo_dir = app_support / "Code" / "User" / "globalStorage" / "rooveterinaryinc.roo-cline"
    if for_uninstall or roo_dir.exists():
        vscode_targets.append((roo_dir / "settings" / "mcp_settings.json", "mcpServers", False))

    ag_targets: list[tuple[pathlib.Path, str, bool]] = [
        (home_dir / ".gemini" / "antigravity" / "mcp_config.json", "mcpServers", False),
    ]
    if for_uninstall or (home_dir / ".gemini" / "config").exists():
        ag_targets.append((home_dir / ".gemini" / "config" / "mcp_config.json", "mcpServers", False))
    if for_uninstall or (home_dir / ".gemini" / "settings.json").exists() or shutil.which("gemini"):
        ag_targets.append((home_dir / ".gemini" / "settings.json", "mcpServers", False))

    return {
        "claude": claude_targets,
        "cursor": [(home_dir / ".cursor" / "mcp.json", "mcpServers", False)],
        "vscode": vscode_targets,
        "windsurf": [(home_dir / ".codeium" / "windsurf" / "mcp_config.json", "mcpServers", False)],
        "antigravity": ag_targets,
        "lmstudio": [(home_dir / ".lmstudio" / "mcp.json", "mcpServers", False)],
        "continue": [(home_dir / ".continue" / "mcpServers" / f"{repo_name}.json", "mcpServers", False)],
    }


def resolve_uv_binary(home: pathlib.Path | None = None) -> str | None:
    found = shutil.which("uv")
    if found:
        return found
    home_dir = home if home is not None else pathlib.Path.home()
    for candidate in (
        home_dir / ".local" / "bin" / "uv",
        home_dir / ".cargo" / "bin" / "uv",
        pathlib.Path("/opt/homebrew/bin/uv"),
        pathlib.Path("/usr/local/bin/uv"),
    ):
        if candidate.exists():
            return str(candidate)
    return None


def upsert_json_mcp_file(
    cfg_path: pathlib.Path,
    repo_name: str,
    py_path: str,
    script_path: str,
    root_key: str = "mcpServers",
    is_vscode_stdio: bool = False,
    dry_run: bool = False,
) -> None:
    data = load_json_strict(cfg_path)
    if not isinstance(data.get(root_key), dict):
        data[root_key] = {}
    section = data[root_key]
    assert isinstance(section, dict)
    entry: dict[str, object] = {
        "command": py_path,
        "args": [script_path],
        "env": {"PYTHONIOENCODING": "utf-8"},
    }
    if is_vscode_stdio:
        entry = {"type": "stdio", **entry}
    section[repo_name] = entry

    if not dry_run:
        if cfg_path.exists():
            create_timestamped_backup(cfg_path)
        atomic_write_text(cfg_path, json.dumps(data, indent=2) + "\n")


def remove_json_mcp_file(
    cfg_path: pathlib.Path,
    repo_name: str,
    root_key: str = "mcpServers",
    dry_run: bool = False,
) -> bool:
    if not cfg_path.exists() or cfg_path.stat().st_size == 0:
        return False
    data = load_json_strict(cfg_path)
    changed = False
    for rk in dict.fromkeys([root_key, "mcpServers", "servers"]):
        section = data.get(rk)
        if isinstance(section, dict) and repo_name in section:
            del section[repo_name]
            changed = True
    if not changed:
        return False
    if not dry_run:
        create_timestamped_backup(cfg_path)
        if cfg_path.parent.name == "mcpServers" and cfg_path.name == f"{repo_name}.json" and not data.get("mcpServers"):
            cfg_path.unlink()
        else:
            atomic_write_text(cfg_path, json.dumps(data, indent=2) + "\n")
    return True


def upsert_codex_toml(
    codex_toml: pathlib.Path,
    repo_name: str,
    py_path: str,
    script_path: str,
    dry_run: bool = False,
) -> None:
    existing = codex_toml.read_text(encoding="utf-8-sig") if codex_toml.exists() else ""
    esc_py = py_path.replace("\\", "\\\\").replace('"', '\\"')
    esc_sc = script_path.replace("\\", "\\\\").replace('"', '\\"')
    block = (
        f"[mcp_servers.{repo_name}]\n"
        f'command = "{esc_py}"\n'
        f'args = ["{esc_sc}"]\n'
        f'env = {{ PYTHONIOENCODING = "utf-8" }}\n'
    )
    sub_pattern = rf"(?ms)^\[mcp_servers\.{re.escape(repo_name)}\.[^\]]+\].*?(?=^\[|\Z)"
    cleaned = re.sub(sub_pattern, "", existing)
    pattern = rf"(?ms)^\[mcp_servers\.{re.escape(repo_name)}\].*?(?=^\[|\Z)"
    if re.search(pattern, cleaned):
        updated = re.sub(pattern, lambda _m: block + "\n", cleaned)
    else:
        updated = (cleaned.rstrip() + "\n\n" + block) if cleaned.strip() else block

    if not dry_run:
        if codex_toml.exists():
            create_timestamped_backup(codex_toml)
        atomic_write_text(codex_toml, updated.rstrip() + "\n")


def remove_codex_toml(
    codex_toml: pathlib.Path,
    repo_name: str,
    dry_run: bool = False,
) -> bool:
    if not codex_toml.exists():
        return False
    existing = codex_toml.read_text(encoding="utf-8-sig")
    pattern = rf"(?ms)^\[mcp_servers\.{re.escape(repo_name)}(?:\.[^\]]+)?\].*?(?=^\[|\Z)"
    if not re.search(pattern, existing):
        return False
    updated = re.sub(pattern, "", existing).strip()
    if not dry_run:
        create_timestamped_backup(codex_toml)
        atomic_write_text(codex_toml, (updated + "\n") if updated else "")
    return True


def register_clients(
    selected_keys: list[str],
    install_dir: pathlib.Path,
    repo_name: str = REPO_NAME,
    home: pathlib.Path | None = None,
    dry_run: bool = False,
) -> list[str]:
    home_dir = home if home is not None else pathlib.Path.home()
    venv_py = str(install_dir / ".venv" / "bin" / "python")
    main_py = str(install_dir / "mcp_server_main.py")
    targets = get_mac_client_targets(repo_name, home=home_dir, for_uninstall=False)
    written: list[str] = []

    for key in selected_keys:
        if key == "codex":
            codex_toml = home_dir / ".codex" / "config.toml"
            upsert_codex_toml(codex_toml, repo_name, venv_py, main_py, dry_run=dry_run)
            written.append(str(codex_toml))
            continue
        for cfg_path, root_key, is_vs in targets.get(key, []):
            upsert_json_mcp_file(
                cfg_path,
                repo_name,
                venv_py,
                main_py,
                root_key=root_key,
                is_vscode_stdio=is_vs,
                dry_run=dry_run,
            )
            written.append(str(cfg_path))
    return written


def run_uninstall(
    repo_name: str = REPO_NAME,
    home: pathlib.Path | None = None,
    dry_run: bool = False,
    progress_cb: Callable[[int, str], None] | None = None,
) -> tuple[list[str], bool]:
    home_dir = home if home is not None else pathlib.Path.home()

    def report(pct: int, msg: str) -> None:
        if progress_cb:
            progress_cb(pct, msg)

    report(30, f"Step 1/2: Removing {repo_name} entries from AI client configurations...")
    targets = get_mac_client_targets(repo_name, home=home_dir, for_uninstall=True)
    cleaned: list[str] = []
    for entries in targets.values():
        for cfg_path, root_key, _is_vs in entries:
            if remove_json_mcp_file(cfg_path, repo_name, root_key=root_key, dry_run=dry_run):
                cleaned.append(str(cfg_path))
    codex_toml = home_dir / ".codex" / "config.toml"
    if remove_codex_toml(codex_toml, repo_name, dry_run=dry_run):
        cleaned.append(str(codex_toml))

    report(75, "Step 2/2: Removing persistent installation directory...")
    install_dir = get_persistent_install_dir(repo_name, home=home_dir)
    removed_dir = False
    if install_dir.exists():
        removed_dir = True
        if not dry_run:
            shutil.rmtree(install_dir)

    report(100, "Uninstall complete.")
    return cleaned, removed_dir


def run_installation(
    selected_keys: list[str],
    script_dir: pathlib.Path,
    repo_name: str = REPO_NAME,
    home: pathlib.Path | None = None,
    dry_run: bool = False,
    progress_cb: Callable[[int, str], None] | None = None,
) -> tuple[list[str], pathlib.Path]:
    if not selected_keys:
        raise ValueError("Please select at least one AI application.")

    def report(pct: int, text: str) -> None:
        if progress_cb:
            progress_cb(pct, text)

    install_dir = get_persistent_install_dir(repo_name, home=home)

    report(15, "Step 1/5: Checking Python runtime manager (uv)...")
    uv_bin = resolve_uv_binary(home=home)
    if not uv_bin and not dry_run:
        subprocess.run(
            ["bash", "-c", "curl -LsSf https://astral.sh/uv/install.sh | sh"],
            check=True,
        )
        uv_bin = resolve_uv_binary(home=home)
    if not uv_bin and not dry_run:
        raise RuntimeError("Could not locate or install 'uv'.")

    report(35, f"Step 2/5: Copying server files to {install_dir}...")
    for req_file in ("mcp_server_main.py", "pyproject.toml"):
        if not (script_dir / req_file).exists():
            raise RuntimeError(
                f"Missing required file '{req_file}' in {script_dir}. "
                "Please extract the complete ZIP archive before running."
            )
    if not dry_run:
        install_dir.mkdir(parents=True, exist_ok=True)
        for copy_file in ("mcp_server_main.py", "pyproject.toml", "SKILL.md", "LICENSE"):
            src = script_dir / copy_file
            if src.exists():
                shutil.copy2(src, install_dir / copy_file)

    report(55, "Step 3/5: Preparing isolated Python 3.12 runtime...")
    if not dry_run and uv_bin:
        find_res = subprocess.run(
            [uv_bin, "python", "find", "--managed-python", "3.12"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        if find_res.returncode != 0:
            subprocess.run([uv_bin, "python", "install", "3.12"], check=True)

    report(75, "Step 4/5: Installing legal database & archive connectors...")
    if not dry_run and uv_bin:
        sync_res = subprocess.run(
            [uv_bin, "sync", "--python", "3.12"],
            cwd=str(install_dir),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        if sync_res.returncode != 0:
            err = (sync_res.stderr or sync_res.stdout or "uv sync failed").strip()
            raise RuntimeError(err)

    report(90, "Step 5/5: Registering MCP server in selected AI applications...")
    written = register_clients(
        selected_keys,
        install_dir=install_dir,
        repo_name=repo_name,
        home=home,
        dry_run=dry_run,
    )
    report(100, "Setup Complete! Connected to your selected AI applications.")
    return written, install_dir


def run_gui(script_dir: pathlib.Path, dry_run: bool = False) -> None:
    import tkinter as tk
    from tkinter import messagebox, ttk

    root = tk.Tk()
    root.title(f"JurisAtlas - {COUNTRY_NAME} Legal MCP Setup")
    root.geometry("640x540")
    root.minsize(615, 510)
    root.resizable(True, True)

    container = ttk.Frame(root, padding=(20, 16, 20, 16))
    container.pack(fill="both", expand=True)

    ttk.Label(
        container,
        text=f"JurisAtlas: {COUNTRY_NAME} Legal MCP Setup",
        font=("SF Pro Text", 15, "bold"),
    ).pack(anchor="w", pady=(0, 8))

    install_preview = get_persistent_install_dir(REPO_NAME)
    info_box = tk.Frame(
        container,
        bg="#e0f2fe",
        highlightbackground="#7dd3fc",
        highlightthickness=1,
        padx=12,
        pady=10,
    )
    info_box.pack(fill="x", pady=(0, 12))
    tk.Label(
        info_box,
        text=(
            f"Read-Only & Persistent Installation ({install_preview})\n"
            "• Does NOT access or modify your personal files or documents.\n"
            "• Creates timestamped config backups before editing; you may safely delete the Downloads ZIP after setup."
        ),
        bg="#e0f2fe",
        fg="#0f172a",
        justify="left",
        anchor="w",
        wraplength=560,
        font=("SF Pro Text", 10),
    ).pack(fill="x")

    group = ttk.LabelFrame(container, text="Select the AI Application(s) You Use:", padding=(12, 10))
    group.pack(fill="x", pady=(0, 10))
    group.columnconfigure(0, weight=1)
    group.columnconfigure(1, weight=1)

    client_vars: dict[str, tk.BooleanVar] = {}
    client_widgets: dict[str, ttk.Checkbutton] = {}
    for idx, (key, label) in enumerate(CLIENT_SPECS):
        var = tk.BooleanVar(value=False)
        client_vars[key] = var
        cb = ttk.Checkbutton(group, text=label, variable=var)
        cb.grid(row=idx // 2, column=idx % 2, sticky="w", padx=6, pady=5)
        client_widgets[key] = cb

    ttk.Label(
        group,
        text="Note: ChatGPT Desktop / Web & Claude Web connect via Remote HTTPS MCP (--transport streamable-http).",
        font=("SF Pro Text", 9),
        foreground="#475569",
        wraplength=550,
    ).grid(row=(len(CLIENT_SPECS) + 1) // 2, column=0, columnspan=2, sticky="w", padx=6, pady=(6, 0))

    status_var = tk.StringVar(value="Ready.")
    ttk.Label(container, textvariable=status_var, font=("SF Pro Text", 10), wraplength=580).pack(anchor="w", pady=(2, 4))

    progress = ttk.Progressbar(container, orient="horizontal", mode="determinate", maximum=100, value=0)
    progress.pack(fill="x", pady=(0, 12))

    top_btn_row = ttk.Frame(container)
    top_btn_row.pack(fill="x", pady=(0, 8))
    detect_btn = ttk.Button(top_btn_row, text="Auto-Detect Installed Apps")
    detect_btn.pack(side="left")
    uninstall_btn = ttk.Button(top_btn_row, text="Uninstall / Remove")
    uninstall_btn.pack(side="right")

    btn_row = ttk.Frame(container)
    btn_row.pack(fill="x")
    install_btn = ttk.Button(btn_row, text="Install to Selected AI Clients", default="active")
    install_btn.pack(side="left", fill="x", expand=True, padx=(0, 8))
    close_btn = ttk.Button(btn_row, text="Close", command=lambda: root.destroy())
    close_btn.pack(side="right")

    def apply_auto_detect() -> None:
        detected = detect_installed_mac_clients()
        found_count = 0
        for key, base_label in CLIENT_SPECS:
            is_found = detected.get(key, False)
            client_vars[key].set(is_found)
            if is_found:
                client_widgets[key].configure(text=f"{base_label} (Detected)")
                found_count += 1
            else:
                client_widgets[key].configure(text=base_label)
        if found_count > 0:
            status_var.set(f"Auto-detected {found_count} installed AI app(s). Review selections and click Install.")
        else:
            status_var.set("No AI apps auto-detected. Select your AI client(s) above and click Install.")

    detect_btn.configure(command=apply_auto_detect)
    apply_auto_detect()

    def show_completion_dialog(summary_text: str, install_path: pathlib.Path) -> None:
        dlg = tk.Toplevel(root)
        dlg.title("JurisAtlas - Setup Complete")
        dlg.geometry("560x350")
        dlg.transient(root)
        dlg.grab_set()

        frame = ttk.Frame(dlg, padding=(18, 14, 18, 14))
        frame.pack(fill="both", expand=True)

        ttk.Label(
            frame,
            text=f"{COUNTRY_NAME} Legal MCP Server Installed",
            font=("SF Pro Text", 13, "bold"),
        ).pack(anchor="w", pady=(0, 6))

        dry_note = " (DRY RUN - no files written)" if dry_run else ""
        ttk.Label(
            frame,
            text=(
                f"{summary_text}{dry_note}\n"
                f"Persistent location: {install_path}\n"
                "Please restart your selected AI application(s) to load the legal research tools."
            ),
            wraplength=510,
            justify="left",
        ).pack(anchor="w", pady=(0, 10))

        ttk.Label(
            frame,
            text="Copy-Paste Starter Prompt:",
            font=("SF Pro Text", 10, "bold"),
        ).pack(anchor="w", pady=(0, 4))

        txt = tk.Text(frame, height=5, wrap="word", font=("SF Pro Text", 10))
        txt.insert("1.0", STARTER_PROMPT)
        txt.configure(state="disabled")
        txt.pack(fill="both", expand=True, pady=(0, 10))

        act_row = ttk.Frame(frame)
        act_row.pack(fill="x")

        def copy_prompt() -> None:
            dlg.clipboard_clear()
            dlg.clipboard_append(STARTER_PROMPT)
            copy_btn.configure(text="Copied to Clipboard!")

        copy_btn = ttk.Button(act_row, text="Copy Starter Prompt", command=copy_prompt)
        copy_btn.pack(side="left")
        ttk.Button(act_row, text="Done", command=dlg.destroy).pack(side="right")

    def set_busy(busy: bool, mode: str = "install") -> None:
        state = "disabled" if busy else "normal"
        install_btn.configure(
            state=state,
            text=("Installing... Please wait" if (busy and mode == "install") else "Install to Selected AI Clients"),
        )
        uninstall_btn.configure(state=state)
        detect_btn.configure(state=state)
        close_btn.configure(state=state)

    def start_worker(mode: str, chosen: list[str]) -> None:
        set_busy(True, mode=mode)
        progress.configure(value=5)
        events: queue.Queue[tuple[str, object]] = queue.Queue()

        def on_progress(pct: int, msg: str) -> None:
            events.put(("progress", (pct, msg)))

        def worker() -> None:
            try:
                if mode == "uninstall":
                    cleaned, removed_dir = run_uninstall(
                        repo_name=REPO_NAME,
                        dry_run=dry_run,
                        progress_cb=on_progress,
                    )
                    events.put(("done_uninstall", (cleaned, removed_dir)))
                else:
                    written, install_path = run_installation(
                        chosen,
                        script_dir=script_dir,
                        repo_name=REPO_NAME,
                        dry_run=dry_run,
                        progress_cb=on_progress,
                    )
                    events.put(("done_install", (written, install_path)))
            except Exception as exc:
                events.put(("error", str(exc)))

        def poll_events() -> None:
            try:
                while True:
                    kind, payload = events.get_nowait()
                    if kind == "progress":
                        pct, msg = payload  # type: ignore[misc]
                        progress.configure(value=pct)
                        status_var.set(str(msg))
                    elif kind == "done_install":
                        written, install_path = payload  # type: ignore[misc]
                        set_busy(False)
                        show_completion_dialog(
                            f"Connected {REPO_NAME} across {len(written)} AI configuration file(s).",
                            install_path,
                        )
                        return
                    elif kind == "done_uninstall":
                        cleaned, removed_dir = payload  # type: ignore[misc]
                        set_busy(False)
                        dir_msg = f" Deleted {get_persistent_install_dir(REPO_NAME)}." if removed_dir else ""
                        messagebox.showinfo(
                            "JurisAtlas - Uninstall Complete",
                            f"Removed {REPO_NAME} from {len(cleaned)} AI configuration file(s) (timestamped backups kept).{dir_msg}",
                            parent=root,
                        )
                        return
                    elif kind == "error":
                        set_busy(False)
                        install_btn.configure(text="Retry Installation")
                        status_var.set("Operation failed. See details.")
                        messagebox.showerror(
                            "Setup Error",
                            f"An error occurred:\n{payload}",
                            parent=root,
                        )
                        return
            except queue.Empty:
                pass
            if root.winfo_exists():
                root.after(50, poll_events)

        threading.Thread(target=worker, daemon=True).start()
        root.after(50, poll_events)

    def on_install() -> None:
        chosen = [key for key, _ in CLIENT_SPECS if client_vars[key].get()]
        if not chosen:
            messagebox.showwarning(
                "No Client Selected",
                "Please select at least one AI application.",
                parent=root,
            )
            return
        start_worker("install", chosen)

    def on_uninstall() -> None:
        confirmed = messagebox.askyesno(
            "JurisAtlas - Confirm Uninstall",
            f"Remove {REPO_NAME} from all AI client configurations and delete {get_persistent_install_dir(REPO_NAME)}?\n\n"
            "(Timestamped config backups are kept; unrelated MCP servers are never modified.)",
            parent=root,
        )
        if confirmed:
            start_worker("uninstall", [])

    install_btn.configure(command=on_install)
    uninstall_btn.configure(command=on_uninstall)

    root.update_idletasks()
    w, h = root.winfo_width(), root.winfo_height()
    x = max(0, (root.winfo_screenwidth() - w) // 2)
    y = max(0, (root.winfo_screenheight() - h) // 2)
    root.geometry(f"{w}x{h}+{x}+{y}")

    # Pure Tk focus without macOS TCC privacy prompts
    root.lift()
    root.attributes("-topmost", True)
    topmost_id = root.after(250, lambda: root.winfo_exists() and root.attributes("-topmost", False))
    root.focus_force()

    orig_destroy = root.destroy

    def clean_destroy() -> None:
        try:
            root.after_cancel(topmost_id)
        except Exception:
            pass
        orig_destroy()

    root.destroy = clean_destroy  # type: ignore[method-assign]
    root.mainloop()


def run_cli(script_dir: pathlib.Path, dry_run: bool = False, uninstall: bool = False) -> None:
    if uninstall:
        cleaned, removed_dir = run_uninstall(
            repo_name=REPO_NAME,
            dry_run=dry_run,
            progress_cb=lambda pct, msg: print(f"[{pct}%] {msg}"),
        )
        print(f"Removed {REPO_NAME} from {len(cleaned)} config file(s). Removed dir: {removed_dir}.")
        return

    print(f"\nJurisAtlas: {COUNTRY_NAME} Legal MCP Setup ({REPO_NAME})")
    detected = detect_installed_mac_clients()
    print("Available AI Applications:")
    for idx, (key, label) in enumerate(CLIENT_SPECS, start=1):
        tag = " [Detected]" if detected.get(key) else ""
        print(f"  [{idx}] {label}{tag}")
    print("  [A] All of the above")
    while True:
        raw = input("\nSelect AI application(s) (e.g. 1,2,3 or A for all): ").strip().lower()
        if raw in {"a", "all", "*"}:
            chosen = [key for key, _ in CLIENT_SPECS]
            break
        tokens = [t.strip() for t in raw.replace(";", ",").split(",") if t.strip()]
        chosen = list(
            dict.fromkeys(
                CLIENT_SPECS[int(t) - 1][0]
                for t in tokens
                if t.isdigit() and 1 <= int(t) <= len(CLIENT_SPECS)
            )
        )
        if chosen:
            break
        print(f"Please select at least one AI application (1-{len(CLIENT_SPECS)} or A for all).")

    written, install_path = run_installation(
        chosen,
        script_dir=script_dir,
        repo_name=REPO_NAME,
        dry_run=dry_run,
        progress_cb=lambda pct, msg: print(f"[{pct}%] {msg}"),
    )
    print(f"\nSetup Complete! Updated {len(written)} config file(s). Installed in {install_path}.")
    print(f"Try this starter prompt after restarting your AI app:\n  {STARTER_PROMPT}")


def main() -> None:
    parser = argparse.ArgumentParser(description=f"JurisAtlas {COUNTRY_NAME} macOS Installer")
    parser.add_argument("--cli", action="store_true", help="Use terminal fallback instead of GUI")
    parser.add_argument("--dry-run", action="store_true", help="Preview installation without writing files")
    parser.add_argument("--uninstall", action="store_true", help="Remove MCP server config entries and install directory")
    args = parser.parse_args()

    script_dir = pathlib.Path(__file__).resolve().parent
    if args.uninstall:
        run_cli(script_dir=script_dir, dry_run=args.dry_run, uninstall=True)
        return

    if not args.cli and not (os.environ.get("SSH_TTY") or os.environ.get("SSH_CONNECTION")):
        try:
            run_gui(script_dir=script_dir, dry_run=args.dry_run)
            return
        except Exception as exc:
            print(f"GUI unavailable ({exc}); switching to terminal mode.")

    run_cli(script_dir=script_dir, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
