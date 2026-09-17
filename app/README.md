# EndCrawl (Flutter app)

A dedicated end-credits roll editor for phones — see the [repo root](../README.md)
for the product summary and the [design handoff](../design/) this was built from.

## Stack

- **Flutter** (iOS & Android), **Riverpod** (`flutter_riverpod`) for state.
- **Layered, with feature-first UI.** Shared domain models and the data layer
  are declared once, centrally; each feature owns only its own screens,
  widgets and controllers:

  ```
  lib/
    bootstrap.dart      the one DI seam: builds the repository, which
                        main.dart injects into the root ProviderScope
    core/               design tokens, theme, Result/AppFailure, utils
    domain/
      models/           Project, CreditBlock (sealed), ProjectSettings,
                        CanvasFormat, CreditFace — the stored schema
      engine/           the roll timing/geometry math (pure Dart)
    data/
      repositories/     ProjectRepository (interface) +
                        LocalProjectRepository, TemplateRepository
      sources/          ProjectLocalStore — JSON documents on disk
    features/
      library/          home: recent projects, resume / crash recovery
      templates/        starting-template chooser
      format/           canvas format & frame rate
      editor/           block list, sheets, transport, status line
      monitor/          real-time roll playback and rendering
      paste/            paste-and-split bulk entry parser
      export/           the (simulated) export pipeline
      appendix/         design-token / component reference screen
      project/          controller for the currently open document
  ```

  Domain models are not owned by a feature because the document is read by
  the editor, the monitor, the library and export alike — burying it inside
  one feature would make the other three reach across a sibling boundary.

## Data layer

Projects are documents, stored one-per-file as JSON and shaped to map
straight onto `users/{uid}/projects/{projectId}` when Firestore is added:

- **`ProjectRepository` is the only seam.** Nothing above it names a store.
  `LocalProjectRepository` is the on-device implementation; a Firestore one
  implements the same interface, and the choice is made once, in
  `bootstrap.dart`. Tests inject an in-memory fake through that same seam.
- **Blocks are embedded in the project document**, not a subcollection —
  v1 has no collaborative editing, a 400-name cast is well under 50 KB
  against Firestore's 1 MB document limit, and embedding keeps a save atomic
  and an open a single read. `Project`'s doc comment records the escape hatch.
- **Failures don't cross layers as exceptions.** Repository calls return
  `Result<T>`, so callers deal with `AppFailure` explicitly; its kinds
  already include `permission` and `network` for the Firestore case.
- **The schema is versioned** (`schemaVersion` + `migrateProjectJson`), enums
  travel as names rather than indices, and a document from a *newer* build
  fails loudly instead of being silently misread. An unknown block type
  throws rather than being skipped, because silently dropping a block would
  destroy the user's content on the next autosave.
- **Writes are atomic** — written to a temp file and renamed into place, so
  a crash mid-save leaves the previous version intact.
- **Ids are Firestore-shaped**: 20 characters from Firestore's own auto-id
  alphabet, so an id minted offline is a valid document id later.

## Autosave and crash recovery

There is no save button. Every document mutation routes through
`ProjectController._writeDocument`, which stamps `updatedAt` and schedules a
debounced write; backgrounding the app flushes anything still pending.
Opening a project sets `openedAt`, and a clean close clears it — so a project
still flagged as open at launch is one the app was killed with. That is what
makes the library's recovery card real, rather than the hardcoded banner the
prototype had.

Note that Riverpod forbids modifying a provider from a widget lifecycle
callback, so open/close are driven by the navigation actions themselves
(`markOpened` at each entry point, `closeProject` from `PopScope`) rather
than from `initState`/`dispose`.

## Notable implementation choices

- **The roll engine** (`domain/engine/roll_engine.dart`) is a pure,
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
- **Serialization is hand-written** rather than generated. The sealed block
  hierarchy needs an explicit type discriminator either way, and keeping it
  by hand avoids a `build_runner` step for the sake of a few dozen lines.
  `json_support.dart` centralises the defensive reads — notably that a JSON
  number decodes as `int` when it has no fractional part, so every `double`
  field must go through `num`.

## Scope note

Per product decision, this build targets **full UI/UX fidelity**, not a real
video pipeline: the export sheet's progress, file-size estimates, and
success/failure states are simulated (ported from the prototype's own
simulated `startExport()`), matching how the prototype itself behaves. There
is no on-device video encoder.

Firebase (Authentication + Firestore) is not wired up yet — the data layer
above is the groundwork for it.

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

- `test/domain/` — schema round-trips for every block type, enum-by-name
  stability, forward-version and unknown-type rejection.
- `test/data/` — the local repository against a temp directory: ordering,
  deletion, corrupt-document tolerance, atomic writes, path-traversal refusal.
- `test/widget_test.dart` — library (empty/list/resume/recovery/error),
  the new-project flow, autosave, every editor sheet, multi-select, and the
  rotate-to-landscape full-bleed monitor, all against an in-memory
  repository injected through `projectRepositoryProvider`.
