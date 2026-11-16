# Growth backlog

Owner decisions recorded 2026-11-16. This is a task list, not a claim that features are shipped.

## Acquisition: Android and iOS

- [x] Replace the website's iOS coming-soon badge with the live App Store link; deployed to Firebase Hosting and verified on lastreel.cookoo.dev on 2026-11-16. App-side link defaults are updated locally and require the next app release.
- [x] Save English-US iOS promotional text focused on films, school videos, cast/crew, preview and watermark-free export. Submit matching Android short copy and the two-project correction for Google review (2026-11-16).

- [ ] Focus the first acquisition experiment on English-speaking US creators on both stores. Lead with the finished rolling credits and the path from names to exported video. Keep platform-specific feature claims accurate.
- [ ] Use the same creative concept on both platforms, with real recordings of each platform's UI. First screenshot: finished credits; next: edit cast/crew, set timing, export.
- [ ] Measure store visit → install → first open → project created → first successful export by platform and country. Compare US and Brazil separately. Do not treat a store-link click as an install.
- [ ] Consider Brazilian Portuguese store copy and product localization only after Brazilian export-completion data supports the investment. Current data does not establish that condition.
- [ ] Record the source and campaign for acquisition experiments. No paid campaign or budget has been authorized.

## Repeatable production workflows

- [ ] CSV import: role/name columns, UTF-8, quoted commas, header mapping, preview, duplicate handling, validation and undo. Build on existing paste-to-rows functionality.
- [ ] Improve logo asset import and reusable logo libraries; audit existing logo blocks before adding duplicate functionality.
- [ ] Saved layout presets and reusable cast/crew blocks across projects.
- [ ] Evaluate these repeat-use benefits for Pro instead of relying only on project limits. Validate willingness to pay before choosing packaging.

## Notifications and lifecycle email

- [ ] Welcome email after account creation: one three-step tutorial and one link back to the first-project workflow. Deduplicate per account.
- [ ] One optional unfinished-draft reminder; cancel after successful export/deletion and respect channel preferences and quiet hours.
- [ ] Export-ready local notification only when native background completion is technically reliable; current rendering can pause in the background. Never announce completion from a timer alone.
- [ ] After first export, show concise CapCut/iMovie import guidance in-app; optionally email it to users who have chosen that channel.
- [ ] Trial-ending reminder with verified plan, date, price and the correct store/provider management link. Suppress where no trial exists, including the current iOS free-launch experience.
- [ ] Occasional template announcement relevant to a user-selected purpose; provide marketing opt-out and frequency limits.
- [ ] Use event IDs, suppression rules, delivery outcomes and an unsent control group to measure incremental completed exports, not just opens/clicks.

## Reliability and measurement

- [ ] Separate marketing-site traffic, web-editor traffic and local/internal testing in Clarity; add outbound store-click and first-export funnel measurement. The current shared project is not a clean marketing-site audience count.

- [ ] Investigate Android review reporting slow saving and an exported file that cannot be found. Reproduce Gallery/Files/Share on reported device classes before increasing acquisition spend.
- [ ] Separate actual SDK ad impressions from ad-loaded events and record export-ad skip reasons.
- [ ] Fix expired export-ad caches and visibility-aware native retry behavior after owner approval of the ad implementation plan. No ad changes are authorized by this backlog entry.
- [ ] Replace rating-based routing with a neutral store-review request; maintain a separate feedback option.
- [ ] Add an optional project-purpose choice (film, school, social, event, other). Existing templates and names do not establish user intent on their own.

## Store-preview production

- [x] Capture an iPhone preview using fictional sample credits: rolling preview → cast entry → timing → H.264 export → successful render/save options. Recorded the actual app in Device Hub on 2026-11-16.
- [x] Produce a 29-second iPhone App Store preview at 886×1920, 30 fps, H.264 with silent stereo AAC. Output: `output/store-preview/LastReel-iPhone-App-Preview.mp4`. Technical metadata and representative frames checked; not uploaded or store-reviewed.
- [ ] Record a separate Android native preview and prepare the Play promotional video/YouTube asset.
- [ ] Verify each depicted feature against the platform's shipped version before upload. Avoid purchase screens, ads, private account data and unsupported export claims.

## UX and review follow-up — 2026-11-16

- [x] Publish individual thank-you replies to the four positive Google Play reviews (Darryl, Elnino, Prince Haru, Asfand). Verified each published reply in Play Console. Three complaint reviews remain unanswered as requested.
- [x] Implement a visible Font action on phone/tablet/desktop editors with Archivo, EB Garamond and Archivo Narrow previews. Store the selection in project settings; bundle the missing font weights for offline use. Local implementation, not released.
- [x] Implement automatic Photos/Gallery saving for successful native video exports, permission handling, persistent saving/saved/failed status, duplicate-save prevention, and retry without rendering again. Retain failed delivery in the current session when the export panel closes. PNG ZIPs continue through sharing/downloads. Local implementation, not released.
- [ ] Verify OS permission denial, permanent denial, storage-full errors, app background/termination, and gallery visibility on physical Android and iOS devices before shipping. Modern Android may save app-created media without a permission prompt.
- [ ] Reproduce and profile slow saving on the reported Redmi device; distinguish rendering duration from gallery-copy time. Automatic saving does not establish a fix for render performance.
- [ ] Implement real image/logo import. Current generic logo editor explicitly says image upload is coming soon; logo-name blocks alone do not deliver this feature. Include PNG transparency, JPEG, image downsampling, orientation, offline caching, sync and export verification.
- [ ] Reply to complaint reviews only after the relevant fixes are released and verified. Keep the intentional two-free-project limit clear; do not promise it will change.

### Three close competitor references (store descriptions, not a verified market ranking)

| App | Verified capabilities worth studying | LastReel priority |
| --- | --- | --- |
| [Scrolling Credits Pro](https://apps.apple.com/us/app/scrolling-credits-pro/id1262188908) | Font style/size/color; image and video backgrounds; included tutorial and sample projects; direct Photo Library output | Finish reliable saving and font access first; add a short first-export tutorial, then background media |
| [End Credits Maker: Roll Titles](https://apps.apple.com/us/app/end-credits-maker-roll-titles/id6747294208) | CSV import, system fonts and text styling, real logo insertion, common-role helper, reusable style presets | Logo import and CSV preview/mapping next; role autocomplete and saved styles after that |
| [Scrolling Credits Video](https://apps.apple.com/us/app/scrolling-credits-video/id6469454751) | Font controls, image/video backgrounds, multilingual UI, particles, advanced export codecs | Background media and better beginner controls; localize based on completed exports by language; particles low priority |

LastReel already has multiple block layouts, timing controls, 4K/advanced export options (device dependent), templates and project sync. Do not rebuild these just because competitors mention them. Actual competitor apps were not installed or usability-tested; claims above come from their public listings/version history.

Recommended order: (1) ship verified auto-save and font picker, (2) real logo/image import and a first-project tutorial, (3) CSV cast/crew import, (4) reusable style presets and image/video backgrounds. Measure first successful saved video, time to save, save failure reasons and repeat export use.

### Revised landscape preview

- [x] Create `output/landscape-preview/LastReel-Landscape-Preview.mp4`: 1920×1080, 24 fps, 29.83 seconds. First 1.5 seconds show the actual portrait app centered in the landscape frame; the rest is only the app's exported credits scrolling upward, with no captions, narration or end card.
- [x] Prepare `output/landscape-preview/LastReel-AppStore-Landscape.mp4` at Apple's accepted 1920×886 iPhone landscape resolution, preserving the full credits image with black side margins and silent stereo audio. Not uploaded or store-reviewed.

Validation for the local UX implementation: export/controller/widget/native-destination tests, phone/tablet font persistence checks, and real offline frame rendering for all three fonts passed in targeted runs. Xcode compiled the simulator demo; Flutter's final copy initially failed because the disk was full. Regenerable build output was removed, the completed app bundle was retained, code signing verified, and installation on the existing iPhone 16 Pro simulator succeeded. No store release was submitted. Current updated screens were visually checked from Flutter test renders; native OS permission dialogs and gallery visibility still require physical-device verification.
