import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';

/// Whether this build runs in a browser. A provider rather than a bare
/// `kIsWeb` so tests can exercise the web rules.
final runningOnWebProvider = Provider<bool>((ref) => kIsWeb);

/// On the web, LastReel is a Pro workspace: an account without verified
/// Pro (see `ClaimsEntitlementRepository`) gets a read-only preview — it
/// can open, play and read every project, but not change, create or
/// export anything. Never true in the mobile apps, whose Free/Pro rules
/// are unchanged.
final webPreviewProvider = Provider<bool>((ref) {
  if (!ref.watch(runningOnWebProvider)) return false;
  return !(ref.watch(entitlementProvider).value?.isPro ?? false);
});

/// Set once the person leaves the access page for the app — "Preview the
/// app first", or "Open my projects" after unlocking. Until then a free
/// account signing in on the web lands on the access page (D2).
class WebEntry extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(currentUidProvider); // A different account starts over.
    return false;
  }

  void enter() => state = true;
}

final webEntryProvider = NotifierProvider<WebEntry, bool>(WebEntry.new);

/// The workspace actions the web preview locks, each with the wording the
/// locked dialog (D8) uses for it.
enum LockedAction {
  export('Exporting from the browser needs Pro.', 'export'),
  timing('Changing timing in the browser needs Pro.', 'change timing'),
  look('Changing the look in the browser needs Pro.', 'change the look'),
  addBlock('Adding blocks in the browser needs Pro.', 'add blocks'),
  paste('Pasting into a project in the browser needs Pro.', 'paste'),
  edit('Editing in the browser needs Pro.', 'edit'),
  newProject('Starting projects in the browser needs Pro.', 'start projects'),
  manage('Managing projects in the browser needs Pro.', 'rename, duplicate or delete projects');

  final String title;

  /// What was tried, for "To …, edit or add blocks here".
  final String verb;
  const LockedAction(this.title, this.verb);
}

/// Refused by any workspace write while the web is in preview.
const webPreviewLocked = AppFailure(
  FailureKind.permission,
  'LastReel on the web is a preview without Pro. Subscribe in the app, then check access.',
);

enum AccessPhase { entry, checking, notFound, unlocked, failed }

class AccessCheck {
  final AccessPhase phase;

  /// While checking: 0 signed in, 1 asking Google Play, 2 unlocking.
  final int step;
  final String? message;

  const AccessCheck(this.phase, {this.step = 0, this.message});
}

/// "I've subscribed — check access" (D2 → D3 → D5 or D6). Asks the server
/// for a fresh sign-in token and reads Pro from it; nothing is charged.
class AccessCheckController extends Notifier<AccessCheck> {
  @override
  AccessCheck build() {
    ref.watch(currentUidProvider);
    return const AccessCheck(AccessPhase.entry);
  }

  Future<void> check() async {
    if (state.phase == AccessPhase.checking) return;
    state = const AccessCheck(AccessPhase.checking, step: 1);
    final result = await ref.read(entitlementRepositoryProvider).restore();
    switch (result) {
      case Ok(:final value) when value.isPro:
        state = const AccessCheck(AccessPhase.checking, step: 2);
        state = const AccessCheck(AccessPhase.unlocked);
      case Ok():
        state = const AccessCheck(AccessPhase.notFound);
      case Err(:final failure):
        state = AccessCheck(AccessPhase.failed, message: failure.message);
    }
  }
}

final accessCheckProvider = NotifierProvider<AccessCheckController, AccessCheck>(AccessCheckController.new);
