# EndCrawl

A dedicated end-credits roll editor for phones — an indie filmmaker, YouTuber,
or film student produces a broadcast-clean rolling credit sequence on their
phone in under 60 seconds. No AI, no keyframing: the runtime is the input,
the motion is derived.

This repo contains the real Flutter implementation, built from the interactive
prototype exported by Claude Design (see [`design/`](design/)).

## Contents

- [`app/`](app/) — the Flutter app (iOS & Android). See [`app/README.md`](app/README.md)
  for architecture, setup, and how to run it.
- [`design/`](design/) — the original Claude Design handoff bundle this app was
  built from: the design prompt, chat transcript, and the interactive HTML/JS
  prototype (`design/project/EndCrawl.dc.html`). Kept for reference; not part
  of the shipped app.

## Status

UI/UX is implemented with full fidelity to the prototype: format & fps setup,
the block editor (title, two-column cast, department, hold cards, logos,
soundtrack, special thanks, spacers), the roll engine (frame-locked scroll,
judder/readability checks, duration & speed lock), the real-time monitor
(2D/3D look, backgrounds, safe guides, rotate-to-preview), paste-and-split
bulk entry, and the export flow. Export itself is simulated — there is no
video encoder behind it in this build.

Projects persist on device: a versioned document schema, a repository
interface with a local JSON-document implementation, debounced autosave, a
project library, and real crash recovery. See
[`app/README.md`](app/README.md#data-layer) for the schema and the layering.

**Next:** Firebase Authentication (email/password + Google Sign-in) and
Firestore, dropped in behind the existing `ProjectRepository` seam.
