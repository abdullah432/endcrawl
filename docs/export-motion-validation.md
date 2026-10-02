# Export motion investigation — 2 October 2026

Status: cause identified and verified in complete exported files on iPhone and Android. Perceptual acceptance of the 60 fps result on the iPhone is **pending the user's review in Photos**. Playback cadence was not captured on device (see Limits).

## Cause

The judder in `MOTION QA.mp4` is not a rendering, timing or encoder fault. The file is a technically perfect 30 fps roll: every frame is an exact 11.000 px translation of the previous one (a whole-pixel shift leaves zero residual), with no repeated or skipped frames, no rasterization shimmer and uniform timestamps. The 17 doubled packet intervals in the file are in the pre-roll that the Photos trim discards.

The judder is temporal sampling. On an iPhone 13 Pro the 1080-wide video plays 390 pt wide, so 11 px/frame at 30 fps is about **119 pt/s, moving in 4 pt jumps every 33 ms**. The eye tracks the text smoothly while the picture jumps, which reads as judder. The onboarding hero is not comparable: it moves 420 pt in 18 s (**23 pt/s**) and Flutter draws it at **120 Hz** on ProMotion (`CADisableMinimumFrameDurationOnPhone`), so about 0.2 pt per refresh, roughly 20× smaller steps.

Only two things shrink the step: a higher frame rate or a slower roll. The half-frame motion blur does neither. At 30 fps it cuts edge sharpness to 15% and leaves the 11 px step in place.

## A rendering defect found on the way, now fixed

At the same runtime, 60 fps halves a whole-pixel speed to 5.5 px/frame. Every other frame then lands on a half pixel and was bilinearly resampled, so frames alternated between crisp and soft: a 30 Hz shimmer. On device, sharpness alternated **1.55×** between even and odd frames. The earlier 60 fps samples hid this because they had blur on.

`FrameRenderer.render` now keeps a flat roll at one sharpness on every frame:

- **Half-pixel speeds** are biased a quarter pixel. Frames alternate between the ¼ and ¾ phases, mirror-image filters with equal sharpness, at about 74% of a whole-pixel frame.
- **Other fractional speeds** (for example, duration-locked rolls) average one pixel of travel. Variation drops from up to 54% to about 8%.
- **Whole-pixel speeds** are untouched and stay pixel-exact.
- **Holds, perspective and the optional blur** are unchanged.

The 180° blur is now opt-in. It is labelled "Motion blur", defaults to off, and projects without the field render sharp.

The branch's runtime-preserving 60 fps changes are kept: `setFps` scales speed, the export sheet's "Render · 60 fps" option, and Android's separate 60 fps size limits.

## Verification

Complete, full-runtime exports used the production `FrameRenderer`, the native H.264 encoder and the production bit rate. The project was the MOTION QA vertical template, with local fixtures only and no account or cloud writes. Each file was decoded frame by frame on the Mac.

| Device | Clip | Frames / runtime | Step (px/frame) | Edge sharpness | Frame-to-frame sharpness change |
|---|---|---|---|---|---|
| iPhone 13 Pro | A: 30 fps, 11 px, sharp | 743 / 24.77 s* | 11.0000 | 4987 | 1.1% |
| iPhone 13 Pro | B: 30 fps, 11 px, 180° blur | 741 / 24.70 s | 11.000 | 759 | 0.9% |
| iPhone 13 Pro | C: 60 fps, 5.5 px, before fix | 1482 / 24.70 s | 5.500 | 4021 | **42.8%** (even/odd 1.55) |
| iPhone 13 Pro | D: 60 fps, 5.5 px, 180° blur | 1482 / 24.70 s | 5.500 | 1980 | 2.5% |
| iPhone 13 Pro | **C2: 60 fps, 5.5 px, fixed** | 1482 / 24.70 s | 5.5000 | 3567 | **0.9%** (even/odd 1.004) |
| iPhone 13 Pro | E: 30 fps, 4 px, sharp (slow) | 1512 / 50.40 s | 4.000 | 4972 | 0.7% |
| iPhone 13 Pro | F: 30 fps, 7.37 px, fixed | 958 / 31.93 s | 7.379 | 3241 | 5.0% |
| Android 14 emulator | 30 fps, 11 px, 1080p | 741 / 24.70 s | 11.000 | 5558 | 1.0% |
| Android 14 emulator | 60 fps, 5.5 px, 720p (fixed) | 1482 / 24.70 s | 3.6667 (= 5.5 × 720/1080) | 6302 | 2.3% |
| Android 14 emulator | 60 fps, 1080p | skipped: encoder reports a 1280 limit at 60 fps | | | |
| Android 14 emulator | 30 fps, 7.37 px, 1080p (fixed) | 958 / 31.93 s | 7.366 | 3504 | 7.1% |

All timestamps are exactly even (Δt constant to 0.01 ms). There are no repeated or skipped frames during motion; the only irregular steps are the first and last frames of motion. Speeds were measured over 10–12 frame spans to avoid sub-pixel estimator bias. 60 fps preserves the 30 fps runtime exactly (1482/60 = 741/30).

\* A was the first render in a fresh process, and its timing ran 2 frames long. Flutter relays out text after a font loads only on the app's next frame, which the offscreen renderer never waited for, so the roll was measured with fallback-font line metrics (18 px more travel). The pixels were identical. `FrameRenderer.open` now rebuilds the roll from fresh render objects once fonts are in. Opening the project three times in a fresh process now gives 741 frames / 4845.87 px every time, on both the iPhone and the emulator.

`flutter analyze`: no issues. `flutter test`: **323 passed, 5 skipped**, including a new renderer test. With the fix disabled, that test fails at 1.46× alternation, matching the device; with the fix it passes.

## Limits and tradeoffs

- **30 fps at this speed will still judder.** No renderer change can remove an 11 px step at 30 Hz. The options are 60 fps at the same runtime, or a slower roll (longer runtime).
- **60 fps needs encoder support.** Many Android devices cap 60 fps below 1080p; the emulator caps at 720p. There the choice is 720p60 or 1080p30 with a slower roll. Physical Android hardware was not tested.
- **60 fps doubles render time and file size.** It also won't suit a 24/25/30 fps editing timeline, so the project rate stays the user's choice.
- **Half-pixel frames are slightly softer.** They keep about 74% of whole-pixel edge sharpness, uniformly across frames. Exact whole-pixel speeds stay pixel-exact.
- **24 fps on a 60 Hz phone adds 3:2 pulldown.** Uneven cadence there is a property of the playback display, not the file.
- **Playback cadence was not recorded on the device.** macOS refused screen-capture access to the command-line recorder, and QuickTime control was declined. The four review clips (A, B, C2, E) were saved to the iPhone's Photos, in that order, for visual comparison.

Evidence is outside the repository at `endcrawl-motion-audit-2026-10-02/`: `ab/` and `ab-android/` (all clips), the harnesses `ab_full.dart`, `ab_android.dart` and `ab_save.dart`, and run logs. The normal `lib/main.dart` profile app was reinstalled and launched on the iPhone and the emulator after testing.
