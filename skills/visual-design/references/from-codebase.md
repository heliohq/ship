# Mode C: From Current Codebase

Reverse-engineer the implicit design system from existing code — make explicit what's already there through systematic extraction, user validation, and structured documentation.

## Checklist — complete in order

1. **Clarify scope** — understand what parts of the codebase to extract from
2. **Discover the tech stack** — find where design tokens live
3. **Extract design tokens** — systematically pull colors, typography, spacing, shadows, radii, components
4. **Present extracted foundation** — show palette + typography for validation before writing all 9 sections
5. **Resolve ambiguities** — ask about inconsistencies and intentional vs accidental choices
6. **Fill gaps** — handle framework defaults, undeclared tokens, and missing values
7. **Build DESIGN.md + preview.html** — only after foundation is validated
8. **Quality gate** — run the Quality Checklist, present with diff summary for final approval

## Clarifying scope

Before scanning files, ask **one scoping question** if the answer isn't obvious from context:

- **Monorepo / multi-app** — "This repo has a marketing site and a dashboard app — should I document both as one system, or focus on one?"
- **Partial extraction** — "Should I document the whole app's design, or just the component library / a specific area?"
- **Intent** — "Are you documenting what exists (warts and all), or creating a cleaned-up target design system?" This changes whether inconsistencies are preserved or resolved.

If the project is a single app with one styling approach, skip to discovery.

## Discovering the tech stack

Search the workspace for signals of the styling approach:
- `tailwind.config.*` / `tailwind.css` — Tailwind CSS (most common in modern projects)
- `theme.ts` / `theme.js` / `theme/` — custom theme objects (MUI, Chakra, styled-components)
- `variables.css` / `_variables.scss` / `tokens.css` — CSS custom properties or Sass variables
- `*.module.css` / `*.styled.ts` — CSS Modules or CSS-in-JS
- `global.css` / `globals.css` / `app.css` — global stylesheets
- `package.json` — check for UI framework deps (e.g., `@mui/material`, `@chakra-ui/react`, `shadcn`, `ant-design`, `@radix-ui`)

## Extracting design tokens

Read the files you found and systematically pull out:

### Colors
- Tailwind: read the `extend.colors` block in `tailwind.config.*`, also check for CSS variable definitions in `globals.css` / `app.css` (e.g., `--primary: 222.2 47.4% 11.2%` in HSL notation — convert to hex)
- Theme objects: read the `colors` / `palette` keys
- CSS variables: grep for `--color-`, `--bg-`, `--text-`, `--border-` patterns
- Sass: grep for `$color-`, `$bg-`, `$brand-` patterns
- If colors are defined as HSL (`hsl(222.2, 47.4%, 11.2%)`), Oklch, or other formats, convert them to hex for the DESIGN.md

### Typography
- Tailwind: `extend.fontFamily`, also check `@import` or `<link>` tags for Google Fonts / local font files
- Look for `font-size`, `line-height`, `letter-spacing`, `font-weight` patterns in CSS or theme config
- Check `layout.tsx` / `_app.tsx` / `index.html` for `<link>` font imports or Next.js `next/font` usage
- Read actual component files to see which font sizes are used in practice (h1, h2, body, caption patterns)

### Spacing & Layout
- Tailwind: `extend.spacing`, check for `container` config, common padding/margin classes used across components
- Theme objects: `spacing` / `space` keys
- CSS: grep for repeated `padding`, `margin`, `gap` values to identify the implicit scale

### Shadows & Elevation
- Tailwind: `extend.boxShadow`
- CSS: grep for `box-shadow` declarations
- Theme objects: `shadows` / `elevation` keys

### Border Radius
- Tailwind: `extend.borderRadius`
- CSS: grep for `border-radius` patterns to find the actual scale in use

### Components
- Read a few representative component files (buttons, cards, inputs, navigation) to see how tokens are applied in practice
- Look for component libraries: if using shadcn/ui, check `components/ui/button.tsx`, `components/ui/card.tsx`, etc.
- For MUI/Chakra, the theme object contains component overrides

## Presenting the extracted foundation

Before writing all 9 sections, present the **extracted palette and typography** for validation:

1. **Extracted palette** — list every color found, grouped by role. Name each one descriptively (not the Tailwind class name). Note which are from config vs hardcoded in components. Ask: "Does this capture your project's colors? Anything missing or wrong?"
2. **Extracted typography** — font families, size hierarchy, weight usage. Ask: "Does this look right?"

This catches errors early — e.g., extracting unused config colors that aren't actually in the UI, or missing hardcoded values that bypass the theme.

## Resolving ambiguities

Real codebases are messy. When you encounter inconsistencies, **ask rather than assume**:

- "I see both `rounded-lg` and `rounded-xl` on cards — is there a distinction or should I standardize?"
- "The theme defines `colors.blue` but no component uses `blue-*` classes — should I include it or leave it out?"
- "I found 3 different `box-shadow` values across components — are these intentional elevation levels or drift?"

## Filling gaps

Real codebases rarely have every design token explicitly defined — some values are inherited from framework defaults, some are scattered across component files:

- If using Tailwind with default config, note which default values are being used (e.g., Tailwind's default `slate` scale)
- Scan 3-5 actual page/component files to observe the de facto patterns — what colors, spacings, and fonts appear most frequently?
- Check for a running dev server — if the project has one, start it and use browser inspection to verify actual rendered values
- Where values are completely absent (e.g., no explicit breakpoints), document the framework defaults in use and note them as inherited

## After validation — writing the DESIGN.md

- Read `references/template.md` for the exact 9-section structure
- Read `references/section-guide.md` for quality standards per section
- Name and organize: give every color a descriptive name that reflects its role, not its Tailwind class name. `bg-slate-900` becomes **Ink Black** (`#0f172a`): "Primary background for dark surfaces"
- Group by semantic role, not by source file
- Document the actual values being used, not what the config *could* support
- Generate the companion `preview.html` using `references/preview-template.html`
- Run the Quality Checklist (defined in SKILL.md) before presenting

**Present with a diff summary** — show the user what you found and any gaps or inconsistencies:
- "Your codebase uses 14 distinct colors. 3 appear to be unused in the theme config."
- "I found two different shadow patterns — `shadow-sm` on cards and a custom `shadow-card` in globals.css. I documented both."
- "No explicit breakpoints defined — I used Tailwind defaults (sm/md/lg/xl/2xl)."

## Handling framework-specific patterns

- **Tailwind + shadcn/ui:** The definitive source of truth is usually `globals.css` (CSS variables in `:root` and `.dark`) plus `tailwind.config.*`. shadcn components consume these variables, so read the variables first, then check a few components for how they're used.
- **MUI / Chakra / Mantine:** Read the `createTheme()` / `extendTheme()` call. The theme object maps directly to DESIGN.md sections (palette → Section 2, typography → Section 3, spacing → Section 5, shadows → Section 6).
- **Plain CSS / Sass:** Grep broadly for color values (`#[0-9a-fA-F]{3,8}`, `rgb(`, `hsl(`), font declarations, and shadow values. Deduplicate and organize by frequency of use.
- **CSS-in-JS (styled-components, emotion):** Look for a theme provider and its theme object, plus any `css` tagged templates with hardcoded values.

## Key principles

- **Document reality, not potential** — prefer observed values over config defaults; if a color is defined but never used, leave it out
- **Validate the foundation** — palette and typography are the highest-leverage checkpoints; get sign-off before writing 9 sections
- **Ask about inconsistencies** — the user knows which are intentional design choices and which are drift
- **Name semantically** — `bg-slate-900` is a Tailwind class; **Ink Black** is a design token
- **Note the provenance** — in the diff summary, distinguish between explicit config values, observed-in-components values, and inherited framework defaults
