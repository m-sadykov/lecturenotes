# ASO LLM Judge Report — {locale}

**Date:** {date}  
**App:** {title}  
**Method:** LLM-as-judge (Apple textual relevance simulation)

## Metadata judged

| Field | Value |
|-------|-------|
| Title ({title_chars}/30) | {title} |
| Subtitle ({subtitle_chars}/30) | {subtitle} |
| Promotional text | {promotional_text_or_not_provided} |
| Keywords | {keywords} |
| Description (excerpt) | {first_2_sentences} |
| Version | {version} |

## Intent themes

{list_3_to_5_themes_from_product_context}

## Summary

| Metric | Value |
|--------|-------|
| Queries judged | {n} |
| Average score | {avg} |
| Median score | {median} |
| Score ≤ 2 (critical) | {count_weak} |
| Score = 3 (partial) | {count_partial} |
| Score ≥ 4 (strong) | {count_strong} |

## Scores by intent theme

| Theme | Avg score | Weakest query |
|-------|-----------|---------------|
| {theme_1} | {score} | "{query}" ({score}) |
| ... | ... | ... |

## Full score table

| # | Query | Score | Reason |
|---|-------|-------|--------|
| 1 | habit tracker | 4 | Clear category match; "gentle" differentiation absent |
| 2 | ... | ... | ... |
| ... | ... | ... | ... |
| 30 | ... | ... | ... |

## Critical gaps (score ≤ 2)

1. **"{query}"** — {score} — {why metadata fails}
2. ...

## Partial matches (score = 3)

1. **"{query}"** — {what metadata lacks}
2. ...

## Strengths (score ≥ 4)

1. **"{query}"** — {what metadata does well}
2. ...

## Recommendations

### 🔴 Title / Subtitle

| Current | Issue | Suggested alternative | Chars |
|---------|-------|----------------------|-------|
| Subtitle: `{current}` | Missing "gentle" intent | `{suggestion}` | {n}/30 |

### 🟡 Description

Add to **opening paragraph**:
> {suggested_sentence}

Add to **features section**:
> {suggested_bullet_or_sentence}

### 🟢 Keywords

Suggested additions (no title duplicates): `{comma_separated}`

## Next steps

- [ ] Apply title/subtitle changes in `metadata/app-info/{locale}.json`
- [ ] Apply description/keywords/promotional text in `metadata/version/{version}/{locale}.json`
- [ ] Re-run judge after changes to compare scores
- [ ] Repeat for next locale
