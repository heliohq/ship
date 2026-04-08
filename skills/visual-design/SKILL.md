---
name: visual-design
description: "Create DESIGN.md files — structured markdown visual design systems (colors, typography, spacing, components) that AI coding agents read to generate consistent UI. Use when the user mentions DESIGN.md, visual design, design system, design tokens, extracting a design from a website, or documenting UI tokens. Also triggers on 'make it look like [brand]', 'capture the design of [site]', 'extract design tokens'. Note: this is NOT for architectural design docs (use /ship:arch-design for those)."
---

# Write Design MD

Create production-quality DESIGN.md files following the **awesome-design-md** format — a 9-section markdown standard for describing visual design systems that AI agents (and Google Stitch) can read and faithfully reproduce.

A DESIGN.md is like AGENTS.md for visual identity: drop it in your project root and any AI coding agent generates UI that matches your design language. No Figma exports, no JSON schemas — just markdown.

## Three Workflows

### A. From Scratch

The user describes their design vision — mood, colors, fonts, brand references — and you produce a complete DESIGN.md.

**Process:**
1. Interview the user. Ask about: mood/atmosphere, primary and accent colors (or let them pick), font preferences, component styles (modern/classic, rounded/sharp), target audience.
2. If they reference a brand ("make it feel like Stripe but warmer"), internalize that sensibility but create original values — never copy another brand's exact hex codes or font stack.
3. Build all 9 sections. Read `references/template.md` for the exact structure and `references/section-guide.md` for detailed guidance on each section.
4. Generate the companion `preview.html` (and optionally `preview-dark.html`). Read `references/preview-template.html` for the HTML scaffold — fill in the design tokens from your DESIGN.md.
5. Present both files to the user.

### B. From a Website URL

The user provides a URL and wants the site's design system captured as a DESIGN.md.

**Process:**
1. Visit the site using browser tools. Take screenshots at desktop and mobile widths.
2. Inspect the DOM to extract actual values: use DevTools or inspection tools to pull exact hex codes, font families, font sizes, weights, line heights, letter spacing, border-radius values, box-shadow values, padding/margin patterns, and gradient definitions.
3. Name every color descriptively — not "Color 1" but "Midnight Navy" or "Signal Green". The name should evoke the color and hint at its role.
4. Build all 9 sections from what you observed. Where values aren't directly inspectable (like design philosophy), infer from the overall aesthetic.
5. Generate `preview.html` using the extracted tokens.
6. Present the result.

**Important for URL workflow:** Accuracy matters more than speed. Real design systems use specific values — `#0a0f1a` is different from `#000000`. Inspect elements rather than guessing. If the site uses a custom font, identify it precisely (check the CSS `font-family` stack). Capture actual shadow values from computed styles rather than approximating.

### C. From Current Codebase

The user has an existing project and wants a DESIGN.md extracted from the code that's already there. The design system is implicit in the CSS, components, and config files — your job is to make it explicit.

**Process:**
1. **Discover the tech stack.** Search the workspace for signals of the styling approach:
   - `tailwind.config.*` / `tailwind.css` — Tailwind CSS (most common in modern projects)
   - `theme.ts` / `theme.js` / `theme/` — custom theme objects (MUI, Chakra, styled-components)
   - `variables.css` / `_variables.scss` / `tokens.css` — CSS custom properties or Sass variables
   - `*.module.css` / `*.styled.ts` — CSS Modules or CSS-in-JS
   - `global.css` / `globals.css` / `app.css` — global stylesheets
   - `package.json` — check for UI framework deps (e.g., `@mui/material`, `@chakra-ui/react`, `shadcn`, `ant-design`, `@radix-ui`)

2. **Extract design tokens.** Read the files you found and systematically pull out:

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

3. **Fill the gaps.** Real codebases rarely have every design token explicitly defined — some values are inherited from framework defaults, some are scattered across component files. When you encounter gaps:
   - If using Tailwind with default config, note which default values are being used (e.g., Tailwind's default `slate` scale)
   - Scan 3-5 actual page/component files to observe the de facto patterns — what colors, spacings, and fonts appear most frequently?
   - Check for a running dev server — if the project has one, start it and use browser inspection to verify actual rendered values
   - Ask the user if unsure about intentional vs accidental choices ("I see both `rounded-lg` and `rounded-xl` on cards — is there a distinction or should I standardize?")

4. **Name and organize.** Transform raw token values into the 9-section format:
   - Give every color a descriptive name that reflects its role, not its Tailwind class name. `bg-slate-900` becomes **Ink Black** (`#0f172a`): "Primary background for dark surfaces"
   - Group by semantic role, not by source file
   - Document the actual values being used, not what the config *could* support

5. **Build the DESIGN.md and preview.** Follow the same 9-section structure and generate `preview.html`.

6. **Present with a diff summary.** Show the user what you found and any gaps or inconsistencies:
   - "Your codebase uses 14 distinct colors. 3 appear to be unused in the theme config."
   - "I found two different shadow patterns — `shadow-sm` on cards and a custom `shadow-card` in globals.css. I documented both."
   - "No explicit breakpoints defined — I used Tailwind defaults (sm/md/lg/xl/2xl)."

**Important for codebase workflow:** The goal is to document what the project *actually* looks like, not what it *could* look like. Prefer observed values over config defaults. If a Tailwind config extends `colors.blue` but no component uses `blue-*` classes, don't include it. Conversely, if components use hardcoded `#1a1a2e` that isn't in the config, document it — that's a real design token whether or not it's formalized.

**Handling framework-specific patterns:**
- **Tailwind + shadcn/ui:** The definitive source of truth is usually `globals.css` (CSS variables in `:root` and `.dark`) plus `tailwind.config.*`. shadcn components consume these variables, so read the variables first, then check a few components for how they're used.
- **MUI / Chakra / Mantine:** Read the `createTheme()` / `extendTheme()` call. The theme object maps directly to DESIGN.md sections (palette → Section 2, typography → Section 3, spacing → Section 5, shadows → Section 6).
- **Plain CSS / Sass:** Grep broadly for color values (`#[0-9a-fA-F]{3,8}`, `rgb(`, `hsl(`), font declarations, and shadow values. Deduplicate and organize by frequency of use.
- **CSS-in-JS (styled-components, emotion):** Look for a theme provider and its theme object, plus any `css` tagged templates with hardcoded values.

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
