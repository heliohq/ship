# Mode B: From a Website URL

Extract a real site's design system into a DESIGN.md through systematic inspection, user validation, and incremental assembly.

## Checklist — complete in order

1. **Clarify scope and intent** — understand what pages to inspect and how the output will be used
2. **Inspect the site** — extract actual values from the DOM, not guesses
3. **Present extracted foundation** — show palette + typography for validation before writing all 9 sections
4. **Resolve ambiguities** — ask about inconsistencies, not assume
5. **Build DESIGN.md + preview.html** — only after foundation is validated
6. **Quality gate** — run the Quality Checklist, then present for final approval

## Clarifying scope and intent

Before opening the browser, ask **two quick questions** (can be combined in one message):

1. **Scope** — "Which pages should I extract from?" The homepage alone? The dashboard? Docs? Pricing page? Different pages on the same site can have noticeably different design treatments. If the user says "the whole site," focus on the homepage + one inner page and note where they diverge.
2. **Intent** — "How will you use this DESIGN.md?" This changes what you capture:
   - *Recreating the look* → extract exact values, maximize fidelity
   - *Taking inspiration* → capture the spirit and key tokens, note where you'd recommend departing
   - *Building something similar but distinct* → extract the system's structure and proportions, but flag values the user should customize

If the user's intent is clear from context ("capture the design of stripe.com for our project"), you can compress to one confirming question.

## Inspecting the site

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

## Presenting the extracted foundation

Before writing all 9 sections, present the **two highest-impact extractions** for validation:

1. **Extracted palette** — list every color you found, grouped by role (primary, surface, text, semantic, border, shadow). Name each one descriptively. Ask: "Does this capture the site's palette, or did I miss/misidentify anything?"
2. **Extracted typography** — font families, the hierarchy of sizes you observed, weights used. Ask: "Does this look right?"

This catches misidentifications early — e.g., confusing a hover-state color with the primary, or missing a secondary font used only in the hero.

## Resolving ambiguities

Real sites are messy. When you encounter inconsistencies, **ask rather than assume**:

- "I found 8 different gray shades — should I document all of them, or consolidate to the 4-5 most prominent?"
- "The hero uses `Inter` but the blog uses `Georgia` — should I document both as part of the system, or treat one as the primary?"
- "Cards on the homepage have `box-shadow: 0 4px 6px rgba(0,0,0,0.1)` but the pricing page uses `0 25px 50px rgba(0,0,0,0.25)` — are these two elevation levels, or an inconsistency?"

For values that aren't directly inspectable (design philosophy, the *why* behind choices), infer from the overall aesthetic but mark these as your interpretation.

## After validation — writing the DESIGN.md

- Read `references/template.md` for the exact 9-section structure
- Read `references/section-guide.md` for quality standards per section
- Name every color descriptively — not "Color 1" but "Midnight Navy" or "Signal Green". The name should evoke the color and hint at its role.
- Generate the companion `preview.html` using `references/preview-template.html`
- Run the Quality Checklist (defined in SKILL.md) before presenting the final result
- Present both files to the user for final approval

## Key principles

- **Inspect, don't guess** — computed styles over eyeballed approximations
- **Validate the foundation** — palette and typography are the highest-leverage checkpoints; get sign-off before writing 9 sections
- **Ask about ambiguity** — real sites have inconsistencies; the user knows which are intentional
- **Name everything** — descriptive color names make the DESIGN.md usable; "Stripe Purple" beats "#635bff"
- **Match the intent** — exact extraction for recreation, interpreted extraction for inspiration
