# Handoff: Free plan → 1 project, Pro free trials

Source of truth: `LastReel App Light.dc.html`. Screens referenced by ID (1.1a, 1.6, 6.5…). Match copy exactly.

## 1. Business rules

- **Free plan:** 1 project (was 3). Ads on. Every block, timing and look tool is included. Exports H.264/HEVC up to 1080p, no watermark. One Pro render unlocks per rewarded ad (unchanged).
- **Pro:** unlimited projects, ProRes, PNG alpha and 4K, no ads.
- **Pricing and trials:**
  - Monthly: $4.99/mo, **7-day free trial**
  - Yearly: $29.99/yr ($2.50 a month, "Save 50%"), **14-day free trial**. Preselected by default.
- No instant charge. Hitting the limit offers a trial, not a purchase.
- A trial user is Pro: no ads, unlimited projects.
- **After a trial ends or Pro is cancelled:** nothing is deleted. Every project is kept, only **one** stays editable, and ads come back.
- Trial eligibility: one trial per account/store account. If the user isn't eligible, swap the trial copy for the plain price ("Start Pro — $29.99/yr"). The store handles this, so check intro-offer eligibility before rendering.

## 2. Library states (module 01)

### 1.1a Library · free, no trial (NEW)
Shown to Free users with 1 of 1 project used who haven't started a trial.
- Eyebrow: `Reel · 1 of 1 · Free`
- "+ New" becomes a **secondary** button (white, outlined). Tapping it opens 1.6.
- The user's one project card shows as normal (`01`).
- A divider row: `FREE PLAN ——— 1 OF 1 PROJECT USED` (mono, muted, with a hairline between).
- **Trial offer card.** It must not look like a project: no black credit frame, no reel number.
  - Background: accent wash fading to white (165°), 1.5px accent-line border, 22px radius.
  - Top row: pill `PRO · FREE TRIAL` (primary background, white mono text), ✕ dismiss button (32px circle).
  - Headline (serif 32px): "Ready for *reel two?*" (italic part in accent)
  - Body: "Your free plan holds one project. Try Pro free to make as many as you like."
  - Chips: `Unlimited projects` · `ProRes · PNG · 4K` · `No ads`
  - Plan selector, two tiles:
    - Yearly: `14 days free` / `then $29.99/yr`, selected by default
    - Monthly: `7 days free` / `then $4.99/mo`
  - Primary CTA: "Start 14-day free trial". The label follows the selected tile ("Start 7-day free trial" for monthly).
  - Fine print: "No charge today · cancel anytime"
- The CTA opens the store purchase sheet. On success, go to 1.1.
- ✕ hides the card for 7 days. While the card is showing, it **replaces** the sponsored ad slot. When it's dismissed, the ad returns.

### 1.1 Library · on trial (renamed from "Library · home")
- Eyebrow: `Reel · Pro trial · 6 days left` (live countdown)
- No sponsored ad (trial = Pro).
- A dashed reminder row at the end of the list: `6d` (accent serif) · "Trial ends 7 Oct" · "After that, one project stays free." · `Plans` button → 6.5.

### 1.2 Library · empty
- Eyebrow: `Reel · 0 of 1 · Free`

### 1.6 Slots full (bottom sheet, opened by + New when full)
- Progress: **one** full bar (was three)
- Label: `1 of 1 project used`
- Title: "The free plan keeps *one project.*"
- Body: "Nothing was deleted and nothing expires. To start another, free up the slot or try Pro free — you won't be charged until the trial ends."
- Pro card: header right `Try free` (accent). Keep the 3 checks. Add the line: "7 days free on monthly ($4.99), 14 days free on yearly ($29.99). Cancel before it ends and pay nothing."
- Primary: "Start free trial" → 6.5
- Secondary: "Free up the slot"

### 1.7 Duplicated · undo
- Eyebrow: `Reel · Pro trial · 3 projects`

### 2.1 New project
- Eyebrow: `New project · Reel 03` (was "slot 3 of 3")

## 3. 6.5 LastReel Pro (paywall)
- Body: "…Pro lifts the **one-project** cap…"
- Monthly row subtitle: "7 days free, then $4.99/mo"
- Yearly row subtitle: "14 days free, then $2.50 a month". Keep the `Save 50%` badge; yearly stays preselected.
- Comparison table, Projects row: Free `1` / Pro `Unlimited`
- CTA: "Start 14-day free trial" (follows the selected plan)
- Below the CTA: "Free until {trialEndDate}, then $29.99/yr. Cancel before then and you pay nothing." Compute the date from the selected plan's trial length.
- Links below unchanged: Restore purchase · Stay on Free

## 4. Settings (module 07)

### 7.1 Settings, plan card (Free)
- Meta: `1 of 1 project · ads on`
- Meter: a single full bar
- Primary: "Start free trial" (was "Upgrade to Pro") · secondary "Restore"

### 7.3 Subscription · Pro
- Cancel copy: "…After that nothing is deleted: you keep every project, **one** can be edited, and ads come back."

## 5. Implementation notes
- Make the free project limit a single config value (`FREE_PROJECT_LIMIT = 1`). Every "x of y" string and meter reads from it.
- Plan state should cover: `free`, `free_trial_dismissed(until)`, `trial(endsAt, plan)`, `pro(plan, renewsAt)`, `lapsed`. Library, Settings, ads and the paywall all read from it.
- Trial countdown: days left = ceil((endsAt − now) / 1 day). Show `Trial ends {d MMM}`.
- After a lapse with more than one project: all projects stay visible and read-only. The user picks one to keep editable (most recent by default). Rendering is still allowed.
- Store setup: monthly and yearly subscriptions each carry a free-trial intro offer (7 days for monthly, 14 days for yearly).
- Analytics: `trial_card_shown`, `trial_card_dismissed`, `trial_plan_selected{plan}`, `trial_started{plan, source: library|slots_full|paywall|settings}`, `trial_converted`, `trial_cancelled`.

## 6. Still to update (not yet in the design file)
- Play Store screenshot 08 copy still says "3 projects free". Change it to: "1 project free. Try Pro free for 7 or 14 days — unlimited projects, ProRes, PNG and 4K, no ads." Then re-export.
- Store listing descriptions need the same plan wording.
