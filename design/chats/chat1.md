# Chat

_Started 2026-09-13 12:50 UTC_

---

## User

<system-info comment="Only acknowledge these if relevant">
Project title is now "# EndCrawl — Design Prompt (v1, no AI)??? Copy everything below the line into Cl"
Current date is now September 13, 2026
</system-info>

<attached aesthetic_system_instructions>
A design system or theme is attached to this project. That attachment already answers the visual-style question: apply it. Do NOT ask the user which visual style to use — no questions about vibe, colors or palette directions (including color-swatch svg-options questions), typography, mood, or art direction, and skip the "divergent visuals" question from the question-asking tips; offer divergent visual directions only if the user themselves asks for alternatives. This rule bans asking the user to pre-pick a style in the abstract — swatches, mood words, palette pickers. It does not ban asking them to choose among candidates you have already built: putting built candidates on a file-options board for the user to pick from is encouraged. Treat the attachment as the confirmed starting point and product context — the "confirm the starting point" tip is already satisfied, so do not ask the user to confirm or re-pick it. Spend your questions on everything else you need: audience, purpose, content, structure, scope, interactions, tone of copy.
</attached aesthetic_system_instructions>

<pasted_text name="Pasted text (274 lines)">
# EndCrawl — Design Prompt (v1, no AI)

&gt; Copy everything below the line into Claude.

---

## ROLE

You are a senior product designer and motion-systems engineer who has shipped
professional post-production tools. You understand that a credit roll is not a
scrolling text box — it is a typographic and timing instrument that has to
survive being projected, streamed, and paused. Design with that seriousness.

## MISSION

Design and build **EndCrawl** — a dedicated end-credits app for phones (iOS &amp;
Android). One job, done better than any desktop tool: an indie filmmaker,
YouTuber, or film student produces a broadcast-clean rolling credit sequence on
their phone in under 60 seconds, and it looks like it came off a Hollywood
online conform.

The benchmark is Endcrawl.com. Match its craft standards, then beat it on speed,
touch ergonomics, and the fact that it lives in the user's pocket. Do not design
a "mobile-lite" version of a desktop tool. Design the tool a working filmmaker
would actually choose.

## HARD CONSTRAINTS — READ FIRST

1. **No AI features anywhere in v1.** No "magic" buttons, no LLM cleanup, no
   generative anything. Every feature must be deterministic, explainable, and
   instant. Where bulk entry is needed, solve it with a rule-based parser and
   direct manipulation — see §7. AI is explicitly deferred to a later phase and
   must not appear in the UI, not even greyed out or as a "coming soon" teaser.
2. **Portrait and landscape are equal citizens.** Not a rotation afterthought —
   a first-class format system covering vertical shorts through scope features
   (§4). The editor UI itself must work in both device orientations, and the
   *output canvas* orientation is independent of the *device* orientation.
3. **Craft over chrome.** Every visual decision serves legibility, timing
   accuracy, or speed of entry. No decorative gradients, no glassmorphism for
   its own sake, no animation that delays a tap.
4. **Thumb-first.** Primary actions live in the bottom third. Nothing critical
   in the top corners. Minimum 44×44pt targets. The app must be fully operable
   one-handed on a 6.1" phone.

## 1. WHO IT'S FOR

- **Indie filmmakers / festival submitters** — need contractual credit ordering,
  exact runtime locks, and alpha export to hand to an editor.
- **YouTubers &amp; short-form creators** — need 9:16 and 1:1, fast, with a
  believable cinema look.
- **Film students** — need the conventions taught to them (card order, two-column
  cast, department grouping) baked in as defaults, so the app teaches while it works.

Design for the filmmaker's standards; deliver the YouTuber's speed.

## 2. WHY MOBILE EDITORS FAIL AT THIS

State the problem the design must beat, and solve each one visibly:

| Failure in CapCut/Premiere-on-phone | What EndCrawl does instead |
|---|---|
| Manual keyframing a text layer up the screen | Roll is generated from content + duration; never keyframed by hand |
| Judder/strobing on the scroll | Frame-locked, whole-pixel-per-frame motion engine (§3) |
| Two-column cast alignment is impossible | Gutter-based two-column block is the hero primitive (§6) |
| Reordering means re-keyframing everything | Reorderable block cards; timing recalculates instantly |
| No alpha output | Transparent background export is a headline feature |
| Text drifts outside title-safe | Live safe-area guides, always available |

## 3. THE ROLL ENGINE — THE PART THAT MUST BE RIGHT

This is where the product is won. Specify and demonstrate:

- **Frame-rate aware.** 23.976 / 24 / 25 / 29.97 / 30 / 50 / 60 fps. The chosen
  rate is part of the project, not the export dialog.
- **No-judder scroll.** Scroll rate must resolve to a whole number of pixels per
  frame at the render resolution (or clean sub-pixel with correct motion
  handling). Surface this to the user as a small, confident **"Judder-free"**
  indicator, and warn — non-blockingly — when a chosen duration would land on a
  fractional rate, offering the nearest two clean durations as one-tap fixes.
- **Duration lock.** The user types a target runtime (e.g. 01:42:00) and the
  engine derives the scroll rate. Inverse mode: user sets a readable scroll
  speed and the engine reports the resulting runtime. Both directions must be
  reachable in one tap of each other.
- **Readability floor.** Enforce a minimum dwell time per line; if content plus
  target duration would push text past readable speed, say so plainly and
  suggest lengthening the roll or trimming lines. Never silently render an
  unreadable roll.
- **Head and tail black.** Configurable padding before the first credit and
  after the last, in seconds or frames.
- **Non-scrolling cards.** Support hold cards (fade in → hold → fade out) that
  interrupt the roll — used for studio logos, "In loving memory", final
  copyright/MPA card. Hold duration and fade durations independently settable.
- **Title-safe / action-safe.** 80% / 90% guides, toggleable, on by default for
  landscape formats.

## 4. FORMAT &amp; ORIENTATION SYSTEM

A dedicated format step, not buried in settings:

- **Presets:** 9:16 vertical (Shorts/Reels/TikTok), 4:5, 1:1, 16:9 HD/UHD,
  1.85:1 flat, 2.39:1 scope, DCI 4K flat/scope. Custom W×H.
- Orientation of the *canvas* is chosen by the user, independent of how they are
  holding the phone.
- **Reflow, don't squash.** Switching format must re-lay-out intelligently:
  vertical formats get tighter gutters, a narrower two-column ratio, larger
  relative type, and the option to auto-collapse two-column cast into stacked
  pairs when the gutter would fall below a legibility threshold. Show this
  reflow as an animated, reversible transition so the user trusts it.
- A **rotate-to-preview** affordance: turning the phone to landscape while a
  landscape project is open expands the monitor to full-bleed with UI dimmed
  away. Turning back restores the editor. This should feel inevitable.

## 5. DESIGN LANGUAGE

Dark, cinema-grade, restrained:

- **Palette:** obsidian/near-black grounds (avoid pure #000 for UI chrome so the
  preview's true black reads as black), a single warm gold accent used sparingly
  for primary action and active state, and a cool neutral grey ramp for
  structure. One reserved semantic color for warnings. No second accent.
- **Type:** a crisp interface face for chrome; a separate, genuinely cinematic
  set of credit typefaces for the roll itself. Ship a curated list (grotesque,
  transitional serif, and a condensed) rather than a font zoo, and let users
  bring their own file.
- **Tokens:** define semantic design tokens (`--surface-canvas`,
  `--surface-raised`, `--accent-primary`, `--text-secondary`, `--safe-guide`,
  spacing scale, radius scale, motion durations/easings) and use them
  everywhere. No hardcoded hex or px in components.
- **Motion:** short, purposeful, 150–250ms, spring where a gesture continues
  physically. UI motion must never compete with, or run during, preview playback.
- **Haptics:** specify where they fire — block drop, snap to gutter, scrub reaching
  a card boundary, duration lock confirmed.

## 6. THE BLOCK EDITOR

The document is an ordered list of typed blocks. Design each type as a distinct,
legible card in a vertical list, and design its editing surface.

**Block types:**

- **Title Card** — studio/production banner (image, vector-safe), film title,
  optional "A Film By". Type scale controls, because contractual credit sizing
  is real: let the user set title size and then constrain other credits
  relative to it (e.g. "no less than 50% of title").
- **Two-Column Cast — the hero.** Left column right-aligned (character/role),
  right column left-aligned (actor), fixed center gutter. Leader style toggle:
  dotted leaders, clean gutter, or hairline rule. Per-row and per-block control
  of gutter width. Support: single-name rows spanning both columns, blank
  spacer rows, and "and" / "with" special-billing rows.
- **Department Block** — a header (DIRECTED BY, CINEMATOGRAPHY, PRODUCTION
  DESIGN, MUSIC BY, EDITED BY…) plus one or more names, in either centered
  stack or two-column form. Ship the standard department order as a template so
  students get it right by default.
- **Hold Card** — non-scrolling, per §3.
- **Logo Row** — a horizontal strip of logos with even optical spacing.
- **Soundtrack Block** — song title / artist / courtesy-of, in the conventional
  three-line form.
- **Special Thanks** — flowing multi-column name list that balances itself.
- **Spacer** — explicit vertical gap in seconds or lines.

**Editing interactions:**

- Long-press to lift, drag to reorder, with the list parting to show the drop
  target. Auto-scroll at the edges.
- Swipe a card for duplicate / mute (keeps it in the doc but out of the render)
  / delete.
- Tap a card to open a focused editor sheet; the monitor stays visible and jumps
  to that block's position in the roll.
- Multi-select for bulk restyling.
- Undo/redo that is reachable without a menu.

## 7. BULK ENTRY — WITHOUT AI

Solve the messy-notes problem deterministically, and make the mechanism visible:

- **Paste &amp; Split.** User pastes raw text. Show a live two-pane parse preview:
  raw on one side, structured rows on the other. The user picks the delimiter
  from detected candidates (comma, tab, dash, colon, " as ", double-space) with
  a live row count and a visible confidence-free, rule-based result. Column swap
  is one tap. Any row the parser can't split is flagged, not guessed, and lands
  in a short "needs a look" list the user fixes inline.
- **Import** from CSV/TSV, and from a Notes/clipboard table, with column mapping.
- **Fast manual entry** as the fallback that must still feel great: an entry bar
  fixed above the keyboard where Tab/Next hops role → name → new row, so a
  30-person cast is typed without ever leaving the keyboard.

Explicitly do *not* infer, autocorrect, or invent names. The user's text is the
user's text.

## 8. THE MONITOR

- Real-time playback at the project frame rate, smooth and honest — what plays
  is what renders.
- **Scrub bar with timecode** (HH:MM:SS:FF, frame-accurate), plus block markers
  along the bar so the user can jump to "Cast" instantly.
- Transport: play/pause, jump to head/tail, step by frame, and a loop-region
  option for checking one section's pacing.
- **Look toggle:** 2D flat roll (the correct, standard Hollywood roll) vs. 3D
  perspective crawl (the Star Wars vanishing-point look), with the 3D mode
  exposing tilt angle and vanishing distance. Make clear in the UI that 2D is
  the professional default and 3D is a stylistic choice.
- **Background:** pure black, transparent/alpha (rendered as a checkerboard in
  the monitor), green screen, custom color, and video-underlay preview so users
  can check contrast against their own footage.
- Pinch to zoom the monitor; double-tap for full-bleed.
- A persistent, quiet **status line**: format · fps · duration · judder state.

## 9. EXPORT

Design the export sheet as a confidence-building screen, not a dialog:

- Format/fps/duration restated, non-editable, with an edit affordance.
- Codec choices appropriate to mobile, with **alpha-capable export called out**
  as the one that drops straight onto a timeline.
- Resolution ladder, and an estimated file size and render time.
- Progress with a real preview thumbnail, backgrounded so the user can keep working.
- Share sheet destinations plus "save to Files/Photos".

## 10. STATES &amp; EDGE CASES — DESIGN THESE, DON'T SKIP THEM

Empty project (with a genuinely useful starting template chooser: Short Film,
Feature, YouTube, Music Video, Student Film); one block only; a 400-name cast
(list virtualization and a jump-to-letter rail); a name too long for its column
(specify the rule — shrink, wrap with hanging indent, or overflow warning —
and pick one); duration that would be unreadable; missing font file; export
failure; offline; project recovery after a crash.

## 11. WHAT TO BUILD

Produce a **high-polish, fully interactive mobile prototype** as a
self-contained HTML page using modern Tailwind and the semantic token layer
from §5. Requirements:

- Renders inside a phone frame, and demonstrates **both** portrait and landscape
  device layouts as well as portrait and landscape *canvas* formats.
- Actually clickable end-to-end: create project → choose format → add and reorder
  blocks → paste-and-split a cast list → adjust duration → toggle 2D/3D → toggle
  background → scrub → export sheet. Real state, not static screens.
- The roll preview must genuinely animate, smoothly, driven by
  `requestAnimationFrame` with a real time base — the scroll math should be the
  actual engine described in §3, not a CSS marquee.
- Include a component/token appendix screen showing the color ramp, type scale,
  spacing, and each block card in its states (default, selected, dragging,
  muted, error).
- Keyboard-free: every interaction reachable by touch.

## 12. ACCEPTANCE CRITERIA

Judge your own output against these before you finish:

1. A first-time user reaches a rendered, correct-looking roll in under 60
   seconds of interaction.
2. The two-column cast block looks typographically correct — true gutter
   alignment, consistent optical spacing — at both 9:16 and 2.39:1.
3. Nothing in the UI mentions or implies AI.
4. The preview scroll is visibly smooth and its speed matches the stated duration.
5. Every color, space, and radius comes from a token.
6. The design would not embarrass itself next to Endcrawl.com in a side-by-side
   screenshot — and is obviously faster to use on a phone.

## 13. DELIBERATELY OUT OF SCOPE (v1)

Automated text cleanup or parsing beyond explicit rules; collaboration and
commenting; cloud projects and accounts; music sync; anything generative. Note
these in a short "future phases" section at the end of your response, but build
none of it.

## 14. HOW TO RESPOND

Lead with a brief statement of the design thesis (3–4 sentences: what makes this
app good, and what you deliberately refused to do). Then the prototype. Then a
short rationale covering the roll-engine math, the two-column gutter system, and
the portrait/landscape reflow rules. Keep the prose tight — the prototype is the
argument.
</pasted_text>

<!-- The user explicitly selected the following skills for this project, as attachments to their message. These are not optional context — they define how you work. Use them. -->
<attached-skill name="Design Components">
This project uses Design Components: every design is a single streaming `Name.dc.html` file. The full authoring spec is in your system prompt under "Writing code — Design Components" — follow it. Author and edit `.dc.html` content with the `dc_write`, `dc_html_str_replace`, `dc_js_str_replace`, and `dc_set_props` tools (not `write_file`; `str_replace_edit` works but won't stream); template edits stream into the live preview as you type.
</attached-skill>

<attached-skill name="Design System (design system)">
[Design System] This project uses the **Design System** design system. This is a binding choice for visual style — every visual must follow it. Don't invent colors, type, spacing, or components not grounded here.

Scope: the design system is a visual style reference only. Its guide may describe example products, brands, or people that are unrelated to the user and unrelated to the subject of this conversation. Never treat anything in the design system as a fact about the user, their work, or the topic they asked about.

    Explore it to find what you need:
    - Always copy out the fonts and colors you need
    - For prototypes and designs, always copy out any relevant components
    - If the design system contains existing mocks of products, and you were asked to design or prototype something similar, copy and fork those mocks to start your design. This helps you make high-quality designs.

    Explore it quickly to find relevant UI kits (e.g. mocks of existing products you can copy and fork)

Full system at `/projects/eb94972e-3daa-4231-ab87-c918521d6acf/`. Before producing any visuals, explore it: call `list_files("/projects/eb94972e-3daa-4231-ab87-c918521d6acf/")` to see the structure, then `read_file` the README/base.md or whatever index file it has. Don't guess at the design system's contents.

CSS tokens: the guide may describe tokens in prose, but the exact `--*` names are defined in the design system's stylesheet(s). Before writing any `var(--*)`, look up the real name in the design system's `.css` files (`list_files` + `read_file` under `/projects/eb94972e-3daa-4231-ab87-c918521d6acf/`). Never guess a token name — an unresolved `var()` silently falls back to the browser default.

For assets and UI kits beyond the guide: `read_file("/projects/eb94972e-3daa-4231-ab87-c918521d6acf/<path>")` and `copy_files` to bring them into the current project.
</attached-skill>

## Assistant

I'll start by exploring the design system.

_[tool: list_files]_

_[tool: read_skill_prompt]_

Design system project is empty, so I'll follow the design language specified in your brief (§5) and build it as a single streaming Design Component.

_[tool: update_todos]_

_[tool: dc_write]_

_[tool: dc_write]_

The write was too large and got cut off mid-stream. I'll rebuild it in bounded passes — core engine + editor first, then the sheets.

_[tool: dc_write]_

_[tool: dc_js_str_replace]_

_[tool: show_html]_

_[tool: show_html]_

_[tool: multi_screenshot]_

_[tool: dc_js_str_replace]_

_[tool: dc_js_str_replace]_

_[tool: multi_screenshot]_

_[tool: get_webview_logs]_

_[tool: eval_js]_

_[tool: eval_js]_

_[tool: eval_js]_

_[tool: eval_js]_

_[tool: eval_js]_

_[tool: get_webview_logs]_

_[tool: show_html]_

_[tool: eval_js]_

_[tool: dc_js_str_replace]_

_[tool: eval_js]_

_[tool: show_html]_

_[tool: eval_js]_

_[tool: eval_js]_

_[tool: eval_js]_

Playback is fine — rAF is just paused in my headless preview. Now the sheets.

_[tool: dc_html_str_replace]_

_[tool: dc_html_str_replace]_

_[tool: dc_js_str_replace]_

_[tool: eval_js]_

## Assistant

_[tool: update_todos]_

_[tool: show_html]_

Now the appendix screen — the last piece.

_[tool: dc_html_str_replace]_

_[tool: dc_js_str_replace]_

_[tool: dc_js_str_replace]_

_[tool: dc_js_str_replace]_

_[tool: dc_js_str_replace]_

_[tool: dc_js_str_replace]_

_[tool: dc_js_str_replace]_

_[tool: ready_for_verification]_

**Design thesis.** A credit roll is a timing instrument, so the runtime is the input and the motion is derived — never keyframed. The engine locks scroll to a whole number of pixels per frame at render resolution and says so in a persistent status line; when a runtime lands fractional or pushes a line below a 3.0s dwell floor, it warns and hands you the two nearest clean runtimes as one-tap fixes. The two-column cast block is the hero primitive: a fixed centre gutter with right-aligned roles and left-aligned names that auto-collapses to stacked pairs when columns fall under the legibility floor, which is what makes 9:16 and 2.39:1 both look correct. And no AI anywhere — bulk entry is a visible rule-based delimiter parser that flags what it can't split instead of guessing.

**What's in it:** template chooser with crash recovery → format/fps step → editor with drag-reorder, swipe actions, per-type edit sheets, live rAF monitor, scrub with block markers, 2D/3D look, five backgrounds incl. alpha checkerboard, timing sheet with both lock directions, Paste & Split, export sheet with alpha callout and a real failure state. Device landscape gives the full-bleed monitor. Second tab is the token/component appendix with every card state, the gutter system shown side-by-side at both aspects, and the stated edge-case rules.

Two things to note: the roll's px/frame math is calculated against the true render resolution while the monitor displays a scaled version, so "judder-free" refers to the export, not the on-screen preview; and the long-name rule is implemented as wrap-with-hanging-indent (never shrink), per the appendix.

**Future phases, deliberately unbuilt:** text cleanup beyond explicit rules, collaboration/commenting, cloud projects and accounts, music sync.

## User

Found issues — fixing…

## Assistant

_[tool: dc_js_str_replace]_

_[tool: dc_js_str_replace]_

_[tool: dc_js_str_replace]_

_[tool: dc_html_str_replace]_

_[tool: dc_html_str_replace]_

_[tool: dc_html_str_replace]_

_[tool: dc_html_str_replace]_

_[tool: ready_for_verification]_

All three fixed: the monitor now derives from the inner screen size (frame − bezel) so it no longer overhangs, the runtime input got `min-width:0` (same for the custom W×H pair), and the status line is nowrap + padded + ellipsized, with the format shown as its pixel dimensions so it fits at every preset.

