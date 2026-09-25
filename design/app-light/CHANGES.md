# LastReel — change handoff

Source of truth: `LastReel App Light.dc.html` (open in a browser; `support.js` must sit next to it).
Apply these changes to the codebase. Screen ids (e.g. 6.1) match the badges in the design file.

## 1. Rename EndCrawl → LastReel
- Wordmark: `LASTREEL` (uppercase, wide letter-spacing, same style as before).
- In sentences: `LastReel` — "LastReel Pro", "New to LastReel?", "Rate LastReel", "LastReel 1.0 (214)".
- Update app name, bundle display name, product IDs/strings, and any `EndCrawl`/`Endcrawl` text.

## 2. Pro-gated export features
Free: H.264, HEVC, up to 1080p. Pro: ProRes 422 HQ, ProRes 4444, PNG sequence, 4K UHD.
- 6.1 Export: Pro options stay visible and selectable, each with a `PRO` chip (gradient pill).
- When a free user selects a Pro option:
  - Show info card: "ProRes 422 HQ is a Pro codec — Watch a 30-second ad to use it for this render. Each ad unlocks one render."
  - Primary button: "Watch ad · render once" → 6.1a
  - Secondary button: "Go Pro · every render, no ads" → 6.5
- Pro users: normal "Render <codec>" button, no card.

## 3. New screen 6.1a — Rewarded ad
- Full-screen black ad player, progress bar, "Ad · 0:18 left", "Reward in 18s" pill.
- Card: "Unlocking ProRes 422 HQ — This render only · starts when the ad ends".
- Advertiser bar at bottom (logo, name, "Learn more").
- Logic:
  - Opt-in only; never auto-plays.
  - Close button appears only after the reward is earned.
  - On reward → render starts automatically (→ 6.2).
  - Closed early → back to 6.1, nothing unlocked.
  - 1 ad = 1 render with the chosen Pro settings. If that render fails (6.3), the retry is free — don't require a second ad.

## 4. 6.4 Export complete — native ad
- Below the destinations list (Files / Photos / Frame.io / Share): "Sponsored" label + "Remove ads" link (→ 6.5) + one native ad card.
- Only shown after the file is saved. No interstitials; never blocks share actions. Free plan only.

## 5. 6.5 LastReel Pro sheet
- Remove the "Where ads show on Free" box.
- Headline: "Unlimited projects. / *Pro formats. No ads.*"
- Subtext: "Free has every block, timing and look tool, with H.264 and HEVC up to 1080p. Pro lifts the three-project cap, unlocks ProRes, PNG and 4K on every render, and removes ads."
- Comparison table (Free | Pro):
  - Projects: 3 | Unlimited
  - Ads: Shown | None
  - Blocks, timing, look: Everything | Everything
  - Codecs: H.264, HEVC | + ProRes, PNG
  - Resolution: Up to 1080p | Up to 4K
  - Pro render on Free: 1 per rewarded ad | Every render
  - Watermark: None | None

## 6. 1.6 Slots full — Pro card
- Add benefit line: "✓ ProRes, PNG alpha and 4K exports" (between "Unlimited projects…" and "No ads…").

## Ad placements (Free plan, final list)
1. Library bottom (1.1, 1.2) — native card (existing)
2. While rendering (6.2) — native card (existing)
3. Export complete (6.4) — native card (new)
4. Rewarded ad for Pro render (6.1a) — opt-in (new)

Never: editor, monitor, template picker, render failure, or inside the exported file.
