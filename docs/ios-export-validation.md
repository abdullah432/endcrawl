# iOS export validation — 25 September 2026

The physical-device export matrix passes file checks after a native timing fix. Background/resume failed before the lifecycle correction; its device rerun and several native UI checks remain pending. A critical thermal condition was measured during extended 4K testing. This is not a full acceptance pass.

## Environment and method

- Device: iPhone 13 Pro (iPhone14,2), 128 GB; iOS 26.6.2 (23G90), USB connected, Developer Mode enabled.
- macOS 26.5.2; Xcode 26.6 (17F113); CocoaPods 1.16.2.
- Retry used Flutter 3.47.5 stable / Dart 3.13.4. Initial build used Flutter 3.44.3 / Dart 3.12.2, before the installed SDK changed between sessions.
- ffmpeg/ffprobe 9.0.2; MediaInfo 26.05.
- Started from clean `main` at `180dfb3`, pulled `origin/main` (already current), worked on `codex/ios-export-fixes`.
- Native registration, Runner target membership, channel implementation, byte swizzle and row stride were inspected. Native capabilities returned H.264, HEVC, ProRes 422 HQ and ProRes 4444 through 3840 pixels; the UI offered 1280, 1920 HD and 4K UHD. PNG is available separately in Dart.
- Exports use the actual iPhone AVAssetWriter plugin, actual production export controller, offscreen renderer and export/library/editor widgets. A temporary profile entrypoint supplied template projects through the existing in-memory test repository, avoiding changes to cloud projects. No encoder or frame renderer was mocked. This matrix alone does **not** validate sign-in or Firestore persistence.
- Control/measurement harness is outside the app repository. It samples process RSS every 100 ms and records settings, progress, lifecycle transitions, file size and elapsed time. RSS is not Xcode's memory gauge or physical footprint.
- Each video was copied off the phone, inspected with ffprobe and MediaInfo, and fully decoded to frame hashes. Reference frame PNGs were generated on-device and compared with extracted video frames. Exact file hashes and raw inspection outputs are retained in the evidence directory.

## Export matrix

HD = longest edge 1920; UHD = 3840. MB is decimal. FPS lists both `r_frame_rate` and `avg_frame_rate`, which agree for every video after the timing fix. The duration of a PNG sequence describes its project timeline, not a container duration.

| Render | Codec requested | Requested pixels | Actual pixels | Exact fps | Frames expected / actual | Duration (s) | Estimated / actual MB | Wall time (s) | File checks | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|
| QA01 H264 HD 24 | h264 | 1920 × 1080 | 1920 × 1080 | 24/1 | 144 / 144 | 6 | 9.000 / 0.960 | 2.537 | PASS | Baseline codec test |
| QA02 HEVC HD 24 | hevc | 1920 × 1080 | 1920 × 1080 | 24/1 | 144 / 144 | 6 | 6.750 / 0.303 | 2.911 | PASS | HEVC Main |
| QA03 H264 UHD 24 | h264 | 3840 × 2160 | 3840 × 2160 | 24/1 | 144 / 144 | 6 | 36.000 / 4.390 | 10.740 | PASS | Full-resolution rendering |
| QA04 H264 HD 23976 | h264 | 1920 × 1080 | 1920 × 1080 | 24000/1001 | 144 / 144 | 6.006 | 9.009 / 0.960 | 2.658 | PASS | Exact timing after fix |
| QA05 H264 HD 2997 | h264 | 1920 × 1080 | 1920 × 1080 | 30000/1001 | 144 / 144 | 4.8048 | 7.207 / 0.906 | 3.093 | PASS | Exact timing after fix |
| QA06 Vertical HD 24 | h264 | 1080 × 1920 | 1080 × 1920 | 24/1 | 144 / 144 | 6 | 9.000 / 1.416 | 3.021 | PASS | Portrait output |
| QA07 Scope HD 24 | h264 | 1920 × 804 | 1920 × 804 | 24/1 | 144 / 144 | 6 | 6.700 / 0.752 | 2.083 | PASS | Scope output |
| QA08 ProRes422 HD 24 | prores422 | 1920 × 1080 | 1920 × 1080 | 24/1 | 144 / 144 | 6 | 115.500 / 19.219 | 2.661 | PASS | HQ profile confirmed |
| QA09 ProRes4444 Alpha HD 24 | prores4444 | 1920 × 1080 | 1920 × 1080 | 24/1 | 144 / 144 | 6 | 165.000 / 28.728 | 3.171 | PASS | Alpha present, clean premultiplied edges |
| QA10 PNG Alpha HD 24 | png | 1920 × 1080 | 1920 × 1080 | 24/1 project | 144 / 144 | 6 | 104.250 / 10.454 | 30.308 | PASS | 144 sequential RGBA PNGs |
| QA11 Hold Vertical HD 24 | h264 | 1080 × 1920 | 1080 × 1920 | 24/1 | 192 / 192 | 8 | 12.000 / 1.039 | 4.958 | PASS | Hold card alone on black |
| QA12 Crawl HD 24 | h264 | 1920 × 1080 | 1920 × 1080 | 24/1 | 144 / 144 | 6 | 9.000 / 2.903 | 3.099 | PASS | File passes; residual text at ending |

H.264 and HEVC use MP4; ProRes uses MOV. All videos have BT.709 primaries, transfer and matrix tags. ProRes 422 is HQ (`apch`, `yuv422p10le`); ProRes 4444 is `ap4h`, `yuva444p12le`, including alpha. PNG ZIP contains all 144 sequentially named RGBA images, 1920 × 1080, with zero alpha in the background.

## Bitrate and progress

| Render | Target Mbps | Actual Mbps | Below target |
|---|---|---|---|
| QA01 H264 HD 24 | 12.000 | 1.277 | 89.36% |
| QA02 HEVC HD 24 | 9.000 | 0.400 | 95.56% |
| QA03 H264 UHD 24 | 48.000 | 5.850 | 87.81% |
| QA04 H264 HD 23976 | 12.000 | 1.275 | 89.37% |
| QA05 H264 HD 2997 | 12.000 | 1.503 | 87.47% |
| QA06 Vertical HD 24 | 12.000 | 1.884 | 84.30% |
| QA07 Scope HD 24 | 8.933 | 0.999 | 88.82% |
| QA11 Hold Vertical HD 24 | 12.000 | 1.035 | 91.37% |
| QA12 Crawl HD 24 | 12.000 | 3.867 | 67.77% |

The low bitrates reflect mostly-black credits, not a bitrate-setting failure. File-size estimates are conservative; the measured sizes above make the discrepancy explicit. Progress frame counts increased monotonically in every matrix render and finished at N/N. Time-left estimates moved from initial heuristics to measured rates; PNG took about 30 seconds versus the initial approximately 25-second estimate. These are single runs, not a performance benchmark.

## Visual inspection

- Sampled each video's start, scrolling section, midpoint and final frame; decoded every frame without errors. No stripes, skewed rows or tinted white text were observed. White-only content cannot independently prove red/blue channel order; source swizzle is `[2, 1, 0, 3]` and destination stride comes from CVPixelBuffer.
- 4K is rendered at 3840 × 2160 and matches the full-resolution reference; text appears sharp.
- Hold-card sample at frame 96 contains only “THANKS FOR WATCHING” on black. The hold segment starts at frame 66; repeated frames during its stationary portion are intentional.
- Crawl output matches the tilted offscreen reference, including residual text at the final frame. A frame-exact comparison against the interactive preview is still unverified.
- All adjacent repeated frames in ordinary short rolls occur in intentional empty head/tail periods. The hold case also repeats stationary card frames. There were no repeated frames in the ordinary moving-credit portion.
- ProRes 4444 alpha corners are zero. At frames 50 and 72, premultiplied RGB mean absolute differences from the PNG reference are below 0.003/255 over the frame; alpha differences are below 0.002/255. Premultiplied compositing on white reveals no visible dark fringe. Gray role labels are intentionally gray. Do not multiply the decoded premultiplied RGB by alpha a second time.

## Fixes and regression evidence

1. `VideoEncoderPlugin.swift`: explicitly sets the input and movie time scales to `fpsNum`. Baseline 23.976 produced `avg_frame_rate=21600/901`, duration 6.006667 s; baseline 29.97 produced `28800/961`, duration 4.805 s. With the fix the same 144 frames are exactly `24000/1001`, 6.006 s and `30000/1001`, 4.8048 s. Protocol unchanged.
2. Lifecycle correction: pause on inactive, resume only when fully resumed, and recheck pause/cancel after an asynchronously rendered frame. Physical-device background verification is still pending. Regression test now holds the app in inactive state on both sides of the hidden transition; the original implementation advanced from 25 to 48 frames while inactive. Updated implementation passes the regression.
3. CocoaPods lock includes the already-declared `gal` Photos plugin. Flutter SDK refresh regenerated four SDK-pinned transitive versions in `pubspec.lock` (matcher, meta, test_api, vector_math); no new export dependency was introduced. Flutter also changed the commented Podfile platform example from 13 to 15; the actual deployment target was already 15. CocoaPods refreshed the corresponding checksum and Flutter pod checksum.

## Behaviour checks

| Check | Result | Evidence / limits |
|---|---|---|
| Home/background/resume | FAIL before lifecycle fix; device rerun pending | Original 4K job failed at frame 86/1440 with “Operation Interrupted”. Reconnection problems stretched the background interval to about 94 seconds, so this was not a precise ten-second test. |
| Cancel | PASS | Tapped “Cancel render” on-device while QA14 was running. Returned to export settings; run cleared; devicectl confirmed the partial MP4 no longer existed. |
| Photos H.264 | PASS save/play; initial prompt unverified | Tapped Save to Photos; success toast. Photos played the file and showed QA15 Photos H264, H.264, 1920 × 1080, 24 FPS, six seconds, 960 KB. Permission was already granted; no fresh prompt was shown. |
| Photos HEVC / ProRes | Pending | Native UI access was interrupted by physical phone use and Mirroring authentication. |
| Share sheet / Save to Files | Pending | Native UI check still required. |
| Low-space preflight | PASS; actual disk-full write not tested | QA18 requested 4K ProRes 4444 with a 6.6 GB estimate against 4,554,011,569 available bytes. Stopped at frame 0 with “Not enough free space.” and offered “Lower resolution”. The lower-resolution button and actual ENOSPC recovery remain untested. No disk filling was performed. |
| Library | PASS production widgets, in-memory persistence only | QA17 screenshots show the same card changing from “RENDERING 37%” to “RENDERED”. Navigation used the temporary harness. Does not prove Firestore synchronization. |
| Memory / thermals | ISSUE OBSERVED | Instruments Activity Monitor attached to the real Endcrawl PID. Peak physical footprint 480,445,624 bytes (458.19 MiB), sampled RSS peak 403,357,696 bytes (384.67 MiB). The entire 56.17-second capture reported **Critical** thermal state, not induced. Heavy renders were stopped afterward. |
| Responsiveness / crashes | Partial | Cancel responded to a real tap during 4K encoding. UI also painted library progress. No crash or jetsam was observed during completed renders, but thermal throttling cannot be ruled out. Xcode debugger attachment had failed; memory was measured with Instruments rather than the requested Xcode gauge. |

Both longer UHD exports also passed full decoding, exact 720-frame / 30-second timing, dimensions and BT.709 checks. The 720-frame UHD jobs completed in 39.421 s and 35.407 s. The trace spans portions of both jobs, not one isolated cold-start benchmark. There is no pre-test thermal baseline, so the capture does not establish that EndCrawl alone caused the device's thermal condition.

## Build and automated checks

- `flutter pub get` and `pod install`: completed. The lockfile now includes the existing Photos dependency.
- `flutter build ios --debug`: passed initially and again after the native timing fix (374.5 s on the retry).
- Profile build with the lifecycle correction: passed (369.0 s after switching build configurations).
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: **249 passed**, including the strengthened lifecycle regression.
- Normal `lib/main.dart` profile build with all fixes: passed (58.6 s).
- Xcode UI: `Product → Build For → Profiling`, physical iPhone destination, **Build Succeeded** at 12:45 PM.
- Normal `lib/main.dart` profile app was reinstalled and launched successfully after testing; no temporary audit entrypoint remains installed. Sign-in/template interaction through the normal app remains unverified because Mirroring is locked.
- No Swift registration or target-membership repair was necessary. The channel contract remains unchanged.

## Known limitations

- The brief requests iOS 13, but the existing project targets iOS 15 (`app/ios/Runner.xcodeproj/project.pbxproj:497`, also 628 and 680). The installed Firebase Core plugin podspec requires iOS 15. This was not silently downgraded; supporting iOS 13 needs a separate dependency compatibility decision.
- The 3D crawl still has small credits visible near the top on its final frame, unlike the flat roll. The same transformed reference contains them. Likely relevant code is `app/lib/features/monitor/widgets/roll_frame.dart:79` (translation before perspective) and `app/lib/domain/engine/roll_engine.dart:201` (travel determined from untransformed measurements). Left unchanged because correcting shared crawl geometry is broader than native encoder validation; inspect the ending before delivery.
- First-time Photos permission text is present in `app/ios/Runner/Info.plist:27`: “EndCrawl saves the credit rolls you render to your photo library.” The live H.264 save succeeded without a prompt, so first-time prompt presentation was not observed.
- Mirroring required Mac Touch ID/password again after physical iPhone use disconnected it. Its secure password field remained focused at the end of testing. This blocks the remaining UI checks; no authentication settings were changed.
- A follow-up short idle thermal trace stalled while saving and was stopped. No subsequent cool-state measurement is available.
- Evidence and generated videos are local only; no push or merge was performed.

## Evidence

Local artifact directory: `/Users/abdullahkhan/Documents/Development/COOKOO/Projects/endcrawl-ios-export-audit-2026-09-25`.

- `baseline/`: before the timing correction, including the two reproducible timing failures.
- `behaviour/`: two longer 720-frame UHD outputs and their full decode/metadata results; separate behaviour logs retain the background failure and low-space preflight.
- `4k-memory.trace`, `memory-summary.json`, `memory-live.xml`, `thermal.xml`: Instruments capture and parsed memory/thermal evidence.
- `fixed/`: all 12 matrix files after the timing correction, raw ffprobe/MediaInfo output, full-frame hashes, screenshots, decoded/reference frames, `inspection.json`, `quality.json`, and the measured `audit.json`.
- Temporary harness and inspection scripts accompany the evidence for reproducibility; they are not included in production code.

## Complete code and dependency diff

```diff
diff --git a/app/ios/Podfile b/app/ios/Podfile
index 620e46e..9d7ef08 100644
--- a/app/ios/Podfile
+++ b/app/ios/Podfile
@@ -1,5 +1,5 @@
 # Uncomment this line to define a global platform for your project
-# platform :ios, '13.0'
+# platform :ios, '15.0'
 
 # CocoaPods analytics sends network stats synchronously affecting flutter build latency.
 ENV['COCOAPODS_DISABLE_STATS'] = 'true'
diff --git a/app/ios/Podfile.lock b/app/ios/Podfile.lock
index 4cc9d98..b00736f 100644
--- a/app/ios/Podfile.lock
+++ b/app/ios/Podfile.lock
@@ -1266,6 +1266,9 @@ PODS:
     - nanopb (~> 3.30910.0)
   - FirebaseSharedSwift (12.19.0)
   - Flutter (1.0.0)
+  - gal (1.0.0):
+    - Flutter
+    - FlutterMacOS
   - google_sign_in_ios (0.0.1):
     - Flutter
     - FlutterMacOS
@@ -1427,6 +1430,7 @@ DEPENDENCIES:
   - firebase_auth (from `.symlinks/plugins/firebase_auth/ios`)
   - firebase_core (from `.symlinks/plugins/firebase_core/ios`)
   - Flutter (from `Flutter`)
+  - gal (from `.symlinks/plugins/gal/darwin`)
   - google_sign_in_ios (from `.symlinks/plugins/google_sign_in_ios/darwin`)
   - in_app_review (from `.symlinks/plugins/in_app_review/ios`)
   - package_info_plus (from `.symlinks/plugins/package_info_plus/ios`)
@@ -1471,6 +1475,8 @@ EXTERNAL SOURCES:
     :path: ".symlinks/plugins/firebase_core/ios"
   Flutter:
     :path: Flutter
+  gal:
+    :path: ".symlinks/plugins/gal/darwin"
   google_sign_in_ios:
     :path: ".symlinks/plugins/google_sign_in_ios/darwin"
   in_app_review:
@@ -1502,7 +1508,8 @@ SPEC CHECKSUMS:
   FirebaseFirestore: 311722a65983b64e912ef1aa5ab8933cefbbf6d8
   FirebaseFirestoreInternal: c5fe347a024926551b8cb6d6b3ba78f19a7b525e
   FirebaseSharedSwift: c91f36aeaa566e12b682caacc40d34c8303c3124
-  Flutter: cabc95a1d2626b1b06e7179b784ebcf0c0cde467
+  Flutter: 71a624a5bc0c04062bf19101d501e466baf2fb47
+  gal: baecd024ebfd13c441269ca7404792a7152fde89
   google_sign_in_ios: d66ab4c862f03eb4b3cac147ba2d9d7e56ef03f7
   GoogleSignIn: e449a40a92e9f2eea56e98b5214d13725dc5a00a
   GoogleUtilities: 4e0c2ad9fa0d0d18b5c4df8bf57b461cba35b0bb
@@ -1521,6 +1528,6 @@ SPEC CHECKSUMS:
   shared_preferences_foundation: 7036424c3d8ec98dfe75ff1667cb0cd531ec82bb
   url_launcher_ios: 7a95fa5b60cc718a708b8f2966718e93db0cef1b
 
-PODFILE CHECKSUM: 3c63482e143d1b91d2d2560aee9fb04ecc74ac7e
+PODFILE CHECKSUM: 3ba3a73b1b12adcf321a227a745625fe0888cc82
 
 COCOAPODS: 1.16.2
diff --git a/app/ios/Runner/VideoEncoderPlugin.swift b/app/ios/Runner/VideoEncoderPlugin.swift
index 2cb05f7..37f7cfc 100644
--- a/app/ios/Runner/VideoEncoderPlugin.swift
+++ b/app/ios/Runner/VideoEncoderPlugin.swift
@@ -242,6 +242,9 @@ private final class EncodeSession {
     }
     input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
     input.expectsMediaDataInRealTime = false
+    // Keep NTSC frame durations exact instead of rounding to the default 600 ticks.
+    input.mediaTimeScale = self.fpsNum
+    writer.movieTimeScale = self.fpsNum
     adaptor = AVAssetWriterInputPixelBufferAdaptor(
       assetWriterInput: input,
       sourcePixelBufferAttributes: [
diff --git a/app/lib/features/export/controllers/export_controller.dart b/app/lib/features/export/controllers/export_controller.dart
index 3acf182..dc9d548 100644
--- a/app/lib/features/export/controllers/export_controller.dart
+++ b/app/lib/features/export/controllers/export_controller.dart
@@ -203,6 +203,17 @@ class ExportController extends Notifier<ExportState> {
 
         final image = await source.render(i);
         try {
+          // Rendering can yield across a lifecycle change. Keep this frame
+          // until the app is active before handing it to the native encoder.
+          if (job.paused) {
+            pace.stop();
+            await job.resumed;
+            pace.start();
+          }
+          if (job.cancelled) {
+            await session.cancel();
+            return;
+          }
           await session.append(image, i);
         } finally {
           image.dispose();
@@ -262,8 +273,8 @@ class ExportController extends Notifier<ExportState> {
 
   void _watchLifecycle() {
     _lifecycle ??= AppLifecycleListener(
-      onHide: () => _job?.pause(),
-      onShow: () => _job?.resume(),
+      onInactive: () => _job?.pause(),
+      onResume: () => _job?.resume(),
     );
   }
 
diff --git a/app/pubspec.lock b/app/pubspec.lock
index 555cd21..d466fd2 100644
--- a/app/pubspec.lock
+++ b/app/pubspec.lock
@@ -508,10 +508,10 @@ packages:
     dependency: transitive
     description:
       name: matcher
-      sha256: dc0b7dc7651697ea4ff3e69ef44b0407ea32c487a39fff6a4004fa585e901861
+      sha256: "31bd099b47c10cd1aeb55146a2d46ce0277630ecef3f7dae54ad7873f36696cd"
       url: "https://pub.dev"
     source: hosted
-    version: "0.12.19"
+    version: "0.12.20"
   material_color_utilities:
     dependency: transitive
     description:
@@ -524,10 +524,10 @@ packages:
     dependency: transitive
     description:
       name: meta
-      sha256: "1741988757a65eb6b36abe716829688cf01910bbf91c34354ff7ec1c3de2b349"
+      sha256: "307249ce4ff29d58a18e97f6345f539382eb9c9c29ecda628900f31de0443dd9"
       url: "https://pub.dev"
     source: hosted
-    version: "1.18.0"
+    version: "1.19.0"
   mime:
     dependency: transitive
     description:
@@ -833,10 +833,10 @@ packages:
     dependency: transitive
     description:
       name: test_api
-      sha256: "949a932224383300f01be9221c39180316445ecb8e7547f70a41a35bf421fb9e"
+      sha256: "2a122cbe059f8b610d3a5415f42e255b6c17b1f21eee1d960f31080237fb4f11"
       url: "https://pub.dev"
     source: hosted
-    version: "0.7.11"
+    version: "0.7.12"
   typed_data:
     dependency: transitive
     description:
@@ -921,10 +921,10 @@ packages:
     dependency: transitive
     description:
       name: vector_math
-      sha256: d530bd74fea330e6e364cda7a85019c434070188383e1cd8d9777ee586914c5b
+      sha256: "92b9910f66ed1057fd4da7b040ae7c74cafacf885bdc81be496928d5049b032d"
       url: "https://pub.dev"
     source: hosted
-    version: "2.2.0"
+    version: "2.4.3"
   vm_service:
     dependency: transitive
     description:
diff --git a/app/test/features/export/export_test.dart b/app/test/features/export/export_test.dart
index b0aa123..8e35195 100644
--- a/app/test/features/export/export_test.dart
+++ b/app/test/features/export/export_test.dart
@@ -253,13 +253,16 @@ void main() {
       await tester.pump(const Duration(milliseconds: 200));
 
       tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
-      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
       await tester.pump(const Duration(milliseconds: 100));
       final before = app.encoder.appended;
       await tester.pump(const Duration(seconds: 2));
       expect(app.encoder.appended, before);
 
+      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
       tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
+      await tester.pump(const Duration(seconds: 2));
+      expect(app.encoder.appended, before);
+
       tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
       await runRender(tester);
       expect(app.encoder.appended, 48);
```

## Follow-up after this report

Fixed in the app since this run:

- **Judder.** Two causes, both measured in `test/features/export/frame_renderer_test.dart`:
  - Each frame's offset was rounded to a whole pixel. Every template started duration-locked at a fractional speed, so a 3.37 px/frame roll moved 3,3,4,3,4… px. It now measures 3.37 ± 0.003 px.
  - Outputs that aren't a whole multiple of the canvas (2048 scope → 1920) re-snapped every line to the output grid, giving 3.25–4 px steps. It now measures 3.75 ± 0.07 px.

  The renderer now draws at a whole multiple of the canvas and applies the sub-pixel remainder in a single resample. New projects and templates also start at a whole-pixel speed, and 6.1 flags a fractional speed with a one-tap fix.
- **3D crawl ending.** The last lines used to stay near the horizon. They now fade out over the top of the frame, and the roll runs on until they've gone. This also covers steep tilts where the horizon sits inside the frame.

### Still to run on a device

1. **Smoothness.** Render a template project (or any roll) at 1920 HD and at 4K, and a 2.39:1 project at 1920. Check each with:

   ```
   python3 tool/motion_check.py <file>.mp4
   ```

   Expect `SMOOTH`, meaning a spread under 0.1 px at the measured width. Also watch one render on a 24p-capable display. A 60 Hz phone screen always adds 3:2 cadence judder to any 24 fps video, so judge 24 fps there with care, or render at 30/60 fps for social.
2. **Home, then return, mid-render.** This should now resume and finish with the exact frame count.
3. **Save to Photos.** Test HEVC and ProRes, and check that the first-time permission prompt text reads "LastReel…".
4. **Share sheet and Save to Files.** Check both hand over the file.
5. **Lower resolution.** Tap it from the low-space failure screen.
6. **Thermals.** Note the thermal state during a long 4K render. The earlier run reached Critical.
