# JurisAtlas Interactive AI Client Selector & Setup Wizard (Windows Forms GUI)
# Saved with UTF-8 BOM for clean Windows PowerShell 5.1 rendering.
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoName = "dk-legal-mcp"
$CountryName = "Denmark"
$CitationExample = "UfR 2024.123 H or LBK nr 100"
$InstallRoot = Join-Path $env:LOCALAPPDATA "JurisAtlas"
$InstallDir = Join-Path $InstallRoot $RepoName
$LogDir = Join-Path $InstallRoot "logs"
$LogFile = Join-Path $LogDir "$RepoName-installer.log"
$StarterPrompt = "Verify $CitationExample in official $CountryName legal registries, confirm whether it is a VERIFIED_OFFICIAL_RECORD or UNCONFIRMED_WEB_MATCH, and summarize the controlling rule with official links."

$ConfigPyScript = @'
import datetime
import json
import os
import pathlib
import re
import shutil
import sys
import tempfile


def strip_jsonc(raw: str) -> str:
    out = []
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
    res = []
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


def load_json_strict(path: pathlib.Path) -> dict:
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
            "Please fix or rename that file first."
        ) from exc
    if not isinstance(loaded, dict):
        raise RuntimeError(
            f"Refusing to overwrite unexpected non-object JSON in '{path}'."
        )
    return loaded


def find_claude_msix_configs(local_appdata: pathlib.Path) -> list[pathlib.Path]:
    found = []
    packages = local_appdata / "Packages"
    if packages.is_dir():
        for pkg in sorted(packages.glob("Claude_*")):
            if pkg.is_dir():
                found.append(pkg / "LocalCache" / "Roaming" / "Claude" / "claude_desktop_config.json")
    return found


def build_win_targets(repo: str, for_uninstall: bool = False) -> dict[str, list[tuple[pathlib.Path, str, bool]]]:
    """Return client -> list of (path, root_key, is_vscode_stdio)."""
    home = pathlib.Path.home()
    appdata = pathlib.Path(os.environ.get("APPDATA", str(home / "AppData" / "Roaming")))
    local_appdata = pathlib.Path(os.environ.get("LOCALAPPDATA", str(home / "AppData" / "Local")))

    claude_targets: list[tuple[pathlib.Path, str, bool]] = []
    msix_cfgs = find_claude_msix_configs(local_appdata)
    for mcfg in msix_cfgs:
        claude_targets.append((mcfg, "mcpServers", False))
    std_claude = appdata / "Claude" / "claude_desktop_config.json"
    if for_uninstall or std_claude.parent.exists() or not msix_cfgs:
        claude_targets.append((std_claude, "mcpServers", False))
    claude_code_cfg = home / ".claude.json"
    if for_uninstall or claude_code_cfg.exists() or (home / ".claude").exists() or shutil.which("claude"):
        claude_targets.append((claude_code_cfg, "mcpServers", False))

    vscode_targets: list[tuple[pathlib.Path, str, bool]] = [
        (appdata / "Code" / "User" / "mcp.json", "servers", True),
    ]
    cline_dir = appdata / "Code" / "User" / "globalStorage" / "saoudrizwan.claude-dev"
    if for_uninstall or cline_dir.exists():
        vscode_targets.append((cline_dir / "settings" / "cline_mcp_settings.json", "mcpServers", False))
    roo_dir = appdata / "Code" / "User" / "globalStorage" / "rooveterinaryinc.roo-cline"
    if for_uninstall or roo_dir.exists():
        vscode_targets.append((roo_dir / "settings" / "mcp_settings.json", "mcpServers", False))

    ag_targets: list[tuple[pathlib.Path, str, bool]] = [
        (home / ".gemini" / "antigravity" / "mcp_config.json", "mcpServers", False),
    ]
    if for_uninstall or (home / ".gemini" / "config").exists():
        ag_targets.append((home / ".gemini" / "config" / "mcp_config.json", "mcpServers", False))
    if for_uninstall or (home / ".gemini" / "settings.json").exists() or shutil.which("gemini"):
        ag_targets.append((home / ".gemini" / "settings.json", "mcpServers", False))

    return {
        "claude": claude_targets,
        "cursor": [(home / ".cursor" / "mcp.json", "mcpServers", False)],
        "vscode": vscode_targets,
        "windsurf": [(home / ".codeium" / "windsurf" / "mcp_config.json", "mcpServers", False)],
        "antigravity": ag_targets,
        "lmstudio": [(home / ".lmstudio" / "mcp.json", "mcpServers", False)],
        "continue": [(home / ".continue" / "mcpServers" / f"{repo}.json", "mcpServers", False)],
    }


def upsert_json_server(cfg_path: pathlib.Path, root_key: str, is_vscode_stdio: bool, repo: str, py_path: str, script_path: str) -> None:
    data = load_json_strict(cfg_path)
    if not isinstance(data.get(root_key), dict):
        data[root_key] = {}
    entry = {
        "command": py_path,
        "args": [script_path],
        "env": {"PYTHONIOENCODING": "utf-8"},
    }
    if is_vscode_stdio:
        entry = {"type": "stdio", **entry}
    data[root_key][repo] = entry
    if cfg_path.exists():
        create_timestamped_backup(cfg_path)
    atomic_write_text(cfg_path, json.dumps(data, indent=2) + "\n")


def remove_json_server(cfg_path: pathlib.Path, root_key: str, repo: str) -> bool:
    if not cfg_path.exists() or cfg_path.stat().st_size == 0:
        return False
    data = load_json_strict(cfg_path)
    changed = False
    for rk in dict.fromkeys([root_key, "mcpServers", "servers"]):
        section = data.get(rk)
        if isinstance(section, dict) and repo in section:
            del section[repo]
            changed = True
    if not changed:
        return False
    create_timestamped_backup(cfg_path)
    if cfg_path.parent.name == "mcpServers" and cfg_path.name == f"{repo}.json" and not data.get("mcpServers"):
        cfg_path.unlink()
    else:
        atomic_write_text(cfg_path, json.dumps(data, indent=2) + "\n")
    return True


def upsert_codex_toml(codex_toml: pathlib.Path, repo: str, py_path: str, script_path: str) -> None:
    existing = codex_toml.read_text(encoding="utf-8-sig") if codex_toml.exists() else ""
    esc_py = py_path.replace("\\", "\\\\").replace('"', '\\"')
    esc_sc = script_path.replace("\\", "\\\\").replace('"', '\\"')
    block = (
        f"[mcp_servers.{repo}]\n"
        f'command = "{esc_py}"\n'
        f'args = ["{esc_sc}"]\n'
        f'env = {{ PYTHONIOENCODING = "utf-8" }}\n'
    )
    sub_pattern = rf"(?ms)^\[mcp_servers\.{re.escape(repo)}\.[^\]]+\].*?(?=^\[|\Z)"
    cleaned = re.sub(sub_pattern, "", existing)
    pattern = rf"(?ms)^\[mcp_servers\.{re.escape(repo)}\].*?(?=^\[|\Z)"
    if re.search(pattern, cleaned):
        updated = re.sub(pattern, lambda _m: block + "\n", cleaned)
    else:
        updated = (cleaned.rstrip() + "\n\n" + block) if cleaned.strip() else block
    if codex_toml.exists():
        create_timestamped_backup(codex_toml)
    atomic_write_text(codex_toml, updated.rstrip() + "\n")


def remove_codex_toml(codex_toml: pathlib.Path, repo: str) -> bool:
    if not codex_toml.exists():
        return False
    existing = codex_toml.read_text(encoding="utf-8-sig")
    pattern = rf"(?ms)^\[mcp_servers\.{re.escape(repo)}(?:\.[^\]]+)?\].*?(?=^\[|\Z)"
    if not re.search(pattern, existing):
        return False
    updated = re.sub(pattern, "", existing).strip()
    create_timestamped_backup(codex_toml)
    atomic_write_text(codex_toml, (updated + "\n") if updated else "")
    return True


def main() -> None:
    action = os.environ.get("JURISATLAS_ACTION", "install").strip().lower()
    repo = os.environ["JURISATLAS_REPO"].strip()
    py_path = os.environ.get("JURISATLAS_PY", "").strip()
    script_path = os.environ.get("JURISATLAS_SCRIPT", "").strip()
    clients = [c.strip() for c in os.environ.get("JURISATLAS_CLIENTS", "").split(",") if c.strip()]
    codex_toml = pathlib.Path.home() / ".codex" / "config.toml"

    touched = []
    if action == "uninstall":
        targets = build_win_targets(repo, for_uninstall=True)
        for entries in targets.values():
            for cfg_path, root_key, _is_vs in entries:
                if remove_json_server(cfg_path, root_key, repo):
                    touched.append(str(cfg_path))
        if remove_codex_toml(codex_toml, repo):
            touched.append(str(codex_toml))
        print(json.dumps({"action": "uninstall", "updated": touched}))
    else:
        targets = build_win_targets(repo, for_uninstall=False)
        for key in clients:
            if key == "codex":
                upsert_codex_toml(codex_toml, repo, py_path, script_path)
                touched.append(str(codex_toml))
                continue
            for cfg_path, root_key, is_vs in targets.get(key, []):
                upsert_json_server(cfg_path, root_key, is_vs, repo, py_path, script_path)
                touched.append(str(cfg_path))
        print(json.dumps({"action": "install", "updated": touched}))


if __name__ == "__main__":
    main()

'@

function Get-DetectedClients {
    $detected = @{}
    $msixClaude = @()
    $pkgDir = Join-Path $env:LOCALAPPDATA "Packages"
    if (Test-Path $pkgDir) {
        $msixClaude = @(Get-ChildItem -Path $pkgDir -Filter "Claude_*" -Directory -ErrorAction SilentlyContinue)
    }
    $detected["claude"] = (
        (Test-Path (Join-Path $env:APPDATA "Claude")) -or
        (Test-Path (Join-Path $env:LOCALAPPDATA "AnthropicClaude")) -or
        ($msixClaude.Count -gt 0) -or
        (Test-Path (Join-Path $env:USERPROFILE ".claude")) -or
        (Test-Path (Join-Path $env:USERPROFILE ".claude.json")) -or
        ($null -ne (Get-Command claude -ErrorAction SilentlyContinue))
    )
    $detected["cursor"] = (
        (Test-Path (Join-Path $env:USERPROFILE ".cursor")) -or
        (Test-Path (Join-Path $env:LOCALAPPDATA "Programs\cursor")) -or
        (Test-Path (Join-Path $env:APPDATA "Cursor"))
    )
    $detected["vscode"] = (
        (Test-Path (Join-Path $env:APPDATA "Code")) -or
        (Test-Path (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code")) -or
        ($null -ne (Get-Command code -ErrorAction SilentlyContinue))
    )
    $detected["windsurf"] = (
        (Test-Path (Join-Path $env:USERPROFILE ".codeium\windsurf")) -or
        (Test-Path (Join-Path $env:APPDATA "Windsurf")) -or
        (Test-Path (Join-Path $env:LOCALAPPDATA "Programs\Windsurf"))
    )
    $detected["antigravity"] = (
        (Test-Path (Join-Path $env:USERPROFILE ".gemini\antigravity")) -or
        (Test-Path (Join-Path $env:USERPROFILE ".gemini\settings.json")) -or
        ($null -ne (Get-Command gemini -ErrorAction SilentlyContinue))
    )
    $detected["lmstudio"] = (
        (Test-Path (Join-Path $env:USERPROFILE ".lmstudio")) -or
        (Test-Path (Join-Path $env:LOCALAPPDATA "LM-Studio")) -or
        (Test-Path (Join-Path $env:LOCALAPPDATA "Programs\LM Studio"))
    )
    $detected["codex"] = (
        (Test-Path (Join-Path $env:USERPROFILE ".codex")) -or
        ($null -ne (Get-Command codex -ErrorAction SilentlyContinue))
    )
    $detected["continue"] = (Test-Path (Join-Path $env:USERPROFILE ".continue"))
    return $detected
}

function Show-CompletionDialog {
    param([string]$SummaryText, [string]$PromptText, [string]$PersistentPath)
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "JurisAtlas - Setup Complete"
    $dlg.Size = New-Object System.Drawing.Size(600, 405)
    $dlg.StartPosition = "CenterParent"
    $dlg.FormBorderStyle = "FixedDialog"
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)

    $hdr = New-Object System.Windows.Forms.Label
    $hdr.Text = "$CountryName Legal MCP Server Installed Successfully"
    $hdr.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $hdr.ForeColor = [System.Drawing.Color]::FromArgb(21, 128, 61)
    $hdr.Location = New-Object System.Drawing.Point(20, 16)
    $hdr.Size = New-Object System.Drawing.Size(545, 26)
    $dlg.Controls.Add($hdr)

    $info = New-Object System.Windows.Forms.Label
    $info.Text = "$SummaryText`r`nInstalled persistently in: $PersistentPath`r`nYou may safely delete the Downloads ZIP folder. Please restart your AI application(s)."
    $info.Font = New-Object System.Drawing.Font("Segoe UI", 9.0)
    $info.ForeColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
    $info.Location = New-Object System.Drawing.Point(20, 48)
    $info.Size = New-Object System.Drawing.Size(545, 76)
    $dlg.Controls.Add($info)

    $pLbl = New-Object System.Windows.Forms.Label
    $pLbl.Text = "Copy-Paste Starter Prompt (try this right after restarting your AI app):"
    $pLbl.Font = New-Object System.Drawing.Font("Segoe UI", 9.2, [System.Drawing.FontStyle]::Bold)
    $pLbl.ForeColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
    $pLbl.Location = New-Object System.Drawing.Point(20, 132)
    $pLbl.Size = New-Object System.Drawing.Size(545, 22)
    $dlg.Controls.Add($pLbl)

    $pBox = New-Object System.Windows.Forms.TextBox
    $pBox.Multiline = $true
    $pBox.ReadOnly = $true
    $pBox.ScrollBars = "Vertical"
    $pBox.Text = $PromptText
    $pBox.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
    $pBox.BackColor = [System.Drawing.Color]::White
    $pBox.Location = New-Object System.Drawing.Point(20, 158)
    $pBox.Size = New-Object System.Drawing.Size(545, 130)
    $dlg.Controls.Add($pBox)

    $copyBtn = New-Object System.Windows.Forms.Button
    $copyBtn.Text = "Copy Starter Prompt"
    $copyBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
    $copyBtn.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
    $copyBtn.ForeColor = [System.Drawing.Color]::White
    $copyBtn.FlatStyle = "Flat"
    $copyBtn.Location = New-Object System.Drawing.Point(20, 304)
    $copyBtn.Size = New-Object System.Drawing.Size(210, 38)
    $copyBtn.Add_Click({
        [System.Windows.Forms.Clipboard]::SetText($PromptText)
        $copyBtn.Text = "Copied to Clipboard!"
        $copyBtn.BackColor = [System.Drawing.Color]::FromArgb(22, 163, 74)
    })
    $dlg.Controls.Add($copyBtn)

    $doneBtn = New-Object System.Windows.Forms.Button
    $doneBtn.Text = "Done"
    $doneBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
    $doneBtn.Location = New-Object System.Drawing.Point(455, 304)
    $doneBtn.Size = New-Object System.Drawing.Size(110, 38)
    $doneBtn.Add_Click({ $dlg.Close() })
    $dlg.Controls.Add($doneBtn)

    [void]$dlg.ShowDialog($form)
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "JurisAtlas - $CountryName Legal MCP Setup"
$form.Size = New-Object System.Drawing.Size(640, 585)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "JurisAtlas: $CountryName Legal MCP Setup"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 13.5, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
$titleLabel.Location = New-Object System.Drawing.Point(24, 16)
$titleLabel.Size = New-Object System.Drawing.Size(580, 30)
$form.Controls.Add($titleLabel)

$safeBox = New-Object System.Windows.Forms.Label
$safeBox.Text = "Read-Only & Persistent Installation (%LOCALAPPDATA%\JurisAtlas\$RepoName)`r`n• Does NOT access or modify your personal documents, emails, or browser data.`r`n• Creates timestamped config backups before editing; safely delete the Downloads ZIP after setup."
$safeBox.Font = New-Object System.Drawing.Font("Segoe UI", 9.0)
$safeBox.ForeColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
$safeBox.BackColor = [System.Drawing.Color]::FromArgb(224, 242, 254)
$safeBox.BorderStyle = "FixedSingle"
$safeBox.Padding = New-Object System.Windows.Forms.Padding(10)
$safeBox.Location = New-Object System.Drawing.Point(24, 52)
$safeBox.Size = New-Object System.Drawing.Size(578, 78)
$form.Controls.Add($safeBox)

$groupBox = New-Object System.Windows.Forms.GroupBox
$groupBox.Text = "Select the AI Application(s) You Use:"
$groupBox.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$groupBox.ForeColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
$groupBox.Location = New-Object System.Drawing.Point(24, 140)
$groupBox.Size = New-Object System.Drawing.Size(578, 214)
$form.Controls.Add($groupBox)

$clientDefs = @(
    @{ Key = "claude"; Label = "Claude Desktop & Claude Code CLI"; X = 16; Y = 28 },
    @{ Key = "cursor"; Label = "Cursor Editor"; X = 300; Y = 28 },
    @{ Key = "vscode"; Label = "VS Code (Copilot / Cline / Roo Code)"; X = 16; Y = 62 },
    @{ Key = "windsurf"; Label = "Windsurf (Codeium)"; X = 300; Y = 62 },
    @{ Key = "antigravity"; Label = "Google Antigravity & Gemini CLI"; X = 16; Y = 96 },
    @{ Key = "lmstudio"; Label = "LM Studio"; X = 300; Y = 96 },
    @{ Key = "codex"; Label = "OpenAI Codex CLI"; X = 16; Y = 130 },
    @{ Key = "continue"; Label = "Continue.dev"; X = 300; Y = 130 }
)

$checkboxMap = @{}
foreach ($def in $clientDefs) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $def.Label
    $cb.Tag = $def.Label
    $cb.Font = New-Object System.Drawing.Font("Segoe UI", 9.0)
    $cb.Location = New-Object System.Drawing.Point($def.X, $def.Y)
    $cb.Size = New-Object System.Drawing.Size(272, 26)
    $groupBox.Controls.Add($cb)
    $checkboxMap[$def.Key] = $cb
}

$remoteNote = New-Object System.Windows.Forms.Label
$remoteNote.Text = "Note: ChatGPT Desktop / Web & Claude Web connect via Remote HTTPS MCP (--transport streamable-http), not local config files."
$remoteNote.Font = New-Object System.Drawing.Font("Segoe UI", 8.2)
$remoteNote.ForeColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
$remoteNote.Location = New-Object System.Drawing.Point(16, 166)
$remoteNote.Size = New-Object System.Drawing.Size(546, 36)
$groupBox.Controls.Add($remoteNote)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Ready."
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9.2)
$statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
$statusLabel.Location = New-Object System.Drawing.Point(24, 368)
$statusLabel.Size = New-Object System.Drawing.Size(578, 36)
$form.Controls.Add($statusLabel)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(24, 408)
$progressBar.Size = New-Object System.Drawing.Size(578, 22)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0
$form.Controls.Add($progressBar)

$detectBtn = New-Object System.Windows.Forms.Button
$detectBtn.Text = "Auto-Detect Installed Apps"
$detectBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9.2)
$detectBtn.Location = New-Object System.Drawing.Point(24, 444)
$detectBtn.Size = New-Object System.Drawing.Size(200, 34)
$form.Controls.Add($detectBtn)

$uninstallBtn = New-Object System.Windows.Forms.Button
$uninstallBtn.Text = "Uninstall / Remove"
$uninstallBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9.2, [System.Drawing.FontStyle]::Bold)
$uninstallBtn.BackColor = [System.Drawing.Color]::FromArgb(254, 242, 242)
$uninstallBtn.ForeColor = [System.Drawing.Color]::FromArgb(185, 28, 28)
$uninstallBtn.FlatStyle = "Flat"
$uninstallBtn.Location = New-Object System.Drawing.Point(412, 444)
$uninstallBtn.Size = New-Object System.Drawing.Size(190, 34)
$form.Controls.Add($uninstallBtn)

$installBtn = New-Object System.Windows.Forms.Button
$installBtn.Text = "Install to Selected AI Clients"
$installBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10.5, [System.Drawing.FontStyle]::Bold)
$installBtn.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
$installBtn.ForeColor = [System.Drawing.Color]::White
$installBtn.FlatStyle = "Flat"
$installBtn.Location = New-Object System.Drawing.Point(24, 488)
$installBtn.Size = New-Object System.Drawing.Size(578, 44)
$installBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($installBtn)

function Invoke-AutoDetectUI {
    $found = Get-DetectedClients
    $count = 0
    foreach ($k in $checkboxMap.Keys) {
        $cb = $checkboxMap[$k]
        $baseLabel = [string]$cb.Tag
        if ($found[$k]) {
            $cb.Checked = $true
            $cb.Text = "$baseLabel (Detected)"
            $count++
        } else {
            $cb.Checked = $false
            $cb.Text = $baseLabel
        }
    }
    if ($count -gt 0) {
        $statusLabel.Text = "Auto-detected $count installed AI application(s). Review selections and click Install."
    } else {
        $statusLabel.Text = "No AI applications auto-detected. Check the AI client(s) you use and click Install."
    }
}

$detectBtn.Add_Click({ Invoke-AutoDetectUI })
Invoke-AutoDetectUI

$script:WorkerState = $null
$script:PsWorker = $null
$script:WorkerRunspace = $null
$script:AsyncHandle = $null

$pollTimer = New-Object System.Windows.Forms.Timer
$pollTimer.Interval = 80

$workerScriptBlock = {
    param($State, $Action, $ScriptDir, $InstallDir, $LogFile, $RepoName, $SelectedClientsStr, $ConfigPyScript)
    $ErrorActionPreference = "Stop"
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    function Write-InstallLog {
        param([string]$Msg)
        $logParent = Split-Path -Parent $LogFile
        if (-not (Test-Path $logParent)) {
            New-Item -ItemType Directory -Path $logParent -Force | Out-Null
        }
        $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Add-Content -Path $LogFile -Value "[$stamp] $Msg" -Encoding UTF8
    }

    function Invoke-NativeStep {
        param(
            [string]$StepName,
            [string]$FilePath,
            [string[]]$ArgumentList,
            [string]$WorkingDirectory = "",
            [string]$StdinText = $null,
            [hashtable]$ExtraEnv = $null
        )
        Write-InstallLog "RUN: $StepName -> $FilePath $($ArgumentList -join ' ')"
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $FilePath
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }
        if ($null -ne $StdinText) { $psi.RedirectStandardInput = $true }
        if ($null -ne $ExtraEnv) {
            foreach ($ek in $ExtraEnv.Keys) {
                $psi.EnvironmentVariables[$ek] = [string]$ExtraEnv[$ek]
            }
        }
        $escapedArgs = foreach ($a in $ArgumentList) {
            if ($a -match '[\s"]') {
                '"' + ($a -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
            } else {
                $a
            }
        }
        $psi.Arguments = ($escapedArgs -join " ")
        $proc = [System.Diagnostics.Process]::Start($psi)
        if ($null -ne $StdinText) {
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            $sw = New-Object System.IO.StreamWriter($proc.StandardInput.BaseStream, $utf8NoBom)
            $sw.Write($StdinText)
            $sw.Flush()
            $sw.Close()
        }
        $outTask = $proc.StandardOutput.ReadToEndAsync()
        $errTask = $proc.StandardError.ReadToEndAsync()
        $proc.WaitForExit()
        $stdout = $outTask.Result
        $stderr = $errTask.Result
        $exitCode = $proc.ExitCode
        $global:LASTEXITCODE = $exitCode
        if ($stdout) { Write-InstallLog "STDOUT: $stdout" }
        if ($stderr) { Write-InstallLog "STDERR: $stderr" }
        if ($LASTEXITCODE -ne 0) {
            $detail = ($stderr + "`r`n" + $stdout).Trim()
            if ($detail.Length -gt 1100) { $detail = $detail.Substring($detail.Length - 1100) }
            throw "$StepName failed (exit code $exitCode).`r`n$detail"
        }
        return $stdout.Trim()
    }

    function Find-UvBinary {
        foreach ($p in @(
            "$env:USERPROFILE\.local\bin\uv.exe",
            "$env:LOCALAPPDATA\uv\uv.exe",
            "$env:USERPROFILE\.cargo\bin\uv.exe"
        )) {
            if (Test-Path $p) { return $p }
        }
        $cmd = Get-Command uv -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
        return $null
    }

    try {
        Write-InstallLog "=== Starting JurisAtlas action=$Action repo=$RepoName ==="
        if ($Action -eq "uninstall") {
            $State.Progress = 25
            $State.Status = "Step 1/2: Removing $RepoName entries from AI client configs..."
            $pyRunner = $null
            $venvPy = Join-Path $InstallDir ".venv\Scripts\python.exe"
            if (Test-Path $venvPy) {
                $pyRunner = $venvPy
            }
            if (-not $pyRunner) {
                $uvBin = Find-UvBinary
                if ($uvBin) {
                    try {
                        $foundPy = Invoke-NativeStep -StepName "Locate uv Python" -FilePath $uvBin -ArgumentList @("python", "find", "3.12")
                        if ($foundPy -and (Test-Path $foundPy.Trim())) { $pyRunner = $foundPy.Trim() }
                    } catch {}
                }
            }
            if (-not $pyRunner) {
                $pyCmd = Get-Command python -ErrorAction SilentlyContinue
                if ($pyCmd) { $pyRunner = $pyCmd.Source }
            }

            $removedFiles = @()
            if ($pyRunner) {
                $envMap = @{
                    "PYTHONIOENCODING" = "utf-8"
                    "PYTHONUTF8" = "1"
                    "JURISATLAS_ACTION" = "uninstall"
                    "JURISATLAS_REPO" = $RepoName
                    "JURISATLAS_PY" = ""
                    "JURISATLAS_SCRIPT" = ""
                    "JURISATLAS_CLIENTS" = ""
                }
                $jsonOut = Invoke-NativeStep -StepName "Clean AI Client Configs" -FilePath $pyRunner -ArgumentList @("-") -StdinText $ConfigPyScript -ExtraEnv $envMap
                try {
                    $parsed = $jsonOut | ConvertFrom-Json
                    if ($parsed.updated) { $removedFiles = @($parsed.updated) }
                } catch {}
            } else {
                Write-InstallLog "No Python interpreter found during uninstall; removing install directory only."
            }

            $State.Progress = 75
            $State.Status = "Step 2/2: Removing persistent installation folder..."
            $removedDir = $false
            if (Test-Path $InstallDir) {
                Remove-Item -LiteralPath $InstallDir -Recurse -Force
                $removedDir = $true
            }
            $State.Progress = 100
            $State.Status = "Uninstall complete."
            $State.Summary = "Removed $RepoName from $($removedFiles.Count) AI configuration file(s) (timestamped backups preserved)." + $(if ($removedDir) { " Deleted $InstallDir." } else { "" })
            $State.Success = $true
        } else {
            $State.Progress = 15
            $State.Status = "Step 1/5: Checking Python runtime manager (uv)..."
            $UvExe = Find-UvBinary
            if (-not $UvExe) {
                $State.Status = "Step 1/5: Installing uv package manager..."
                Invoke-NativeStep -StepName "Install uv" -FilePath "powershell.exe" -ArgumentList @(
                    "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
                    "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm https://astral.sh/uv/install.ps1 | iex"
                ) | Out-Null
                $UvExe = Find-UvBinary
                if (-not $UvExe) {
                    throw "Could not locate uv.exe after installation. Check your network connection or install uv manually from https://docs.astral.sh/uv/."
                }
            }

            $State.Progress = 35
            $State.Status = "Step 2/5: Copying server files to persistent folder..."
            foreach ($reqFile in @("mcp_server_main.py", "pyproject.toml")) {
                $srcPath = Join-Path $ScriptDir $reqFile
                if (-not (Test-Path $srcPath)) {
                    throw "Missing required file '$reqFile' next to gui_installer.ps1. Please extract the full ZIP archive before running."
                }
            }
            if (-not (Test-Path $InstallDir)) {
                New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
            }
            foreach ($copyFile in @("mcp_server_main.py", "pyproject.toml", "SKILL.md", "LICENSE")) {
                $srcPath = Join-Path $ScriptDir $copyFile
                if (Test-Path $srcPath) {
                    Copy-Item -LiteralPath $srcPath -Destination (Join-Path $InstallDir $copyFile) -Force
                }
            }

            $State.Progress = 55
            $State.Status = "Step 3/5: Preparing isolated Python 3.12 runtime..."
            $hasPy = $false
            try {
                Invoke-NativeStep -StepName "Check Python 3.12" -FilePath $UvExe -ArgumentList @("python", "find", "3.12") | Out-Null
                $hasPy = $true
            } catch {
                $hasPy = $false
            }
            if (-not $hasPy) {
                Invoke-NativeStep -StepName "Install Python 3.12" -FilePath $UvExe -ArgumentList @("python", "install", "3.12") | Out-Null
            }

            $State.Progress = 75
            $State.Status = "Step 4/5: Installing legal database & archive connectors..."
            Invoke-NativeStep -StepName "Sync Python Environment" -FilePath $UvExe -ArgumentList @("sync", "--python", "3.12") -WorkingDirectory $InstallDir | Out-Null

            $VenvPy = Join-Path $InstallDir ".venv\Scripts\python.exe"
            $MainPy = Join-Path $InstallDir "mcp_server_main.py"
            if (-not (Test-Path $VenvPy)) {
                throw "Expected virtual environment Python not found at: $VenvPy"
            }
            if (-not (Test-Path $MainPy)) {
                throw "Expected MCP server script not found at: $MainPy"
            }

            $State.Progress = 90
            $State.Status = "Step 5/5: Registering MCP server in selected AI applications..."
            $envMap = @{
                "PYTHONIOENCODING" = "utf-8"
                "PYTHONUTF8" = "1"
                "JURISATLAS_ACTION" = "install"
                "JURISATLAS_REPO" = $RepoName
                "JURISATLAS_PY" = $VenvPy
                "JURISATLAS_SCRIPT" = $MainPy
                "JURISATLAS_CLIENTS" = $SelectedClientsStr
            }
            $cfgOut = Invoke-NativeStep -StepName "Update AI Client Configs" -FilePath $VenvPy -ArgumentList @("-") -StdinText $ConfigPyScript -ExtraEnv $envMap
            $updatedCount = 0
            try {
                $parsed = $cfgOut | ConvertFrom-Json
                if ($parsed.updated) { $updatedCount = @($parsed.updated).Count }
            } catch {}

            $State.Progress = 100
            $State.Status = "Setup complete! Updated $updatedCount AI configuration file(s)."
            $State.Summary = "Connected $RepoName to $updatedCount AI client configuration file(s) with automatic timestamped backups."
            $State.Success = $true
        }
    } catch {
        $errMsg = $_.Exception.Message
        Write-InstallLog "ERROR: $errMsg"
        $State.Success = $false
        $State.Error = $errMsg
        $State.Status = "Operation failed. See error dialog and log for details."
    } finally {
        $State.Done = $true
    }
}

function Start-BackgroundAction {
    param([string]$Action, [string]$SelectedClientsStr)
    $installBtn.Enabled = $false
    $uninstallBtn.Enabled = $false
    $detectBtn.Enabled = $false
    foreach ($cb in $checkboxMap.Values) { $cb.Enabled = $false }
    if ($Action -eq "install") {
        $installBtn.Text = "Installing... Please wait"
        $installBtn.BackColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
    } else {
        $uninstallBtn.Text = "Removing..."
    }
    $progressBar.Value = 5

    $script:WorkerState = [hashtable]::Synchronized(@{
        Progress = 5
        Status = "Starting..."
        Done = $false
        Success = $false
        Summary = ""
        Error = ""
        Mode = $Action
    })

    $script:WorkerRunspace = [runspacefactory]::CreateRunspace()
    $script:WorkerRunspace.Open()
    $script:PsWorker = [powershell]::Create()
    $script:PsWorker.Runspace = $script:WorkerRunspace
    [void]$script:PsWorker.AddScript($workerScriptBlock).
        AddArgument($script:WorkerState).
        AddArgument($Action).
        AddArgument($ScriptDir).
        AddArgument($InstallDir).
        AddArgument($LogFile).
        AddArgument($RepoName).
        AddArgument($SelectedClientsStr).
        AddArgument($ConfigPyScript)

    $script:AsyncHandle = $script:PsWorker.BeginInvoke()
    $pollTimer.Start()
}

$pollTimer.Add_Tick({
    if ($null -eq $script:WorkerState) { return }
    $pct = [int]$script:WorkerState.Progress
    if ($pct -lt 0) { $pct = 0 }
    if ($pct -gt 100) { $pct = 100 }
    $progressBar.Value = $pct
    $statusLabel.Text = [string]$script:WorkerState.Status

    if ($script:WorkerState.Done) {
        $pollTimer.Stop()
        try {
            if ($null -ne $script:PsWorker -and $null -ne $script:AsyncHandle) {
                $script:PsWorker.EndInvoke($script:AsyncHandle) | Out-Null
            }
        } catch {
            if (-not $script:WorkerState.Error) {
                $script:WorkerState.Success = $false
                $script:WorkerState.Error = $_.Exception.Message
            }
        } finally {
            if ($null -ne $script:PsWorker) { $script:PsWorker.Dispose(); $script:PsWorker = $null }
            if ($null -ne $script:WorkerRunspace) { $script:WorkerRunspace.Close(); $script:WorkerRunspace.Dispose(); $script:WorkerRunspace = $null }
            $script:AsyncHandle = $null
        }

        $installBtn.Enabled = $true
        $uninstallBtn.Enabled = $true
        $detectBtn.Enabled = $true
        $uninstallBtn.Text = "Uninstall / Remove"
        foreach ($cb in $checkboxMap.Values) { $cb.Enabled = $true }

        if ($script:WorkerState.Success) {
            if ($script:WorkerState.Mode -eq "install") {
                $installBtn.Text = "Install / Reinstall to Selected AI Clients"
                $installBtn.BackColor = [System.Drawing.Color]::FromArgb(22, 163, 74)
                Show-CompletionDialog -SummaryText $script:WorkerState.Summary -PromptText $StarterPrompt -PersistentPath $InstallDir
            } else {
                $installBtn.Text = "Install to Selected AI Clients"
                $installBtn.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
                [System.Windows.Forms.MessageBox]::Show(
                    $script:WorkerState.Summary,
                    "JurisAtlas - Uninstall Complete",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
            }
        } else {
            $installBtn.Text = "Retry Installation"
            $installBtn.BackColor = [System.Drawing.Color]::FromArgb(220, 38, 38)
            [System.Windows.Forms.MessageBox]::Show(
                "Operation failed:`r`n`r`n$($script:WorkerState.Error)`r`n`r`nFull log: $LogFile",
                "JurisAtlas - Setup Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
    }
})

$installBtn.Add_Click({
    $selected = @()
    foreach ($def in $clientDefs) {
        if ($checkboxMap[$def.Key].Checked) {
            $selected += $def.Key
        }
    }
    if ($selected.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please select at least one AI application before installing.",
            "No Client Selected",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }
    Start-BackgroundAction -Action "install" -SelectedClientsStr ($selected -join ",")
})

$uninstallBtn.Add_Click({
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Remove $RepoName from all AI client configurations and delete $InstallDir?`r`n`r`n(Timestamped config backups are kept; unrelated MCP servers are never touched.)",
        "JurisAtlas - Confirm Uninstall",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
        Start-BackgroundAction -Action "uninstall" -SelectedClientsStr ""
    }
})

$form.Add_FormClosing({
    if ($null -ne $script:WorkerState -and -not $script:WorkerState.Done) {
        $_.Cancel = $true
        [System.Windows.Forms.MessageBox]::Show(
            "Setup is currently running. Please wait a moment for the current step to finish.",
            "Operation In Progress",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
})

[void]$form.ShowDialog()
