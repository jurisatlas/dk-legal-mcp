# Denmark Legal Research MCP Server (`dk-legal-mcp`)

**[Dansk](#lang-da) | [English Documentation](#english-documentation)**

---

<a id="lang-da"></a>
## Juridisk MCP-server for Dansk Lovgivning og Retspraksis (`dk-legal-mcp`) — Dansk

### Om dette arkiv

Dette arkiv indeholder en Model Context Protocol (MCP) server, der forbinder din AI-applikation (Claude Desktop, Cursor, Windsurf, VS Code / Copilot, Cline eller Antigravity) direkte til Retsinformation (`retsinformation.dk`) og Domsdatabasen (`domsdatabasen.dk` — byretterne, Sø- og Handelsretten, Østre og Vestre Landsret samt Højesteret).

### Installation (Valg af AI-applikation)

1. **Download:** Klik på **`<> Code` -> `Download ZIP`** øverst til højre og udpak mappen på din computer.
2. **Start installationen:** Dobbeltklik på **`Click_Here_To_Install_Windows.bat`** (Windows) eller **`Click_Here_To_Install_Mac.command`** (macOS).
3. **Vælg AI-klient:** Marker de AI-programmer du anvender (Claude, Cursor, Windsurf, VS Code, Antigravity), klik på installer og genstart din AI-applikation.

**Sikkerhedsbemærkning:** Installationsværktøjet arbejder udelukkende i skrivebeskyttet tilstand (read-only) og tilgår ingen personlige filer på din computer.

### Domstolshierarki og officielle kilder

| Instans | Omfattede domstole |
|:---|:---|
| **1. instans (24 Byretter & Sø- og Handelsretten)** | 24 Byretter (District Courts) & Sø- og Handelsretten (Maritime and Commercial High Court) |
| **2. instans (Østre Landsret & Vestre Landsret)** | Østre Landsret (High Court of Eastern Denmark) & Vestre Landsret (High Court of Western Denmark) |
| **3. instans (Højesteret)** | Højesteret (Supreme Court of Denmark) |

- **Retsinformation Open Data API (retsinformation.dk):** [https://www.retsinformation.dk](https://www.retsinformation.dk) (`retsinformation.dk`, `ft.dk`)
- **Domsdatabasen (domsdatabasen.dk — Byretter, Østre/Vestre Landsret, Sø- og Handelsretten & Højesteret):** [https://domsdatabasen.dk](https://domsdatabasen.dk) (`domsdatabasen.dk`, `domstol.dk`, `hoejesteret.dk`)

---

<a id="english-documentation"></a>
## English Documentation

Model Context Protocol (MCP) server providing live, read-only access to **Denmark (DK)** legislation, official gazettes, multi-tier judicial decisions (First Instance, Regional/Cantonal/Appellate, and Supreme/Constitutional courts, including HTML and PDF full-text extraction), and statutory citation verification across all major AI clients (**ChatGPT Desktop, OpenAI Codex CLI, Claude Desktop, Claude Code CLI, Cursor, Windsurf, VS Code / GitHub Copilot / Cline / Roo Code, Google Antigravity / Gemini CLI, Perplexity, and Continue.dev**).

---

### Interactive Desktop Setup (Select Your AI Assistant)

This package includes a graphical installer for legal practitioners and non-technical users that lets you select which AI application(s) you use:

1. **Download:** Click **`<> Code`** at the top right of this repository, select **`Download ZIP`**, and extract the folder to your computer.
2. **Run the Setup Utility:**
   - **Windows:** Double-click `Click_Here_To_Install_Windows.bat`
   - **macOS:** Double-click `Click_Here_To_Install_Mac.command`
3. **Select Your AI Client(s) & Connect:** Check the box(es) for the AI assistant(s) installed on your computer (**ChatGPT Desktop & OpenAI Codex CLI**, **Claude Desktop & Claude Code CLI**, **Cursor**, **Windsurf**, **VS Code / GitHub Copilot / Cline / Roo Code**, **Google Antigravity / Gemini CLI**, or **Perplexity / Continue.dev**), click **Install to Selected AI Clients**, and restart your selected AI application.

**System Integrity Note:** The setup utility operates strictly in read-only mode with respect to your personal files and documents. It installs an isolated Python runtime inside the extracted folder and registers the server entry only in the AI client configuration files you select.

---

### Multi-Tier Judicial Hierarchy & Live Indexed National Archives

This server performs live queries across the full judicial hierarchy and official legal archives of **Denmark**, extracting full text from both HTML pages and official court/gazette PDF judgments:

| Judicial Tier | Covered Courts & Tribunals |
|:---|:---|
| **Tier 1 — First Instance** | 24 Byretter (District Courts) & Sø- og Handelsretten (Maritime and Commercial High Court) |
| **Tier 2 — Regional / Cantonal / Appellate** | Østre Landsret (High Court of Eastern Denmark) & Vestre Landsret (High Court of Western Denmark) |
| **Tier 3 — Supreme & Constitutional** | Højesteret (Supreme Court of Denmark) |

#### Official Portals & Live Indexed Domains

- **National Legislation & Official Gazette:** Retsinformation Open Data API (retsinformation.dk) — [https://www.retsinformation.dk](https://www.retsinformation.dk)
  - *Indexed Legislation Domains:* `retsinformation.dk`, `ft.dk`
- **Court Decisions & Jurisprudence Archives:** Domsdatabasen (domsdatabasen.dk — Byretter, Østre/Vestre Landsret, Sø- og Handelsretten & Højesteret) — [https://domsdatabasen.dk](https://domsdatabasen.dk)
  - *Indexed Judicial & Open Case Law Domains:* `domsdatabasen.dk`, `domstol.dk`, `hoejesteret.dk`

---

### Available MCP Tools

| Tool | Description |
|:---|:---|
| `search_legislation` | Searches enacted statutes, codes, decrees, and official gazette publications in Denmark. |
| `search_case_law` | Searches national jurisprudence and open judicial archives for Denmark. |
| `search_tiered_court_decisions` | Filters case law specifically by judicial instance (`first_instance`, `appellate_regional`, `supreme_constitutional`) or specific regional/cantonal/district court. |
| `list_court_hierarchy` | Returns the complete 3-tier court structure and supported regional court filters for Denmark. |
| `get_legal_document_markdown` | Retrieves full statutory or judicial texts (both HTML and official `.pdf` court judgments) and converts them into clean Markdown. |
| `verify_citation` | Validates statutory and case law citations against official registries. |

---

<details>
<summary><b>Manual Configuration for Developers (Optional)</b></summary>

```json
{
  "mcpServers": {
    "dk-legal-mcp": {
      "command": "uvx",
      "args": [
        "--from",
        "https://github.com/jurisatlas/dk-legal-mcp/archive/refs/heads/main.zip",
        "dk-legal-mcp"
      ]
    }
  }
}
```
</details>
