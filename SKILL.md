---
name: dk-legal-mcp-skill
description: Official Denmark (DK) legislation, multi-tier court precedent research, and citation verification skill.
version: 2.0.0
author: JurisAtlas
license: MIT
---

# Denmark Legal Research & Multi-Tier Case Law Skill (`dk-legal-mcp`)

Use this skill whenever the user asks a legal question, drafts a pleading or contract, or researches case law across any judicial instance in **Denmark (DK)**.

## Verification & Research Rules

1. **Citation Verification:** Never fabricate a statutory provision or case citation. Query `search_legislation`, `search_case_law`, `search_tiered_court_decisions`, or `verify_citation` before citing any authority (e.g., `UfR 2024.123 H or LBK nr 100`).
2. **Multi-Tier Judicial Coverage:**
   - **First Instance (Trial / Municipal / District):** 24 Byretter (District Courts) & Sø- og Handelsretten (Maritime and Commercial High Court)
   - **Second Instance (Cantonal / Regional / Appellate):** Østre Landsret (High Court of Eastern Denmark) & Vestre Landsret (High Court of Western Denmark)
   - **Supreme & Constitutional Instance:** Højesteret (Supreme Court of Denmark)
   - **Primary Tiered Database:** Domsdatabasen (domsdatabasen.dk — Byretter, Østre/Vestre Landsret, Sø- og Handelsretten & Højesteret) (`https://domsdatabasen.dk`)
