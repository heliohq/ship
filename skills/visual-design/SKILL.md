---
name: visual-design
description: "Create DESIGN.md files — structured markdown visual design systems (colors, typography, spacing, components) that AI coding agents read to generate consistent UI. Use when the user mentions DESIGN.md, visual design, design system, design tokens, extracting a design from a website, or documenting UI tokens. Also triggers on 'make it look like [brand]', 'capture the design of [site]', 'extract design tokens'. Note: this is NOT for architectural design docs (use /ship:write-docs for those) or system design thinking (use /ship:arch-design for that)."
---

# Visual Design

Create production-quality DESIGN.md files following the **awesome-design-md** format — a 9-section markdown standard for describing visual design systems that AI agents (and Google Stitch) can read and faithfully reproduce.

A DESIGN.md is like AGENTS.md for visual identity: drop it in your project root and any AI coding agent generates UI that matches your design language. No Figma exports, no JSON schemas — just markdown.

## Three Modes

Determine which mode applies, then read the corresponding reference file for the full process.

### A. From Scratch

The user describes their vision — mood, colors, fonts, brand references. You explore the vision through structured discovery, propose 2-3 directions, and build the DESIGN.md incrementally with user validation at each stage.

**Read `references/from-scratch.md` for the full process.**

### B. From a Website URL

The user provides a URL and wants the site's design system captured. You clarify scope and intent, inspect the DOM for actual values, validate the extracted foundation with the user, and assemble the DESIGN.md.

**Read `references/from-url.md` for the full process.**

### C. From Current Codebase

The user has an existing project and wants a DESIGN.md extracted from the code. You discover the tech stack, systematically extract tokens, validate with the user, fill gaps, and document what the project actually looks like.

**Read `references/from-codebase.md` for the full process.**

## The 9-Section Format

Every DESIGN.md follows this exact structure. The H1 is always:

```
# Design System Inspiration of [Name]
```

Then 9 numbered H2 sections. See `references/template.md` for the full template with placeholders, and `references/section-guide.md` for detailed writing guidance.

| # | Section | What It Contains |
|---|---------|-----------------|
| 1 | Visual Theme & Atmosphere | 2-3 paragraphs of design philosophy + Key Characteristics bullet list |
| 2 | Color Palette & Roles | Colors grouped by role (Primary, Accent, Surface, Neutral, Semantic) |
| 3 | Typography Rules | Font families, hierarchy table, typographic principles |
| 4 | Component Stylings | Buttons, cards, inputs, navigation, badges, distinctive components |
| 5 | Layout Principles | Spacing system, grid, whitespace philosophy, border-radius scale |
| 6 | Depth & Elevation | Shadow levels table + shadow philosophy |
| 7 | Do's and Don'ts | 7-10 specific directives each, referencing actual values |
| 8 | Responsive Behavior | Breakpoints, touch targets, collapsing strategy |
| 9 | Agent Prompt Guide | Quick color reference, 5 example prompts, iteration guide |

## Formatting Conventions

These conventions make the file parseable by both humans and AI agents:

- **Hex codes** always in backticks: `` `#533afd` ``
- **RGBA values** in backticks: `` `rgba(50,50,93,0.25)` ``
- **Font names** in backticks: `` `sohne-var` ``
- **CSS values** in backticks: `` `0px 30px 45px -30px` ``
- **Metrics** in backticks: `` `8px` ``, `` `1.40` ``
- **Color names** in bold: **Stripe Purple**, **Deep Navy**
- **Size dual notation**: `56px (3.50rem)` — pixel with rem equivalent
- **Color entry format**: `- **Descriptive Name** (\`#hex\`): Role and usage context.`
- **Component property format**: `- Property: \`value\` (contextual note)`
- Tables use standard markdown pipe syntax
- No YAML frontmatter in the DESIGN.md output (the file is pure markdown)
- No code fences wrapping design content (fences only for inline CSS values)

## Quality Checklist

Before presenting the DESIGN.md, verify:

- [ ] H1 follows `# Design System Inspiration of [Name]`
- [ ] All 9 sections present and numbered
- [ ] Every color has a descriptive name, hex in backticks, and usage description
- [ ] Typography table has all columns: Role, Font, Size, Weight, Line Height, Letter Spacing
- [ ] At least 3 button variants documented (primary, secondary/ghost, tertiary)
- [ ] Shadow table has 4-6 levels with actual CSS values
- [ ] Do's and Don'ts reference specific hex values and measurements
- [ ] Section 9 has 5 concrete example component prompts with real values from the system
- [ ] Breakpoints table covers mobile through large desktop
- [ ] Colors are semantically grouped (not just listed)
- [ ] No orphan values — every color/token referenced in Section 9's Quick Reference appears in Section 2

## Generating Preview HTML

After completing the DESIGN.md, generate a companion `preview.html` — a self-contained HTML file that visually demonstrates the design system.

Read `references/preview-template.html` for the HTML scaffold. The preview should contain:

1. **Navigation bar** — brand name + CTA button in the design system's style
2. **Hero section** — headline and subtitle demonstrating the type scale
3. **Color palette** — swatches for every color in Section 2, labeled with name and hex
4. **Typography scale** — samples at each hierarchy level from Section 3
5. **Button variants** — all button styles from Section 4
6. **Card examples** — 2-3 cards with proper shadows and borders
7. **Form inputs** — default, focus, and error states
8. **Spacing scale** — visual representation of the spacing system
9. **Border radius** — examples at each scale value
10. **Elevation/shadows** — cards at each shadow level

The HTML must be fully self-contained (inline CSS, no external dependencies) and use CSS custom properties for all design tokens. Include a responsive media query so it renders well on mobile too.

If the design system has a dark mode or dark sections, also generate `preview-dark.html` with dark surface backgrounds.

## Execution Handoff

Output the report card:

```
## [Visual Design] Report Card

| Field | Value |
|-------|-------|
| Status | <DONE / BLOCKED> |
| Summary | DESIGN.md created via <mode: scratch / url / codebase> |

### Metrics
| Metric | Value |
|--------|-------|
| Mode | <From Scratch / From URL / From Codebase> |
| Sections completed | <N>/9 |
| Colors documented | <N> |
| Typography levels | <N> |
| Component variants | <N> |
| Preview generated | <yes / no> |
| Dark mode preview | <yes / no / n/a> |

### Artifacts
| File | Purpose |
|------|---------|
| DESIGN.md | Visual design system (9-section format) |
| preview.html | Self-contained HTML preview of the design system |
| preview-dark.html | Dark mode variant (if applicable) |
```

## Reference Files

Read these as needed — they contain the detailed templates, mode processes, and examples:

- **`references/from-scratch.md`** — Full process for creating a DESIGN.md from scratch through collaborative discovery.
- **`references/from-url.md`** — Full process for extracting a design system from a live website.
- **`references/from-codebase.md`** — Full process for reverse-engineering a design system from existing code.
- **`references/template.md`** — The complete 9-section template with fill-in placeholders. Read this when writing any DESIGN.md.
- **`references/section-guide.md`** — Deep guidance on what makes each section excellent. Read this for quality standards and common pitfalls.
- **`references/preview-template.html`** — HTML scaffold for the preview file. Read this when generating the preview.
