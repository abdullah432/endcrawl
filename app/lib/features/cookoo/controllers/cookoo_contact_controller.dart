import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../bootstrap.dart';
import '../../../core/config/app_links.dart';
import '../data/cookoo_contact_client.dart';
import '../models/cookoo_content.dart';
import 'cookoo_promo_controller.dart';

/// "0.0.7+8" — sent with each request so replies can mention the build.
final cookooAppVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

final cookooContactClientProvider = Provider<CookooContactClient>(
  (ref) => HttpCookooContactClient(AppLinks.cookooContact),
);

/// What the contact form collected.
class CookooContactRequest {
  final CookooNeed need;
  final String name;
  final String email;
  final String idea;
  final CookooBudget budget;

  /// The slide the form was opened from — `s1`…`s4`.
  final String source;

  const CookooContactRequest({
    required this.need,
    required this.name,
    required this.email,
    required this.idea,
    required this.budget,
    required this.source,
  });
}

/// Sends contact requests to cookoo.dev. A request that can't go out now
/// (no connection, a timeout, a server error) is queued on the device and
/// retried: on a timer with backoff while the app is open, and whenever the
/// app comes back to the foreground.
class CookooContactController {
  final Ref _ref;
  Timer? _retry;
  Duration _delay = _firstDelay;
  bool _flushing = false;

  static const _firstDelay = Duration(seconds: 30);
  static const _maxDelay = Duration(minutes: 10);

  CookooContactController(this._ref);

  Future<CookooDelivery> submit(CookooContactRequest request) async {
    _ref.read(analyticsProvider).logEvent('cookoo_contact_submit', {
      'need': request.need.wire,
      'budget': request.budget.wire,
      'source': request.source,
    });
    final payload = _payload(request);
    final result = await _ref.read(cookooContactClientProvider).send(payload);
    if (result == CookooDelivery.retry) {
      final store = _ref.read(cookooStoreProvider);
      await store.setPendingContacts([...store.pendingContacts, jsonEncode(payload)]);
      _schedule();
    }
    return result;
  }

  /// Sends whatever is queued, oldest first. Requests the site refuses are
  /// dropped; the rest stay queued for the next try.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    _retry?.cancel();
    try {
      final store = _ref.read(cookooStoreProvider);
      final pending = store.pendingContacts;
      if (pending.isEmpty) return;
      final client = _ref.read(cookooContactClientProvider);
      final remaining = <String>[];
      for (final (i, encoded) in pending.indexed) {
        final Map<String, Object?> payload;
        try {
          payload = (jsonDecode(encoded) as Map).cast<String, Object?>();
        } on Object {
          continue; // Unreadable — nothing to retry.
        }
        if (await client.send(payload) == CookooDelivery.retry) {
          // Still offline: keep this one and everything after it, untried.
          remaining.addAll(pending.skip(i));
          break;
        }
      }
      // Requests queued while this flush ran are kept too.
      final added = store.pendingContacts.skip(pending.length);
      await store.setPendingContacts([...remaining, ...added]);
      if (remaining.isEmpty && added.isEmpty) {
        _delay = _firstDelay;
      } else {
        _schedule();
      }
    } finally {
      _flushing = false;
    }
  }

  /// Back in the foreground: try now, and restart the backoff.
  void resumed() {
    _delay = _firstDelay;
    flush();
  }

  void _schedule() {
    _retry?.cancel();
    _retry = Timer(_delay, flush);
    _delay = Duration(seconds: math.min(_delay.inSeconds * 2, _maxDelay.inSeconds));
  }

  void dispose() => _retry?.cancel();

  Map<String, Object?> _payload(CookooContactRequest request) {
    final locale = PlatformDispatcher.instance.locale;
    return {
      'need': request.need.wire,
      'name': request.name,
      'email': request.email,
      'idea': request.idea,
      'budget': request.budget.wire,
      'source': 'lastreel_settings_${request.source}',
      // Read, not awaited: the form watches it, so it has long resolved.
      'appVersion': _ref.read(cookooAppVersionProvider).value ?? '',
      'locale': locale.toLanguageTag(),
      'country': locale.countryCode ?? '',
    };
  }
}

final cookooContactControllerProvider = Provider<CookooContactController>((ref) {
  final controller = CookooContactController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

/// Retries queued contact requests at launch and on every return to the
/// foreground. Watched from the app root.
final cookooContactSyncProvider = Provider<void>((ref) {
  final controller = ref.watch(cookooContactControllerProvider);
  final lifecycle = AppLifecycleListener(onResume: controller.resumed);
  ref.onDispose(lifecycle.dispose);
  // After this build, not inside it: flushing reads other providers.
  scheduleMicrotask(controller.flush);
});
