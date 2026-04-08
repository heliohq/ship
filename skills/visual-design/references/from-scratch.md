# Mode A: From Scratch

Collaborative design exploration — turn a vague vision into a complete DESIGN.md through structured discovery and incremental validation.

<HARD-GATE>
Do NOT write the DESIGN.md until you have explored the user's vision, proposed design directions, and received approval on the overall direction. A "simple" design system is where unexamined assumptions cause the most wasted iteration. The discovery can be brief for clear visions, but you MUST present a direction and get approval.
</HARD-GATE>

## Checklist — complete in order

1. **Explore project context** — check existing files (CSS, theme configs, package.json) for constraints
2. **Offer visual companion** — if the project has a dev server or you can serve preview.html, offer to show live previews as you iterate (this is its own message, not combined with a question)
3. **Discovery questions** — one at a time, understand the design vision
4. **Propose 2-3 design directions** — with trade-offs and your recommendation
5. **Present design incrementally** — core sections first, get feedback before completing all 9
6. **Write DESIGN.md + preview.html** — only after direction is validated
7. **Quality gate** — run the Quality Checklist, then present for final approval

## Discovery — understanding the vision

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

## Exploring directions

- Once you understand the vision, propose **2-3 design directions** with distinct personalities
- For each direction, describe: color mood (with example hex), typography approach, component style, and the overall feel
- Lead with your recommendation and explain why it fits their stated goals
- Example: "Direction A: *Midnight Professional* — dark navy surfaces, weight-300 headings, subtle chromatic shadows. Direction B: *Warm Editorial* — cream backgrounds, serif headings, generous whitespace. I'd recommend A because you mentioned wanting a developer-tool feel."

## Presenting the design incrementally

- After the user picks a direction, build the design section by section
- Present the **foundation sections first** and get feedback before completing all 9:
  - **Section 2 (Colors)** — present the full palette with names and roles. This is the highest-impact decision. Get approval before proceeding.
  - **Section 3 (Typography)** — font choices, hierarchy table. Get approval.
  - **Sections 4-6 (Components, Layout, Elevation)** — present together as the "component layer." Get approval.
  - **Sections 1, 7-9 (Atmosphere, Do's/Don'ts, Responsive, Agent Guide)** — complete after the core is validated.
- Scale each presentation to its complexity — a few sentences if straightforward, detailed walkthrough if nuanced
- Be ready to go back and revise. "The blues feel too cold" means revisiting Section 2 before continuing.

## Visual companion

When you anticipate that visual feedback would help the user evaluate choices (color palettes, typography pairings, component styles), offer to show a live preview:

> "I can generate a live preview as we go so you can see how colors, fonts, and components look together. Want me to open a preview in your browser?"

This offer MUST be its own message — do not combine with other questions. If they accept:
- Generate `preview.html` early with the foundation tokens (even before all 9 sections are complete)
- Update the preview as you iterate on sections
- Use `references/preview-template.html` as the scaffold

If they decline, proceed with text-only descriptions.

## After validation — writing the DESIGN.md

- Read `references/template.md` for the exact 9-section structure
- Read `references/section-guide.md` for quality standards per section
- Generate the companion `preview.html` (and optionally `preview-dark.html`) using `references/preview-template.html`
- Run the Quality Checklist (defined in SKILL.md) before presenting the final result
- Present both files to the user for final approval

## Key principles

- **One question at a time** — don't overwhelm with a wall of questions
- **Multiple choice preferred** — "Which of these 3 palettes?" beats "What colors do you want?"
- **Show, don't describe** — if visual companion is available, show a palette swatch instead of listing 10 hex codes
- **Foundation first** — colors and typography define 80% of the feel; get those right before detailing components
- **Be opinionated** — always lead with your recommendation; the user hired a design system, not a menu
- **Revise willingly** — going back to fix the palette after seeing components is normal, not failure
