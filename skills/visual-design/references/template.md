# Template: DESIGN.md

Use this as the structural scaffold when creating any DESIGN.md. Replace all `[bracketed]` placeholders with real values. Remove any placeholder sections that don't apply, but aim to fill all 9 sections.

---

# Design System Inspiration of [Brand/Project Name]

## 1. Visual Theme & Atmosphere

[2-3 paragraphs describing the design philosophy, mood, and visual identity. Reference specific hex values inline in backticks. Describe what makes this design system distinctive — its personality, the feeling it evokes, the principles driving its aesthetic choices. Mention the primary font and signature color by name.]

[Second paragraph expanding on the visual approach — how light/dark balance works, what the shadow philosophy communicates, how typography choices reinforce the brand personality.]

**Key Characteristics:**
- [Distinctive trait 1 — e.g., "Custom variable font with geometric OpenType alternates"]
- [Distinctive trait 2 — e.g., "Weight 300 as signature headline weight for understated authority"]
- [Distinctive trait 3 — e.g., "Blue-tinted chromatic shadows instead of neutral gray"]
- [Distinctive trait 4 — e.g., "Deep navy (`#061b31`) headings instead of pure black"]
- [Distinctive trait 5 — e.g., "Conservative border-radius (4px-8px) for precision feel"]
- [Distinctive trait 6 — e.g., "Alternating light/dark section rhythm"]
- [Distinctive trait 7 — e.g., "Monospace companion font for code and data"]

## 2. Color Palette & Roles

### Primary
- **[Primary Color Name]** (`[#hex]`): [Role — e.g., "Primary brand color, CTA backgrounds, link text, interactive highlights"]
- **[Secondary Primary Name]** (`[#hex]`): [Role — e.g., "Primary heading color; dark warm neutral"]
- **[Tertiary Primary Name]** (`[#hex]`): [Role — e.g., "Page background, card surfaces, button text on primary"]

### Secondary & Accent
- **[Accent Color 1 Name]** (`[#hex]`): [Role and usage context]
- **[Accent Color 2 Name]** (`[#hex]`): [Role and usage context]
- **[Accent Light Name]** (`[#hex]`): [Role — tinted surface variant]

### Surface & Background
- **[Background Name]** (`[#hex]`): [Role — e.g., "Primary page background"]
- **[Surface Name]** (`[#hex]`): [Role — e.g., "Card and container background"]
- **[Elevated Surface Name]** (`[#hex]`): [Role — e.g., "Hover state backgrounds, subtle highlights"]

### Neutrals & Text
- **[Heading Text Name]** (`[#hex]`): [Role — primary headings and nav text]
- **[Label Text Name]** (`[#hex]`): [Role — form labels and secondary headings]
- **[Body Text Name]** (`[#hex]`): [Role — secondary text and descriptions]
- **[Muted Text Name]** (`[#hex]`): [Role — captions, timestamps, placeholder text]

### Semantic & Status
- **[Success Name]** (`[#hex]`): [Role — success indicators, positive actions]
- **[Warning Name]** (`[#hex]`): [Role — warnings, caution states]
- **[Error Name]** (`[#hex]`): [Role — errors, destructive actions]
- **[Info Name]** (`[#hex]`): [Role — informational highlights]

### Borders & Dividers
- **[Default Border Name]** (`[#hex]`): [Role — standard border for cards and containers]
- **[Active Border Name]** (`[#hex]`): [Role — selected/focused state borders]
- **[Subtle Border Name]** (`[#hex]`): [Role — dividers, light separators]

### Shadow Colors
- **[Primary Shadow Name]** (`[rgba value]`): [Role — primary branded shadow]
- **[Secondary Shadow Name]** (`[rgba value]`): [Role — secondary depth layer]
- **[Ambient Shadow Name]** (`[rgba value]`): [Role — soft ambient lift]

### Gradient System
- [Describe gradient patterns, e.g., "Linear gradient from `#ea2261` to `#f96bee` for hero decorations"]
- [Additional gradient if applicable]

## 3. Typography Rules

### Font Family
- **Primary**: `[font-name]` with fallback `[fallback-stack]`
- **Secondary**: `[font-name]` with fallback `[fallback-stack]` (if applicable)
- **Monospace**: `[font-name]` with fallback `[fallback-stack]` (if applicable)
- **OpenType Features**: [e.g., `"ss01"` globally, `"tnum"` for tabular numbers]

### Hierarchy

| Role | Font | Size | Weight | Line Height | Letter Spacing | Notes |
|------|------|------|--------|-------------|----------------|-------|
| Display Hero | [font] | [XX]px ([X.XX]rem) | [weight] | [X.XX] | [Xpx] | [notes] |
| Display Large | [font] | [XX]px ([X.XX]rem) | [weight] | [X.XX] | [Xpx] | |
| Section Heading | [font] | [XX]px ([X.XX]rem) | [weight] | [X.XX] | [Xpx] | |
| Sub-heading | [font] | [XX]px ([X.XX]rem) | [weight] | [X.XX] | [Xpx] | |
| Body Large | [font] | [XX]px ([X.XX]rem) | [weight] | [X.XX] | normal | |
| Body | [font] | [XX]px ([X.XX]rem) | [weight] | [X.XX] | normal | |
| Button | [font] | [XX]px ([X.XX]rem) | [weight] | [X.XX] | normal | |
| Link | [font] | [XX]px ([X.XX]rem) | [weight] | [X.XX] | normal | |
| Caption | [font] | [XX]px ([X.XX]rem) | [weight] | [X.XX] | normal | |
| Small / Micro | [font] | [XX]px ([X.XX]rem) | [weight] | [X.XX] | [Xpx] | |
| Code | [mono-font] | [XX]px ([X.XX]rem) | [weight] | [X.XX] | normal | |

### Principles
- [Principle 1 — e.g., "Light weight at display sizes for understated authority"]
- [Principle 2 — e.g., "Letter-spacing tightens progressively with size increases"]
- [Principle 3 — e.g., "Two-weight system: 300 for content, 400 for interactive elements"]
- [Principle 4 — e.g., "Monospace font reserved for code blocks and data tables"]

## 4. Component Stylings

### Buttons

**Primary CTA**
- Background: `[#hex]`
- Text: `[#hex]`
- Padding: [X]px [X]px
- Radius: [X]px
- Font: [X]px [font] weight [X]
- Hover: [hover treatment]
- Use: [when to use this variant]

**Secondary / Ghost**
- Background: transparent
- Text: `[#hex]`
- Padding: [X]px [X]px
- Radius: [X]px
- Border: `[border value]`
- Hover: [hover treatment]
- Use: [when to use]

**Tertiary / Subtle**
- Background: transparent or `[#hex]`
- Text: `[#hex]`
- Padding: [X]px [X]px
- Radius: [X]px
- Border: `[border value]`
- Use: [when to use]

### Cards & Containers
- Background: `[#hex]`
- Border: `[border value]`
- Radius: [X]px
- Shadow: `[full CSS shadow value]`
- Padding: [X]px
- [Additional card variants if applicable]

### Badges / Tags / Pills
**[Variant Name]**
- Background: `[#hex or rgba]`
- Text: `[#hex]`
- Padding: [X]px [X]px
- Radius: [X]px
- Border: `[border value]`
- Font: [X]px weight [X]

### Inputs & Forms
- Border: `[border value]`
- Radius: [X]px
- Focus: `[focus ring/border value]`
- Error: `[error state treatment]`
- Label: `[#hex]`, [X]px [font]
- Input Text: `[#hex]`
- Placeholder: `[#hex]`

### Navigation
- [Describe nav structure — horizontal/vertical, sticky behavior]
- Brand: [logo/logotype placement]
- Links: [X]px [font] weight [X], `[#hex]`
- CTA: [describe nav CTA treatment]
- Mobile: [hamburger/drawer/bottom nav]

### Image Treatment
- [Border-radius for images]
- [Shadow treatment]
- [Aspect ratio conventions]

### Distinctive Components
[Describe any unique components specific to this design system — code blocks, pricing cards, testimonial cards, feature grids, etc.]

## 5. Layout Principles

### Spacing System
- Base unit: [X]px
- Scale: [list the full spacing scale, e.g., "2px, 4px, 8px, 12px, 16px, 24px, 32px, 48px, 64px"]
- Component padding: [describe padding conventions]
- Section spacing: [describe vertical rhythm between sections]

### Grid & Container
- Max content width: [X]px
- Column count: [X] columns
- Gutter: [X]px
- Hero: [describe hero layout]
- Content sections: [describe typical section layouts]

### Whitespace Philosophy
- [Principle 1 — e.g., "Generous whitespace around headlines creates breathing room"]
- [Principle 2 — e.g., "Dense data packing with spacious chrome surroundings"]
- [Principle 3 — e.g., "Section padding increases with viewport width"]
- [Principle 4 — e.g., "Asymmetric padding — more top than bottom to create forward momentum"]

### Border Radius Scale

| Category | Radius | Use |
|----------|--------|-----|
| Micro | [X]px | [use case] |
| Subtle | [X]px | [use case] |
| Standard | [X]px | [use case] |
| Comfortable | [X]px | [use case] |
| Large | [X]px | [use case] |
| Pill | [X]px or 9999px | [use case] |
| Circle | 50% | [use case] |

## 6. Depth & Elevation

| Level | Treatment | Use |
|-------|-----------|-----|
| Flat (Level 0) | No shadow | [use case] |
| Subtle (Level 1) | `[shadow value]` | [use case] |
| Standard (Level 2) | `[shadow value]` | [use case] |
| Elevated (Level 3) | `[shadow value]` | [use case] |
| Deep (Level 4) | `[shadow value]` | [use case] |
| Focus Ring | `[outline/ring value]` | Keyboard accessibility |

**Shadow Philosophy**: [2-3 sentences about the shadow approach — are shadows warm/cool/neutral? Single or multi-layer? What mood do they create? How do they tie to the color palette?]

### Decorative Depth
- [Describe any non-shadow depth techniques — gradient overlays, dark sections, backdrop-filter, etc.]

## 7. Do's and Don'ts

### Do
- [Specific directive referencing actual values — e.g., "Use `#061b31` for headings instead of pure black"]
- [Directive 2]
- [Directive 3]
- [Directive 4]
- [Directive 5]
- [Directive 6]
- [Directive 7]

### Don't
- [Specific prohibition with reasoning — e.g., "Don't use weight 700 for headlines — the system relies on light weights"]
- [Prohibition 2]
- [Prohibition 3]
- [Prohibition 4]
- [Prohibition 5]
- [Prohibition 6]
- [Prohibition 7]

## 8. Responsive Behavior

### Breakpoints

| Name | Width | Key Changes |
|------|-------|-------------|
| Mobile Small | <[X]px | [changes] |
| Mobile | [X]-[X]px | [changes] |
| Tablet | [X]-[X]px | [changes] |
| Desktop | [X]-[X]px | [changes] |
| Large Desktop | >[X]px | [changes] |

### Touch Targets
- [Minimum size guideline]
- [Button padding on mobile]
- [Link spacing on mobile]
- [Interactive element guidelines]

### Collapsing Strategy
- [How hero adapts — font size changes]
- [How navigation adapts — hamburger/drawer]
- [How grids collapse — column count changes]
- [How spacing reduces]
- [How images behave]

### Image Behavior
- [Responsive image approach]
- [Shadow treatment at mobile sizes]
- [Aspect ratio handling]
- [Loading behavior]

## 9. Agent Prompt Guide

### Quick Color Reference
- Background: [Name] (`[#hex]`)
- Surface: [Name] (`[#hex]`)
- Primary: [Name] (`[#hex]`)
- Accent: [Name] (`[#hex]`)
- Heading text: [Name] (`[#hex]`)
- Body text: [Name] (`[#hex]`)
- Border: [Name] (`[#hex]`)
- Link: [Name] (`[#hex]`)
- Success: [Name] (`[#hex]`)
- Error: [Name] (`[#hex]`)

### Example Component Prompts
- "[Complete prompt for creating a hero section with specific values from this system]"
- "[Complete prompt for creating a card component with shadow, border, typography values]"
- "[Complete prompt for creating a badge/tag with exact colors, padding, radius]"
- "[Complete prompt for creating a navigation bar with font, color, layout values]"
- "[Complete prompt for creating a dark/branded section with background, text colors, card treatment]"

### Iteration Guide
1. [Step for establishing base tokens — fonts, colors]
2. [Step for typography scale]
3. [Step for shadows and elevation]
4. [Step for component tokens]
5. [Step for heading vs body color distinction]
6. [Step for data/number formatting]
7. [Step for dark/branded sections]
8. [Step for code/monospace treatment]
