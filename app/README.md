# EndCrawl (Flutter app)

A dedicated end-credits roll editor for phones — see the [repo root](../README.md)
for the product summary and the [design handoff](../design/) this was built from.

## Stack

- **Flutter** (iOS & Android), **Riverpod** (`flutter_riverpod`) for state.
- **Feature-based architecture** — each feature owns its `controllers/`,
  `models/`, `repository/`, `screens/`, and `widgets/`:

  ```
  lib/
    core/                 design tokens, theme, small shared widgets
    features/
      project/            the document: blocks, format/fps/timing settings,
                           the roll engine math, undo/redo — the shared
                           domain model every other feature reads from
      templates/           screen 1: starting-template chooser + crash recovery
      format/               screen 2: canvas format & frame rate
      editor/                screen 3: the block list, sheets, transport,
                             status line — the main editing surface
      monitor/                real-time roll playback: geometry, per-block
                             rendering, the animation ticker
      paste/                   paste-and-split bulk entry parser
      export/                   the (simulated) export pipeline
      appendix/                  design-token / component reference screen
  ```

## Notable implementation choices

- **The roll engine** (`features/project/models/roll_engine.dart`) is a pure,
  widget-free port of the prototype's timing math: frame-locked scroll,
  judder/readability checks, duration-lock and speed-lock modes, and the
  "nearest clean runtime" snap suggestions. It has no Flutter dependency and
  is unit-testable in isolation.
- **Block layout measurement**: the roll's scroll math needs each block's
  real on-screen height (for hold-card sequencing, markers, and per-block
  duration estimates) — the same problem the prototype solved by reading
  `offsetTop` off the DOM after layout. `features/monitor/widgets/roll_content.dart`
  does the Flutter equivalent: it renders the roll at full render resolution
  with a `GlobalKey` per block, then measures each block's offset via
  `RenderBox.localToGlobal` in a post-frame callback and reports it back to
  `ProjectController`.
- **Rendering a canvas-resolution roll inside a small preview box**: the
  monitor renders the credit roll at the project's real export resolution
  (e.g. 2048×858) and then visually scales it down to fit the on-screen
  preview, exactly like the prototype's CSS `transform: scale()`. In Flutter
  this needs `OverflowBox` at two levels (see `monitor_view.dart`) so the
  full-resolution content isn't crushed down to the small preview's tight
  layout constraints before it gets scaled.
- **Drag-to-reorder and swipe actions** use Flutter's own `ReorderableListView`
  (long-press to lift, auto-scroll at the edges, for free) and
  `flutter_slidable` (duplicate/mute/delete), rather than hand-rolled pointer
  tracking — same interaction, more idiomatic Flutter.
- **Playback** uses a real-time `Timer`-driven ticker (`PlaybackController`)
  rather than a fixed frame step, so the roll's on-screen speed always
  matches the stated duration regardless of tick rate — the Flutter analogue
  of the prototype's `requestAnimationFrame` loop.

## Scope note

Per product decision, this build targets **full UI/UX fidelity**, not a real
video pipeline: the export sheet's progress, file-size estimates, and
success/failure states are simulated (ported from the prototype's own
simulated `startExport()`), matching how the prototype itself behaves. There
is no on-device video encoder.

## Running it

```
flutter pub get
flutter run
```

## Testing

```
flutter analyze
flutter test
```

`test/widget_test.dart` covers the primary flows: template → format → editor,
opening every sheet (timing, paste & split, export, the cast block editor),
multi-select, and the rotate-to-landscape full-bleed monitor.
