# Handoff: Free plan → 2 projects, Pro free trials

Source of truth: `LastReel App Light.dc.html`. Screens referenced by ID (1.1a, 1.6, 6.5…). Match copy exactly.

## Latest changes (v3)
- Free limit raised from **1 to 2 projects** everywhere: Library, Slots full, Paywall table, Settings, Cancel copy.
- **1.1a** redesigned: both free projects are listed, followed by one plan card with a single "Start free trial" button. The Library has no plan tiles or prices.
- "Start free trial" always opens **6.5 LastReel Pro**. That is the only place the user picks yearly (14 days free) or monthly (7 days free).
- The design file `LastReel App Light.html` is bundled next to this doc. It opens offline in any browser.

## 1. Business rules

- **Free plan:** 2 projects (was 3). Ads on. Every block, timing and look tool is included. Exports H.264/HEVC up to 1080p, no watermark. One Pro render unlocks per rewarded ad (unchanged).
- **Pro:** unlimited projects, ProRes, PNG alpha and 4K, no ads.
- **Pricing and trials:**
  - Monthly: $4.99/mo, **7-day free trial**
  - Yearly: $29.99/yr ($2.50 a month, "Save 50%"), **14-day free trial**. Preselected by default.
- No instant charge. Hitting the limit offers a trial, not a purchase.
- A trial user is Pro: no ads, unlimited projects.
- **After a trial ends or Pro is cancelled:** nothing is deleted. Every project is kept, only **two** stay editable, and ads come back.
- Trial eligibility: one trial per account/store account. If the user isn't eligible, swap the trial copy for the plain price ("Start Pro — $29.99/yr"). The store handles this, so check intro-offer eligibility before rendering.

## 2. Library states (module 01)

### 1.1a Library · free, no trial (NEW)
Shown to Free users with 2 of 2 projects used who haven't started a trial.
- Eyebrow: `Reel · 2 of 2 · Free`
- "+ New" becomes a **secondary** button (white, outlined). Tapping it opens 1.6.
- Both project cards show as normal (`01`, `02`).
- **Plan card**, pinned to the bottom of the list (white, 1px line, 20px radius):
  - Row: `FREE PLAN` (left) · `2 OF 2 PROJECTS` (right), mono, muted
  - A 2-segment meter, both filled
  - Title: "Both free projects are in use"
  - Body: "Try Pro free for unlimited projects, ProRes and 4K exports, and no ads."
  - **One button only:** "Start free trial". No prices, plan tiles or trial lengths on this screen.
- Tapping "Start free trial" opens **6.5 LastReel Pro**, where the user picks a plan (yearly 14 days free, preselected; monthly 7 days free) and confirms through the store sheet. On success, go to 1.1.
- While the card is showing, it **replaces** the sponsored ad slot.

### 1.1 Library · on trial (renamed from "Library · home")
- Eyebrow: `Reel · Pro trial · 6 days left` (live countdown)
- No sponsored ad (trial = Pro).
- A dashed reminder row at the end of the list: `6d` (accent serif) · "Trial ends 7 Oct" · "After that, two projects stay free." · `Plans` button → 6.5.

### 1.2 Library · empty
- Eyebrow: `Reel · 0 of 2 · Free`

### 1.6 Slots full (bottom sheet, opened by + New when full)
- Progress: **two** full bars (was three)
- Label: `2 of 2 projects used`
- Title: "The free plan keeps *two projects.*"
- Body: "Nothing was deleted and nothing expires. To start another, free up a slot or try Pro free — you won't be charged until the trial ends."
- Pro card: header right `Try free` (accent). Keep the 3 checks. Add the line: "7 days free on monthly ($4.99), 14 days free on yearly ($29.99). Cancel before it ends and pay nothing."
- Primary: "Start free trial" → 6.5
- Secondary: "Free up a slot"

### 1.7 Duplicated · undo
- Eyebrow: `Reel · Pro trial · 3 projects`

### 2.1 New project
- Eyebrow: `New project · Reel 03` (was "slot 3 of 3")

## 3. 6.5 LastReel Pro (paywall)
- Body: "…Pro lifts the **two-project** cap…"
- Monthly row subtitle: "7 days free, then $4.99/mo"
- Yearly row subtitle: "14 days free, then $2.50 a month". Keep the `Save 50%` badge; yearly stays preselected.
- Comparison table, Projects row: Free `2` / Pro `Unlimited`
- CTA: "Start 14-day free trial" (follows the selected plan)
- Below the CTA: "Free until {trialEndDate}, then $29.99/yr. Cancel before then and you pay nothing." Compute the date from the selected plan's trial length.
- Links below unchanged: Restore purchase · Stay on Free

## 4. Settings (module 07)

### 7.1 Settings, plan card (Free)
- Meta: `2 of 2 projects · ads on`
- Meter: two full bars
- Primary: "Start free trial" (was "Upgrade to Pro") · secondary "Restore"

### 7.3 Subscription · Pro
- Cancel copy: "…After that nothing is deleted: you keep every project, **two** can be edited, and ads come back."

## 5. Implementation notes
- Make the free project limit a single config value (`FREE_PROJECT_LIMIT = 2`). Every "x of y" string and meter reads from it.
- Plan state should cover: `free`, `free_trial_dismissed(until)`, `trial(endsAt, plan)`, `pro(plan, renewsAt)`, `lapsed`. Library, Settings, ads and the paywall all read from it.
- Trial countdown: days left = ceil((endsAt − now) / 1 day). Show `Trial ends {d MMM}`.
- After a lapse with more than two projects: all projects stay visible and read-only. The user picks two to keep editable (most recent by default). Rendering is still allowed.
- Store setup: monthly and yearly subscriptions each carry a free-trial intro offer (7 days for monthly, 14 days for yearly).
- Analytics: `trial_card_shown`, `trial_card_dismissed`, `trial_plan_selected{plan}`, `trial_started{plan, source: library|slots_full|paywall|settings}`, `trial_converted`, `trial_cancelled`.

## 6. Still to update (not yet in the design file)
- Play Store screenshot 08 copy still says "3 projects free". Change it to: "2 projects free. Try Pro free for 7 or 14 days — unlimited projects, ProRes, PNG and 4K, no ads." Then re-export.
- Store listing descriptions need the same plan wording.
