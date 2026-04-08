# Section Guide: Writing Excellent DESIGN.md Sections

This guide explains what makes each of the 9 sections great, with common pitfalls to avoid.

## Table of Contents
1. [Visual Theme & Atmosphere](#1-visual-theme--atmosphere)
2. [Color Palette & Roles](#2-color-palette--roles)
3. [Typography Rules](#3-typography-rules)
4. [Component Stylings](#4-component-stylings)
5. [Layout Principles](#5-layout-principles)
6. [Depth & Elevation](#6-depth--elevation)
7. [Do's and Don'ts](#7-dos-and-donts)
8. [Responsive Behavior](#8-responsive-behavior)
9. [Agent Prompt Guide](#9-agent-prompt-guide)

---

## 1. Visual Theme & Atmosphere

**Purpose:** Set the emotional and philosophical foundation. An AI agent reading this section should immediately understand the *vibe* — is it playful or serious? Minimal or rich? Technical or warm?

**What makes it excellent:**
- Specific, not vague. "Clean white foundation with deep navy headings" beats "professional and modern."
- References actual values inline: mention hex codes, font names, specific weight choices.
- Explains *why* choices work, not just what they are. "Weight 300 creates ethereal, almost whispered authority" tells the agent how to interpret the weight.
- The Key Characteristics bullet list is a scannable summary — 7-8 items, each a distinct trait.

**Common pitfalls:**
- Generic adjectives without substance ("sleek", "modern", "clean" with no specifics)
- No hex codes or font names — the atmosphere section should ground the abstract in the concrete
- Key Characteristics that repeat what the paragraphs say instead of distilling new traits

---

## 2. Color Palette & Roles

**Purpose:** Give every color a name, a code, and a job. An agent should be able to look up "what color do I use for body text?" and get an exact answer.

**What makes it excellent:**
- Every color has a **descriptive, evocative name** — not "Blue 1" but "Midnight Navy" or "Signal Green"
- Colors grouped semantically: Primary, Accent, Surface, Neutral, Semantic, Border, Shadow
- Each entry follows the format: `- **Name** (\`#hex\`): Role description`
- Role descriptions are specific: "Primary heading color; dark blue adding warmth" not just "used for headings"
- Includes RGBA values for shadows and semi-transparent colors
- Gradients described with full CSS notation
- Complete coverage: every color visible on the site should appear here

**Common pitfalls:**
- Missing shadow colors — shadows are part of the palette
- Vague role descriptions ("accent color" — accent for what?)
- Colors without names (just hex codes)
- Forgetting semi-transparent variants (hover states, overlays, backdrop-filter colors)
- Not including enough neutrals — most sites use 4-6 shades of gray/neutral

**Naming colors well:**
Good names hint at both the color and its personality:
- "Carbon Dark" (dark, industrial feel)
- "Frosted Glass" (light, transparent, cool)
- "Emerald Signal" (green, attention-grabbing)
- "Warm Sand" (beige, comfortable, organic)

Avoid: "Primary Blue", "Secondary Gray", "Color A"

---

## 3. Typography Rules

**Purpose:** Define the complete type system so an agent can render any text element correctly.

**What makes it excellent:**
- Font Family subsection lists the full fallback stack
- The Hierarchy table includes ALL columns: Role, Font, Size, Weight, Line Height, Letter Spacing, Notes
- Size uses dual notation: `56px (3.50rem)` for both px and rem
- Line height as decimal: `1.10`, `1.40` (not percentage)
- Letter spacing in pixels: `-1.4px`, `0px`, `normal`
- Roles cover the full range: from Display Hero down to Micro/Nano, plus Code variants
- The Principles subsection explains the *why* — not just "use weight 300" but "light weight at display sizes creates understated authority rather than conventional bold impact"
- Notes about OpenType features (ss01, tnum, liga) when relevant

**Common pitfalls:**
- Missing the code/monospace font — if the site has any code, document its type treatment
- Only documenting 3-4 roles when the actual system has 10+
- Line height as percentage instead of decimal
- Missing letter-spacing (especially negative tracking at large sizes — this is critical for display type)
- Not mentioning font-feature-settings when the font uses them

---

## 4. Component Stylings

**Purpose:** Give the agent exact recipes for building UI components.

**What makes it excellent:**
- Each button variant is a named recipe: Primary CTA, Ghost, Tertiary, etc.
- Properties listed as bullets with `Property: \`value\`` format
- Includes hover/focus states — these define the interaction feel
- Cards include background, border, radius, shadow, and padding — the full recipe
- Inputs document all states: default, focus, error, disabled
- Navigation describes the full structure: sticky behavior, link treatment, CTA placement, mobile adaptation
- Distinctive Components section captures anything unique to this design system

**Common pitfalls:**
- Only documenting one button variant (most systems have 3-4)
- Missing hover states — interaction design matters
- Not documenting focus rings/outlines (accessibility)
- Generic card descriptions without actual shadow values
- Forgetting badges/tags/pills — these are common and have specific treatments

---

## 5. Layout Principles

**Purpose:** Define the spatial system — how things are sized, spaced, and arranged.

**What makes it excellent:**
- Base unit declared (usually 4px or 8px)
- Full spacing scale listed (not just the base unit)
- Grid documented: max width, columns, gutter
- Border Radius Scale as a table: Micro, Subtle, Standard, Comfortable, Large, Pill, Circle
- Whitespace Philosophy explains the *feel* of spacing — dense vs airy, symmetric vs asymmetric

**Common pitfalls:**
- Listing only the base unit without the full scale
- Missing border-radius scale — this strongly defines visual personality (sharp vs round)
- No max content width — agents need this to constrain layouts

---

## 6. Depth & Elevation

**Purpose:** Define how elements appear to stack in z-space.

**What makes it excellent:**
- Table with exact columns: Level, Treatment, Use
- 4-6 levels from Flat through Deep, plus Focus Ring for accessibility
- Treatment column contains complete CSS shadow values in backticks
- Multi-layer shadows documented as-is: `rgba(50,50,93,0.25) 0px 30px 45px -30px, rgba(0,0,0,0.1) 0px 18px 36px -18px`
- Shadow Philosophy explains the aesthetic: chromatic vs neutral, tight vs diffuse, how shadows tie to the color palette

**Common pitfalls:**
- Generic "light shadow" / "medium shadow" without actual values
- Missing the focus ring level (accessibility requirement)
- Not explaining *why* the shadow approach was chosen
- Forgetting that shadow colors are part of the brand palette

---

## 7. Do's and Don'ts

**Purpose:** Guardrails that prevent an agent from going off-brand. The most actionable section.

**What makes it excellent:**
- 7-10 items per list
- Every item references specific values: "Use `#061b31` for headings instead of pure black"
- Don'ts explain *why not*: "Don't use large border-radius (12px+) — the system relies on subtle 4-8px curves for precision feel"
- Items cover typography, color, spacing, shadows, and components
- Items are non-obvious — don't just repeat what earlier sections say. Focus on the mistakes an agent would actually make without this guidance.

**Common pitfalls:**
- Vague directives: "Use consistent spacing" (this says nothing)
- No specific values referenced
- Don'ts without reasoning
- Repeating obvious rules from earlier sections

---

## 8. Responsive Behavior

**Purpose:** Define how the design adapts across screen sizes.

**What makes it excellent:**
- Breakpoints table covers 4-5 sizes with Key Changes column
- Touch Targets section ensures mobile usability (44px minimum, etc.)
- Collapsing Strategy describes how each major component adapts
- Image Behavior covers responsive images, shadow treatment at mobile

**Common pitfalls:**
- Only defining 2 breakpoints (need at least 4: mobile, tablet, desktop, large)
- Missing touch target minimums
- Not describing how navigation collapses
- No guidance on typography scaling across breakpoints

---

## 9. Agent Prompt Guide

**Purpose:** The cheat sheet. An agent should be able to read just this section and produce on-brand components.

**What makes it excellent:**
- Quick Color Reference: simple key-value list with the 10 most important colors
- 5 Example Component Prompts that are complete, copy-paste-ready instructions: "Create a dark card: #181818 background, 8px radius. Title at 16px weight 700, white text..."
- Each prompt includes specific pixel values, colors, weights, and spacing
- Iteration Guide: 6-8 numbered steps for getting from zero to on-brand

**Common pitfalls:**
- Quick Reference that lists every single color (defeats the purpose — pick the top 10)
- Example prompts that are vague: "make a nice card" (needs exact values)
- Iteration Guide that's too abstract
- Not including enough prompts (5 is the target: hero, card, badge, nav, dark section)

---

## General Writing Tips

1. **Be specific over generic.** Every value should be something an AI agent can directly apply to CSS. Prefer `rgba(50,50,93,0.25) 0px 30px 45px -30px` over "subtle blue shadow."

2. **Name everything.** Colors, elevation levels, spacing values, button variants. Named things are memorable and referenceable.

3. **Explain the why.** When a design choice is non-obvious, a sentence of reasoning helps the agent make good judgment calls in edge cases.

4. **Maintain internal consistency.** If Section 2 defines a color as "Midnight Navy," Section 7 and 9 should use that same name. If Section 3 says heading weight is 300, Section 4's button descriptions shouldn't randomly use 600.

5. **Test the Agent Prompt Guide.** Read Section 9 in isolation — could you build a component from just those prompts? If not, the prompts need more specifics.
