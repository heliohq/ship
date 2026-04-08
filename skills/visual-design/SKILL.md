---
name: visual-design
description: "Create DESIGN.md files — structured markdown visual design systems (colors, typography, spacing, components) that AI coding agents read to generate consistent UI. Use when the user mentions DESIGN.md, visual design, design system, design tokens, extracting a design from a website, or documenting UI tokens. Also triggers on 'make it look like [brand]', 'capture the design of [site]', 'extract design tokens'. Note: this is NOT for architectural design docs (use /ship:arch-design for those)."
---

# Write Design MD

Create production-quality DESIGN.md files following the **awesome-design-md** format — a 9-section markdown standard for describing visual design systems that AI agents (and Google Stitch) can read and faithfully reproduce.

A DESIGN.md is like AGENTS.md for visual identity: drop it in your project root and any AI coding agent generates UI that matches your design language. No Figma exports, no JSON schemas — just markdown.

## Three Modes

### A. From Scratch

Collaborative design exploration — turn a vague vision into a complete DESIGN.md through structured discovery and incremental validation.

<HARD-GATE>
Do NOT write the DESIGN.md until you have explored the user's vision, proposed design directions, and received approval on the overall direction. A "simple" design system is where unexamined assumptions cause the most wasted iteration. The discovery can be brief for clear visions, but you MUST present a direction and get approval.
</HARD-GATE>

**Checklist — complete in order:**

1. **Explore project context** — check existing files (CSS, theme configs, package.json) for constraints
2. **Offer visual companion** — if the project has a dev server or you can serve preview.html, offer to show live previews as you iterate (this is its own message, not combined with a question)
3. **Discovery questions** — one at a time, understand the design vision
4. **Propose 2-3 design directions** — with trade-offs and your recommendation
5. **Present design incrementally** — core sections first, get feedback before completing all 9
6. **Write DESIGN.md + preview.html** — only after direction is validated
7. **Quality gate** — run the Quality Checklist, then present for final approval

**Discovery — understanding the vision:**

- Check the project first — existing colors, fonts, or framework choices are constraints, not blank-slate decisions
- Ask questions **one at a time** to refine the vision
- Prefer **multiple choice** when possible — easier to answer than open-ended
- Focus on these dimensions (in roughly this order):

  1. **Mood & atmosphere** — "Which best describes the feel you want?" (minimal/clean, warm/approachable, bold/energetic, premium/sophisticated, playful/creative)
  2. **Light or dark** — light background, dark background, or both?
  3. **Color direction** — any brand colors already decided? Warm or cool palette? Specific colors they love or hate?
  4. **Typography feel** — geometric/modern (Inter, DM Sans) vs humanist/warm (Source Sans, Nunito) vs editorial/distinctive (Playfair, Fraunces)? Serif or sans-serif headings?
  5. **Component style** — sharp corners or rounded? Dense or airy? Flat or elevated (shadows)?
  6. **Target audience & platform** — developer tool, consumer app, marketing site, dashboard?
  7. **References** — any sites or brands they admire? ("Make it feel like Stripe but warmer")

- If they reference a brand, internalize the sensibility but create original values — never copy another brand's exact hex codes or font stack
- If the vision is already crystal clear ("I want exactly the Linear aesthetic but with green as primary"), you can compress discovery to 2-3 confirming questions

**Exploring directions:**

- Once you understand the vision, propose **2-3 design directions** with distinct personalities
- For each direction, describe: color mood (with example hex), typography approach, component style, and the overall feel
- Lead with your recommendation and explain why it fits their stated goals
- Example: "Direction A: *Midnight Professional* — dark navy surfaces, weight-300 headings, subtle chromatic shadows. Direction B: *Warm Editorial* — cream backgrounds, serif headings, generous whitespace. I'd recommend A because you mentioned wanting a developer-tool feel."

**Presenting the design incrementally:**

- After the user picks a direction, build the design section by section
- Present the **foundation sections first** and get feedback before completing all 9:
  - **Section 2 (Colors)** — present the full palette with names and roles. This is the highest-impact decision. Get approval before proceeding.
  - **Section 3 (Typography)** — font choices, hierarchy table. Get approval.
  - **Sections 4-6 (Components, Layout, Elevation)** — present together as the "component layer." Get approval.
  - **Sections 1, 7-9 (Atmosphere, Do's/Don'ts, Responsive, Agent Guide)** — complete after the core is validated.
- Scale each presentation to its complexity — a few sentences if straightforward, detailed walkthrough if nuanced
- Be ready to go back and revise. "The blues feel too cold" means revisiting Section 2 before continuing.

**Visual companion:**

When you anticipate that visual feedback would help the user evaluate choices (color palettes, typography pairings, component styles), offer to show a live preview:

> "I can generate a live preview as we go so you can see how colors, fonts, and components look together. Want me to open a preview in your browser?"

This offer MUST be its own message — do not combine with other questions. If they accept:
- Generate `preview.html` early with the foundation tokens (even before all 9 sections are complete)
- Update the preview as you iterate on sections
- Use `references/preview-template.html` as the scaffold

If they decline, proceed with text-only descriptions.

**After validation — writing the DESIGN.md:**

- Read `references/template.md` for the exact 9-section structure
- Read `references/section-guide.md` for quality standards per section
- Generate the companion `preview.html` (and optionally `preview-dark.html`) using `references/preview-template.html`
- Run the Quality Checklist before presenting the final result
- Present both files to the user for final approval

**Key principles:**

- **One question at a time** — don't overwhelm with a wall of questions
- **Multiple choice preferred** — "Which of these 3 palettes?" beats "What colors do you want?"
- **Show, don't describe** — if visual companion is available, show a palette swatch instead of listing 10 hex codes
- **Foundation first** — colors and typography define 80% of the feel; get those right before detailing components
- **Be opinionated** — always lead with your recommendation; the user hired a design system, not a menu
- **Revise willingly** — going back to fix the palette after seeing components is normal, not failure

### B. From a Website URL

Extract a real site's design system into a DESIGN.md through systematic inspection, user validation, and incremental assembly.

**Checklist — complete in order:**

1. **Clarify scope and intent** — understand what pages to inspect and how the output will be used
2. **Inspect the site** — extract actual values from the DOM, not guesses
3. **Present extracted foundation** — show palette + typography for validation before writing all 9 sections
4. **Resolve ambiguities** — ask about inconsistencies, not assume
5. **Build DESIGN.md + preview.html** — only after foundation is validated
6. **Quality gate** — run the Quality Checklist, then present for final approval

**Clarifying scope and intent:**

Before opening the browser, ask **two quick questions** (can be combined in one message):

1. **Scope** — "Which pages should I extract from?" The homepage alone? The dashboard? Docs? Pricing page? Different pages on the same site can have noticeably different design treatments. If the user says "the whole site," focus on the homepage + one inner page and note where they diverge.
2. **Intent** — "How will you use this DESIGN.md?" This changes what you capture:
   - *Recreating the look* → extract exact values, maximize fidelity
   - *Taking inspiration* → capture the spirit and key tokens, note where you'd recommend departing
   - *Building something similar but distinct* → extract the system's structure and proportions, but flag values the user should customize

If the user's intent is clear from context ("capture the design of stripe.com for our project"), you can compress to one confirming question.

**Inspecting the site:**

- Visit the site using browser tools. Take screenshots at **desktop and mobile** widths.
- Inspect the DOM to extract **actual values** — don't guess from screenshots:
  - **Colors**: exact hex codes from computed styles (not approximations)
  - **Typography**: font families (full `font-family` stack from CSS), sizes, weights, line heights, letter spacing
  - **Spacing**: padding/margin patterns on key elements (nav, hero, cards, sections)
  - **Borders**: border-radius values, border colors
  - **Shadows**: exact `box-shadow` computed values (multi-layer shadows are common)
  - **Gradients**: full CSS gradient definitions
- If the site uses a custom font, identify it precisely — check the CSS `font-family` stack, look for `@font-face` declarations or Google Fonts / Typekit links
- Accuracy matters more than speed. `#0a0f1a` is different from `#000000`. Inspect rather than eyeball.

**Presenting the extracted foundation:**

Before writing all 9 sections, present the **two highest-impact extractions** for validation:

1. **Extracted palette** — list every color you found, grouped by role (primary, surface, text, semantic, border, shadow). Name each one descriptively. Ask: "Does this capture the site's palette, or did I miss/misidentify anything?"
2. **Extracted typography** — font families, the hierarchy of sizes you observed, weights used. Ask: "Does this look right?"

This catches misidentifications early — e.g., confusing a hover-state color with the primary, or missing a secondary font used only in the hero.

**Resolving ambiguities:**

Real sites are messy. When you encounter inconsistencies, **ask rather than assume**:

- "I found 8 different gray shades — should I document all of them, or consolidate to the 4-5 most prominent?"
- "The hero uses `Inter` but the blog uses `Georgia` — should I document both as part of the system, or treat one as the primary?"
- "Cards on the homepage have `box-shadow: 0 4px 6px rgba(0,0,0,0.1)` but the pricing page uses `0 25px 50px rgba(0,0,0,0.25)` — are these two elevation levels, or an inconsistency?"

For values that aren't directly inspectable (design philosophy, the *why* behind choices), infer from the overall aesthetic but mark these as your interpretation.

**After validation — writing the DESIGN.md:**

- Read `references/template.md` for the exact 9-section structure
- Read `references/section-guide.md` for quality standards per section
- Name every color descriptively — not "Color 1" but "Midnight Navy" or "Signal Green". The name should evoke the color and hint at its role.
- Generate the companion `preview.html` using `references/preview-template.html`
- Run the Quality Checklist before presenting the final result
- Present both files to the user for final approval

**Key principles:**

- **Inspect, don't guess** — computed styles over eyeballed approximations
- **Validate the foundation** — palette and typography are the highest-leverage checkpoints; get sign-off before writing 9 sections
- **Ask about ambiguity** — real sites have inconsistencies; the user knows which are intentional
- **Name everything** — descriptive color names make the DESIGN.md usable; "Stripe Purple" beats "#635bff"
- **Match the intent** — exact extraction for recreation, interpreted extraction for inspiration

### C. From Current Codebase

Reverse-engineer the implicit design system from existing code — make explicit what's already there through systematic extraction, user validation, and structured documentation.

**Checklist — complete in order:**

1. **Clarify scope** — understand what parts of the codebase to extract from
2. **Discover the tech stack** — find where design tokens live
3. **Extract design tokens** — systematically pull colors, typography, spacing, shadows, radii, components
4. **Present extracted foundation** — show palette + typography for validation before writing all 9 sections
5. **Resolve ambiguities** — ask about inconsistencies and intentional vs accidental choices
6. **Fill gaps** — handle framework defaults, undeclared tokens, and missing values
7. **Build DESIGN.md + preview.html** — only after foundation is validated
8. **Quality gate** — run the Quality Checklist, present with diff summary for final approval

**Clarifying scope:**

Before scanning files, ask **one scoping question** if the answer isn't obvious from context:

- **Monorepo / multi-app** — "This repo has a marketing site and a dashboard app — should I document both as one system, or focus on one?"
- **Partial extraction** — "Should I document the whole app's design, or just the component library / a specific area?"
- **Intent** — "Are you documenting what exists (warts and all), or creating a cleaned-up target design system?" This changes whether inconsistencies are preserved or resolved.

If the project is a single app with one styling approach, skip to discovery.

**Discovering the tech stack:**

Search the workspace for signals of the styling approach:
- `tailwind.config.*` / `tailwind.css` — Tailwind CSS (most common in modern projects)
- `theme.ts` / `theme.js` / `theme/` — custom theme objects (MUI, Chakra, styled-components)
- `variables.css` / `_variables.scss` / `tokens.css` — CSS custom properties or Sass variables
- `*.module.css` / `*.styled.ts` — CSS Modules or CSS-in-JS
- `global.css` / `globals.css` / `app.css` — global stylesheets
- `package.json` — check for UI framework deps (e.g., `@mui/material`, `@chakra-ui/react`, `shadcn`, `ant-design`, `@radix-ui`)

**Extracting design tokens:**

Read the files you found and systematically pull out:

**Colors:**
- Tailwind: read the `extend.colors` block in `tailwind.config.*`, also check for CSS variable definitions in `globals.css` / `app.css` (e.g., `--primary: 222.2 47.4% 11.2%` in HSL notation — convert to hex)
- Theme objects: read the `colors` / `palette` keys
- CSS variables: grep for `--color-`, `--bg-`, `--text-`, `--border-` patterns
- Sass: grep for `$color-`, `$bg-`, `$brand-` patterns
- If colors are defined as HSL (`hsl(222.2, 47.4%, 11.2%)`), Oklch, or other formats, convert them to hex for the DESIGN.md

**Typography:**
- Tailwind: `extend.fontFamily`, also check `@import` or `<link>` tags for Google Fonts / local font files
- Look for `font-size`, `line-height`, `letter-spacing`, `font-weight` patterns in CSS or theme config
- Check `layout.tsx` / `_app.tsx` / `index.html` for `<link>` font imports or Next.js `next/font` usage
- Read actual component files to see which font sizes are used in practice (h1, h2, body, caption patterns)

**Spacing & Layout:**
- Tailwind: `extend.spacing`, check for `container` config, common padding/margin classes used across components
- Theme objects: `spacing` / `space` keys
- CSS: grep for repeated `padding`, `margin`, `gap` values to identify the implicit scale

**Shadows & Elevation:**
- Tailwind: `extend.boxShadow`
- CSS: grep for `box-shadow` declarations
- Theme objects: `shadows` / `elevation` keys

**Border Radius:**
- Tailwind: `extend.borderRadius`
- CSS: grep for `border-radius` patterns to find the actual scale in use

**Components:**
- Read a few representative component files (buttons, cards, inputs, navigation) to see how tokens are applied in practice
- Look for component libraries: if using shadcn/ui, check `components/ui/button.tsx`, `components/ui/card.tsx`, etc.
- For MUI/Chakra, the theme object contains component overrides

**Presenting the extracted foundation:**

Before writing all 9 sections, present the **extracted palette and typography** for validation:

1. **Extracted palette** — list every color found, grouped by role. Name each one descriptively (not the Tailwind class name). Note which are from config vs hardcoded in components. Ask: "Does this capture your project's colors? Anything missing or wrong?"
2. **Extracted typography** — font families, size hierarchy, weight usage. Ask: "Does this look right?"

This catches errors early — e.g., extracting unused config colors that aren't actually in the UI, or missing hardcoded values that bypass the theme.

**Resolving ambiguities:**

Real codebases are messy. When you encounter inconsistencies, **ask rather than assume**:

- "I see both `rounded-lg` and `rounded-xl` on cards — is there a distinction or should I standardize?"
- "The theme defines `colors.blue` but no component uses `blue-*` classes — should I include it or leave it out?"
- "I found 3 different `box-shadow` values across components — are these intentional elevation levels or drift?"

**Filling gaps:**

Real codebases rarely have every design token explicitly defined — some values are inherited from framework defaults, some are scattered across component files:

- If using Tailwind with default config, note which default values are being used (e.g., Tailwind's default `slate` scale)
- Scan 3-5 actual page/component files to observe the de facto patterns — what colors, spacings, and fonts appear most frequently?
- Check for a running dev server — if the project has one, start it and use browser inspection to verify actual rendered values
- Where values are completely absent (e.g., no explicit breakpoints), document the framework defaults in use and note them as inherited

**After validation — writing the DESIGN.md:**

- Read `references/template.md` for the exact 9-section structure
- Read `references/section-guide.md` for quality standards per section
- Name and organize: give every color a descriptive name that reflects its role, not its Tailwind class name. `bg-slate-900` becomes **Ink Black** (`#0f172a`): "Primary background for dark surfaces"
- Group by semantic role, not by source file
- Document the actual values being used, not what the config *could* support
- Generate the companion `preview.html` using `references/preview-template.html`
- Run the Quality Checklist before presenting

**Present with a diff summary** — show the user what you found and any gaps or inconsistencies:
- "Your codebase uses 14 distinct colors. 3 appear to be unused in the theme config."
- "I found two different shadow patterns — `shadow-sm` on cards and a custom `shadow-card` in globals.css. I documented both."
- "No explicit breakpoints defined — I used Tailwind defaults (sm/md/lg/xl/2xl)."

**Handling framework-specific patterns:**
- **Tailwind + shadcn/ui:** The definitive source of truth is usually `globals.css` (CSS variables in `:root` and `.dark`) plus `tailwind.config.*`. shadcn components consume these variables, so read the variables first, then check a few components for how they're used.
- **MUI / Chakra / Mantine:** Read the `createTheme()` / `extendTheme()` call. The theme object maps directly to DESIGN.md sections (palette → Section 2, typography → Section 3, spacing → Section 5, shadows → Section 6).
- **Plain CSS / Sass:** Grep broadly for color values (`#[0-9a-fA-F]{3,8}`, `rgb(`, `hsl(`), font declarations, and shadow values. Deduplicate and organize by frequency of use.
- **CSS-in-JS (styled-components, emotion):** Look for a theme provider and its theme object, plus any `css` tagged templates with hardcoded values.

**Key principles:**

- **Document reality, not potential** — prefer observed values over config defaults; if a color is defined but never used, leave it out
- **Validate the foundation** — palette and typography are the highest-leverage checkpoints; get sign-off before writing 9 sections
- **Ask about inconsistencies** — the user knows which are intentional design choices and which are drift
- **Name semantically** — `bg-slate-900` is a Tailwind class; **Ink Black** is a design token
- **Note the provenance** — in the diff summary, distinguish between explicit config values, observed-in-components values, and inherited framework defaults

## The 9-Section Format

Every DESIGN.md follows this exact structure. The H1 is always:

```
# Design System Inspiration of [Name]
```

Then 9 numbered H2 sections. Here's the overview — see `references/template.md` for the full template with placeholders, and `references/section-guide.md` for detailed writing guidance.

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

## Reference Files

Read these as needed — they contain the detailed templates and examples:

- **`references/template.md`** — The complete 9-section template with fill-in placeholders. Read this when writing any DESIGN.md.
- **`references/section-guide.md`** — Deep guidance on what makes each section excellent. Read this for quality standards and common pitfalls.
- **`references/preview-template.html`** — HTML scaffold for the preview file. Read this when generating the preview.
