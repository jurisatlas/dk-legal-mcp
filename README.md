[← All JurisAtlas Jurisdictions](https://github.com/jurisatlas) · [Unified Multi-Country Installer](https://github.com/jurisatlas/cli) · [Interactive Setup Guide](https://jurisatlas.github.io)

**Languages:** **English** | [Dansk](docs/README.da.md)

# Denmark Official Legal Research for Your AI Assistant (`dk-legal-mcp`)

Connect your desktop AI assistant directly to official **Denmark (DK)** legislation, official gazettes, and multi-tier court decisions (First Instance, High Courts (Østre & Vestre Landsret), and Supreme / Constitutional courts) with honest citation verification and full HTML/PDF text extraction.

**Free & Open Source (MIT)** · **Read-Only Official Portals** · **Zero API Keys** · **Never Touches Personal Files** · **1-Click Uninstall**

---

## Easy Setup for Lawyers & Researchers (No Coding, No ZIP Needed)

> [!TIP]
> **1-File Auto-Downloading Installer:** Download just the single installer file below and double-click it — **no ZIP extraction needed**. It automatically fetches the latest `dk-legal-mcp` files from GitHub in the background, installs persistently into your local app folder, and opens the visual setup window.
> - **Windows:** Download **[`Click_Here_To_Install_Windows.bat`](https://github.com/jurisatlas/dk-legal-mcp/raw/main/Click_Here_To_Install_Windows.bat)** and double-click it.
> - **macOS:** Download **[`Click_Here_To_Install_Mac.command`](https://github.com/jurisatlas/dk-legal-mcp/raw/main/Click_Here_To_Install_Mac.command)** and double-click it.
> - *Prefer an offline full archive?* You can also download the optional complete ZIP via **`<> Code` → `Download ZIP`** or **[Releases](https://github.com/jurisatlas/dk-legal-mcp/releases)** — the launcher works both standalone and inside an extracted folder.
> - *Want multiple countries or a 1-click Claude Desktop `.mcpb` bundle?* Use the **[Unified Multi-Country Installer (`jurisatlas/cli`)](https://github.com/jurisatlas/cli)**, **[Unified Server (`jurisatlas-mcp`)](https://github.com/jurisatlas/jurisatlas-mcp)**, or **[jurisatlas.github.io](https://jurisatlas.github.io)**.

1. **Download 1 File:** Click the Windows (`.bat`) or macOS (`.command`) link above (or download the optional full ZIP).
2. **Double-Click to Launch:** The self-bootstrapping launcher fetches all required `dk-legal-mcp` files automatically from GitHub in the background and opens the visual setup window.
3. **Connect & Restart:** Review your **auto-detected AI apps**, click **Install to Selected AI Clients**, and restart your AI app. The server installs persistently to `%LOCALAPPDATA%\JurisAtlas\dk-legal-mcp` (Windows) or `~/.jurisatlas/dk-legal-mcp` (macOS), so you can delete the downloaded file afterward.

**Supported AI Applications:**
- **Auto-configured locally:** Claude Desktop & Claude Code CLI, Cursor, VS Code (GitHub Copilot / Cline / Roo Code), Windsurf, Google Antigravity & Gemini CLI, LM Studio, OpenAI Codex CLI, and Continue.dev.
- **ChatGPT Desktop / Web & Claude Web:** Connect via a live HTTPS MCP URL (`--transport streamable-http`, see below).

### How to Connect via MCP Link / JSON

- **1-Click App Deep Links & Claude `.mcpb`:** Open **[jurisatlas.github.io](https://jurisatlas.github.io)** for 1-click **Cursor** (`cursor://...`) and **VS Code** (`vscode:mcp/...`) install buttons and the drag-and-drop **Claude Desktop `.mcpb`** bundle.
- **Direct Local MCP JSON (No Git Required):** Open the Developer Reference below and paste the `uvx` JSON block into your AI app's MCP settings (`mcpServers` for Claude / Cursor / Windsurf / Antigravity / LM Studio, or `"servers"` + `"type": "stdio"` for VS Code).
- **Live Pasteable HTTPS MCP URL (`https://.../mcp`):** For ChatGPT Desktop/Web or Claude Web Connectors, run `dk-legal-mcp --transport streamable-http --host 0.0.0.0 --port 8000` (or deploy the unified **[`jurisatlas-mcp`](https://github.com/jurisatlas/jurisatlas-mcp)** with 1 click on FastMCP Cloud or Render) and paste your `https://.../mcp` endpoint URL.

<details>
<summary><b>Seeing a Windows SmartScreen or macOS Gatekeeper security popup? (Normal & Safe)</b></summary>

- **Windows (Microsoft Defender SmartScreen):** Click **More info** → **Run anyway**.
- **macOS (Gatekeeper / macOS Sequoia):** Open **System Settings → Privacy & Security**, scroll down to the blocked file notice, and click **Open Anyway**.
- **Why does this appear?** Community open-source scripts without a paid commercial code-signing certificate trigger the default OS warning. Every line of installer and server code in this repository is publicly readable.

</details>

**Safety & 1-Click Uninstall:** Runs strictly read-only against public official legal portals and never accesses your documents, emails, or browser data. Before editing any AI config file, the installer creates a timestamped backup and writes atomically. To remove everything cleanly at any time, reopen the same visual installer and click **Uninstall / Remove**.

---

## Try It Right Away: 3 Copy-Paste Starter Prompts

1. **Citation Verification:**
   > Verify `UfR 2024.123 H or LBK nr 100` in official Denmark registries, report whether it is a `VERIFIED_OFFICIAL_RECORD` or `UNCONFIRMED_WEB_MATCH`, and summarize the key holding or statutory rule with official links.
2. **Statute & Precedent Research:**
   > Research controlling Denmark legislation and recent appellate/supreme court decisions on commercial contract termination, citing only verified official sources with clickable URLs.
3. **Court Hierarchy & Appeal Path:**
   > Map the 3-tier court hierarchy in Denmark (First Instance → High Courts (Østre & Vestre Landsret) → Supreme / Constitutional) for an administrative dispute and retrieve recent decisions from the appellate tier.

---

## Covered Courts & Official Portals

| Judicial Tier | Covered Courts & Tribunals |
|:---|:---|
| **Tier 1 — First Instance** | 24 Byretter (District Courts) & Sø- og Handelsretten (Maritime and Commercial High Court) |
| **Tier 2 — High Courts (Østre & Vestre Landsret)** | Østre Landsret (High Court of Eastern Denmark) & Vestre Landsret (High Court of Western Denmark) |
| **Tier 3 — Supreme & Constitutional** | Højesteret (Supreme Court of Denmark) |

- **Official Legislation & Gazette:** Retsinformation Open Data API (retsinformation.dk) — [https://www.retsinformation.dk](https://www.retsinformation.dk) (`retsinformation.dk`, `ft.dk`)
- **Court Decisions & Jurisprudence:** Domsdatabasen (domsdatabasen.dk — Byretter, Østre/Vestre Landsret, Sø- og Handelsretten & Højesteret) — [https://domsdatabasen.dk](https://domsdatabasen.dk) (`domsdatabasen.dk`, `domstol.dk`, `hoejesteret.dk`)

---

<details>
<summary><b>Developer & Technical Reference (6 MCP Tools, 3 Prompts, uvx, Manual JSON & Streamable HTTP)</b></summary>

### Standardized MCP Tools (6 Tools)

| Tool | Description |
|:---|:---|
| `search_legislation` | Searches enacted statutes, codes, regulations, and official gazettes in Denmark. Returns `source_tier` (`official_registry_api` vs `web_search_fallback`) and structured `warnings`. |
| `search_case_law` | Searches national jurisprudence and judicial archives for Denmark, tagging official API vs web fallback hits. |
| `search_tiered_court_decisions` | Filters case law by judicial instance (`first_instance`, `appellate_regional` — High Courts (Østre & Vestre Landsret), `supreme_constitutional`) or a sub-portal key. |
| `list_court_hierarchy` | Returns the complete 3-tier court structure and official sub-portal keys for Denmark. |
| `get_legal_document_markdown` | Fetches full statutory or judgment text (HTML or `.pdf`) and converts it to clean paginated Markdown. |
| `verify_citation` | Verifies legal citations against live sources, returning `VERIFIED_OFFICIAL_RECORD` only for official registry API hits, `UNCONFIRMED_WEB_MATCH` for web fallback hits, or `NOT_FOUND`. |

### Built-in MCP Prompts (3 Native Prompts)

- `verify_citations_in_draft` — Extract and audit every Denmark citation in a legal brief, memo, or contract.
- `research_statute_and_precedent` — Research controlling statutes and multi-tier case law for a legal issue.
- `map_court_hierarchy` — Map the 3-tier court escalation path and locate appellate decisions.

### Run Directly with `uvx` (No Git Required)

```bash
uvx --from https://github.com/jurisatlas/dk-legal-mcp/archive/refs/heads/main.zip dk-legal-mcp
```

### Remote HTTPS / Streamable HTTP Mode (ChatGPT Desktop / Web & Claude Web)

```bash
uvx --from https://github.com/jurisatlas/dk-legal-mcp/archive/refs/heads/main.zip dk-legal-mcp --transport streamable-http --host 127.0.0.1 --port 8000
```

### Manual JSON Configuration

**Claude Desktop / Cursor / Windsurf / Antigravity / LM Studio (`mcpServers`):**

```json
{
  "mcpServers": {
    "dk-legal-mcp": {
      "command": "uvx",
      "args": [
        "--from",
        "https://github.com/jurisatlas/dk-legal-mcp/archive/refs/heads/main.zip",
        "dk-legal-mcp"
      ],
      "env": {
        "PYTHONIOENCODING": "utf-8"
      }
    }
  }
}
```

**VS Code (`Code/User/mcp.json` — uses `"servers"` + `"type": "stdio"`):**

```json
{
  "servers": {
    "dk-legal-mcp": {
      "type": "stdio",
      "command": "uvx",
      "args": [
        "--from",
        "https://github.com/jurisatlas/dk-legal-mcp/archive/refs/heads/main.zip",
        "dk-legal-mcp"
      ],
      "env": {
        "PYTHONIOENCODING": "utf-8"
      }
    }
  }
}
```

</details>

---

> **Not Legal Advice:** JurisAtlas is an open-source legal research aid, not legal advice. Always verify statutes and judgments against official gazettes and court registries before relying on them in legal work. Only `VERIFIED_OFFICIAL_RECORD` results come from structured official APIs; `UNCONFIRMED_WEB_MATCH` results come from indexed web search fallback and require manual verification. Released under the [MIT License](LICENSE).
