[← All JurisAtlas Jurisdictions](https://github.com/jurisatlas) · [Unified Multi-Country Installer](https://github.com/jurisatlas/cli) · [English README](../README.md)

**Languages:** [English](../README.md) | **Dansk**

# Officiel juridisk søgning til din AI-assistent — Denmark (`dk-legal-mcp`)

Denne gratis, skrivebeskyttede Model Context Protocol (MCP)-server forbinder din AI-applikation (Claude Desktop & Claude Code CLI, Cursor, VS Code (GitHub Copilot / Cline / Roo Code), Windsurf, Google Antigravity & Gemini CLI, LM Studio, OpenAI Codex CLI, and Continue.dev) direkte til Retsinformation (`retsinformation.dk`) og Domsdatabasen (`domsdatabasen.dk` — byretterne, Sø- og Handelsretten, Østre og Vestre Landsret samt Højesteret).

**Gratis & Open Source (MIT) · Skrivebeskyttet mod officielle portaler · Ingen API-nøgler · Rører ikke personlige filer · Afinstallation med 1 klik**

---

## Nem installation (Ingen kodning, ingen ZIP)

> [!TIP]
> **1-fils installationsprogram (Ingen ZIP nødvendig):** Download kun den enkelte fil herunder og dobbeltklik — den henter automatisk alle nødvendige filer fra GitHub i baggrunden og åbner installationsvinduet. Fuld ZIP (`<> Code` → `Download ZIP`) er også tilgængelig som valgmulighed.
> - **Windows:** [`Click_Here_To_Install_Windows.bat`](https://github.com/jurisatlas/dk-legal-mcp/raw/main/Click_Here_To_Install_Windows.bat)
> - **macOS:** [`Click_Here_To_Install_Mac.command`](https://github.com/jurisatlas/dk-legal-mcp/raw/main/Click_Here_To_Install_Mac.command)
> - Har du brug for flere lande? Brug **[Samlet flerlands-installationsprogram (jurisatlas/cli)](https://github.com/jurisatlas/cli)** eller **[jurisatlas-mcp](https://github.com/jurisatlas/jurisatlas-mcp)**.

1. **Download 1 fil:** Klik på Windows- (`.bat`) eller macOS-linket (`.command`) ovenfor (eller fuld ZIP som tilvalg).
2. **Dobbeltklik for at starte:** Starteren henter automatisk de nyeste filer fra GitHub i baggrunden og åbner den grafiske guide.
3. **Forbind AI-apps:** Gennemse automatisk fundne AI-programmer (Claude Desktop & Claude Code CLI, Cursor, VS Code (GitHub Copilot / Cline / Roo Code), Windsurf, Google Antigravity & Gemini CLI, LM Studio, OpenAI Codex CLI, and Continue.dev), klik **Install to Selected AI Clients** og genstart AI-appen.

**Bemærk for ChatGPT Desktop / Web & Claude Web:** Disse apps benytter en ekstern HTTPS MCP-URL (`--transport streamable-http`, se nedenfor).

### Forbind via MCP-link eller JSON

- **1-Click Links & Claude `.mcpb`:** [jurisatlas.github.io](https://jurisatlas.github.io) (Cursor `cursor://`, VS Code `vscode:mcp/`, Claude Desktop `.mcpb`).
- **Local MCP JSON (`uvx`):** `dk-legal-mcp` via `https://github.com/jurisatlas/dk-legal-mcp/archive/refs/heads/main.zip` (see Developer Reference below; no Git required).
- **Remote HTTPS MCP (`https://.../mcp`):** `dk-legal-mcp --transport streamable-http --host 0.0.0.0 --port 8000` or 1-click deploy on FastMCP Cloud / Render via [`jurisatlas-mcp`](https://github.com/jurisatlas/jurisatlas-mcp).

<details>
<summary><b>Ser du en Windows SmartScreen- eller macOS Gatekeeper-advarsel? (Normalt & Sikkert)</b></summary>

- **Windows (SmartScreen):** Klik på **Flere oplysninger** → **Kør alligevel**.
- **macOS (Gatekeeper / Sequoia):** Åbn **Systemindstillinger → Anonymitet og sikkerhed** og klik på **Åbn alligevel**.

</details>

**Sikkerhed & 1-kliks afinstallation:** Arbejder udelukkende i skrivebeskyttet tilstand mod officielle portaler og rører ikke personlige filer. Åbn guiden igen og klik **Uninstall / Remove** for at fjerne alt.

---

## Prøv med det samme: 3 eksempelprompts

1. > Verificer henvisningen `UfR 2024.123 H or LBK nr 100` i officielle registre for Denmark, oplys om den er officielt bekræftet og opsummer reglen.
2. > Søg relevant lovgivning og retspraksis i Denmark om et konkret juridisk spørgsmål med officielle links.
3. > Kortlæg domstolshierarkiet i Denmark i tre instanser og find nyere landsretsdomme.

---

## Domstolshierarki og officielle kilder

| Instans | Omfattede domstole |
|:---|:---|
| **1. instans (24 Byretter & Sø- og Handelsretten)** | 24 Byretter (District Courts) & Sø- og Handelsretten (Maritime and Commercial High Court) |
| **2. instans (Østre Landsret & Vestre Landsret)** | Østre Landsret (High Court of Eastern Denmark) & Vestre Landsret (High Court of Western Denmark) |
| **3. instans (Højesteret)** | Højesteret (Supreme Court of Denmark) |

- **Retsinformation Open Data API (retsinformation.dk):** [https://www.retsinformation.dk](https://www.retsinformation.dk) (`retsinformation.dk`, `ft.dk`)
- **Domsdatabasen (domsdatabasen.dk — Byretter, Østre/Vestre Landsret, Sø- og Handelsretten & Højesteret):** [https://domsdatabasen.dk](https://domsdatabasen.dk) (`domsdatabasen.dk`, `domstol.dk`, `hoejesteret.dk`)

---

<details>
<summary><b>Teknisk reference til udviklere (6 MCP-værktøjer, 3 prompts, uvx, manuel JSON & Streamable HTTP)</b></summary>

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

> **Ikke juridisk rådgivning:** JurisAtlas er et researchværktøj. Kontroller altid mod Retsinformation og officielle kilder. Kun `VERIFIED_OFFICIAL_RECORD` stammer fra et officielt API. ([MIT License](../LICENSE))
