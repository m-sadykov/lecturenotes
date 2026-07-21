---
name: aso-llm-judge
description: >-
  Evaluates App Store metadata against tail search queries using an LLM-as-judge
  workflow modeled on Apple's search relevance research. Generates relevance
  scores (1–5), gap analysis, and metadata recommendations. Use when the user
  asks to run ASO LLM judge, evaluate App Store metadata, score search
  relevance, optimize tail queries, or improve title/subtitle/description for
  App Store search.
---

# ASO LLM Judge

Simulate Apple's textual relevance evaluator: given a search query and app metadata, rate how semantically relevant the app is (1–5) and recommend metadata fixes.

Based on [Apple's research](https://arxiv.org/pdf/2602.23234) — tail queries benefit most because behavioral signals are sparse.

## Quick Start

When invoked:

1. Determine locale (default: `en-US`; accept `en`, `de-DE`, `ar-SA`, etc.)
2. Load metadata and product context (see [Data Sources](#data-sources))
3. Build or load ~30 tail queries (see [tail-queries.md](tail-queries.md))
4. Score every query using [Judge Prompt](#judge-prompt)
5. Deliver report using [report-template.md](report-template.md)
6. Propose concrete title/subtitle/description/keyword changes

Ask the user only if locale is unclear or they want a custom query set.

---

## Data Sources

All App Store metadata lives under `metadata/`. Do not read `docs/app-store-*` files.

| Field | Source |
|-------|--------|
| Title, subtitle | `metadata/app-info/{locale}.json` → `name`, `subtitle` |
| Description, keywords, promotional text | `metadata/version/{version}/{locale}.json` → `description`, `keywords`, `promotionalText` |
| Product USP, audience, features | `docs/doable_tech_spec.md` or `docs/doable_tech_spec_prototype.md` |

**Version folder:** Use the highest semver directory under `metadata/version/` (e.g. `1.4`). If the user names a version, use that instead.

**Locale mapping:** `en` → `en-US`; `ar` → `ar-SA`; `de` → `de-DE`; `fr` → `fr-FR`; match filenames in `metadata/app-info/`.

**Loading:** Merge `app-info` + `version` JSON for the same locale before judging. If a version file is missing for a locale, judge title + subtitle only and note the gap.

---

## Workflow

### Phase 1 — Load context

```
Task Progress:
- [ ] Locale and version confirmed
- [ ] Metadata loaded from metadata/app-info + metadata/version
- [ ] Product USP summarized (3–5 intent themes)
- [ ] Query set ready (~30 queries)
```

Summarize USP in intent themes before judging. For Doable, default themes:

- Gentle / calm habit tracking (no pressure, no guilt)
- Minimal micro-habits and daily routines
- Streaks and simple progress
- Audience: anxiety, burnout, ADHD, procrastination, beginners
- Practical: offline, widgets, one-tap check-in

### Phase 2 — Build query set

Start from [tail-queries.md](tail-queries.md). Customize by:

- Replacing generic habit terms with locale-appropriate phrasing
- Adding 5–10 user-supplied queries if provided
- Ensuring mix: ~40% head (high volume), ~60% tail (niche, long-tail)

Target **30 queries** unless the user specifies otherwise.

### Phase 3 — Judge each query

For **each** query, apply the judge prompt below. Score honestly — do not inflate scores to please the user.

**Batching:** Score all 30 in one pass if context allows; otherwise batches of 10. Every query must appear in the final report.

### Phase 4 — Analyze and recommend

After all scores:

1. **Average score** and **median score**
2. **Weak queries** (score ≤ 2): critical metadata gaps
3. **Partial queries** (score = 3): improvable with subtitle/description tweaks
4. **Strong queries** (score ≥ 4): protect this language in metadata; don't remove it in refactors
5. **Intent theme coverage**: which themes score well vs poorly

Recommendations must be **specific and actionable**:

- Exact subtitle alternatives (≤ 30 chars) with character counts
- Description sentences to add (with placement: opening / features / closing) → `metadata/version/{version}/{locale}.json`
- Keywords to add (no words duplicated from title) → same version file
- Per-field priority: 🔴 title/subtitle, 🟡 description, 🟢 keywords

Do **not** edit metadata files unless the user explicitly asks to apply changes.

### Phase 5 — Optional comparison

If the user provides **before/after** metadata or asks to compare locales:

- Run the same query set on both versions
- Show delta table: query → old score → new score

---

## Judge Prompt

Use this template for each query. Replace placeholders with loaded metadata.

```text
You are an App Store search relevance evaluator.

A user typed this search query in the App Store. Your job is to judge how
relevant this app is to that query, based ONLY on the app metadata below.
Do not assume features that are not stated or strongly implied.

Relevance scale:
1 = Irrelevant — wrong category or intent
2 = Weak — same category but poor semantic match
3 = Partial — related intent, missing key signals in metadata
4 = Good — clear match, minor gaps
5 = Perfect — metadata directly answers this query

Strict rules:
- Judge semantic intent, not keyword overlap alone
- Penalize overpromising (metadata claims features not described)
- Reward clear differentiation when the query is niche (e.g. "gentle", "ADHD")
- Respond in this exact format:
  SCORE: [1-5]
  REASON: [one sentence, max 25 words]

Search query: "{query}"

App metadata:
- Title: {title}
- Subtitle: {subtitle}
- Promotional text: {promotionalText_or_"not provided"}
- Description: {description_first_500_chars}
- Keywords: {keywords_or_"not provided"}
```

When executing as the agent, you **are** the judge — apply this rubric directly; do not call an external API unless the user requests it.

---

## Scoring Rubric (calibration)

| Score | Meaning | Example for Doable |
|-------|---------|-------------------|
| 1 | Wrong app type | Query: "calorie counter" |
| 2 | Right category, wrong positioning | Query: "gamified habit RPG" (Doable is calm, not gamified) |
| 3 | Related but metadata silent on key intent | Query: "habit tracker for anxiety" (description lacks anxiety/gentle) |
| 4 | Strong match, small gap | Query: "simple habit tracker" |
| 5 | Metadata mirrors query intent | Query: "habit tracker with streaks" (streaks in description) |

---

## Report Output

Deliver the final report using [report-template.md](report-template.md). Include:

- Metadata snapshot judged
- Full score table (all 30 queries)
- Summary stats
- Top 5 gaps and top 5 strengths
- Prioritized recommendations with character counts for title/subtitle

Report language: match the user's language (Russian if they write in Russian).

---

## Anti-patterns

- Do not keyword-stuff recommendations
- Do not recommend title terms already in keywords field
- Do not score based on app code features absent from metadata
- Do not skip tail queries — they are the primary value of this skill
- Do not claim Apple uses this exact prompt; this is a practical simulation

---

## Alignment with Apple paper

Reference: [Scaling Search Relevance (arXiv:2602.23234)](https://arxiv.org/pdf/2602.23234) — Apple's LLM-as-a-Judge for App Store textual relevance.

This section does **not** change the workflow. It explains what we simulate, what we do not, and how to interpret scores.

### What we simulate

- **Pointwise textual relevance:** query + app metadata → ordinal label (1–5)
- **Tail-query priority:** paper §5 shows the largest conversion lift on low-frequency (tail) queries where behavioral signals are sparse; this skill weights ~60% of queries as tail (see [tail-queries.md](tail-queries.md))
- **Metadata-only judgment:** judge uses the same class of inputs human annotators see (title, subtitle, description, keywords) — not app code or assumed features

### What we do NOT simulate

- Production ranker training or behavioral signals (clicks, downloads)
- Fine-tuned in-house LLM (paper: FT-3B with F1 ≈ 0.80 on human labels vs generic pretrained models)
- Millions of query–app pairs from search logs
- Real-time reranking or listwise/pairwise comparison across competitors (listed as Apple future work in paper §6)

### Mapping: Apple pipeline → this skill

| Apple (production) | This skill (developer ASO) |
|--------------------|----------------------------|
| Query–app pair from search logs | Curated query + your merged metadata |
| LLM generates textual relevance label | Agent applies [Judge Prompt](#judge-prompt) |
| Label augments ranker training data | Score highlights metadata gaps |
| Multi-objective: textual + behavioral | Textual relevance only |
| A/B test: +0.24% conversion (worldwide) | Before/after score delta (proxy metric) |

### How to interpret results

- **Tail scores (≤2 → ≥4)** align with where Apple's system gains most; prioritize these in metadata edits
- **Head query scores near 5** are expected when title names the category; do not over-optimize head at the expense of tail differentiation
- **Average/median scores** measure metadata semantic fit — a quality proxy, not a ranking position prediction
- **Before/after comparison** (Phase 5) mirrors the iterative goal of improving textual relevance labels, without access to Apple's ranker

### Optional extensions (closer to paper, not default)

- Replace seed queries with real terms from App Store Connect / Search Ads
- **Pairwise judge:** score your app vs 1–2 competitor metadata for the same query (closer to ranking in a result set)
- Manual calibration: spot-check 5–10 queries against your own judgment to stabilize scores

### Disclaimer

This is a practical ASO workflow **inspired by** Apple's research, not Apple's production system. Do not claim scores predict App Store rank or conversion.

---

## Additional Resources

- Seed query bank: [tail-queries.md](tail-queries.md)
- Report template: [report-template.md](report-template.md)
