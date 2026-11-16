import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart'
    as att;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where App Tracking Transparency stands for this app, as iOS reports it.
enum TrackingAuthorizationStatus {
  /// iOS hasn't asked yet: the one state in which it can.
  notDetermined,

  /// Turned off for every app (a managed device, a child's account).
  restricted,
  denied,
  authorized,

  /// Not iOS 14+, so nothing to ask.
  notSupported;

  bool get allowed => this == authorized;
}

/// iOS's tracking permission, behind one seam: the pre-prompt and the
/// Privacy row read and ask through it, and tests replace it.
abstract interface class TrackingAuthorization {
  Future<TrackingAuthorizationStatus> status();

  /// Shows iOS's own alert if it still can, and returns the answer.
  Future<TrackingAuthorizationStatus> request();
}

class PluginTrackingAuthorization implements TrackingAuthorization {
  const PluginTrackingAuthorization();

  static TrackingAuthorizationStatus _map(att.TrackingStatus status) =>
      switch (status) {
        att.TrackingStatus.notDetermined =>
          TrackingAuthorizationStatus.notDetermined,
        att.TrackingStatus.restricted => TrackingAuthorizationStatus.restricted,
        att.TrackingStatus.denied => TrackingAuthorizationStatus.denied,
        att.TrackingStatus.authorized => TrackingAuthorizationStatus.authorized,
        att.TrackingStatus.notSupported =>
          TrackingAuthorizationStatus.notSupported,
      };

  @override
  Future<TrackingAuthorizationStatus> status() async {
    try {
      return _map(
        await att.AppTrackingTransparency.trackingAuthorizationStatus,
      );
    } on Object {
      return TrackingAuthorizationStatus.notDetermined;
    }
  }

  @override
  Future<TrackingAuthorizationStatus> request() async {
    try {
      await waitForActiveApp();
      return _map(
        await att.AppTrackingTransparency.requestTrackingAuthorization(),
      );
    } on Object {
      return TrackingAuthorizationStatus.notDetermined;
    }
  }
}

final trackingAuthorizationProvider = Provider<TrackingAuthorization>(
  (ref) => const PluginTrackingAuthorization(),
);

/// The current status. Invalidated after iOS answers and whenever the
/// Privacy row is shown — the answer can change in iOS Settings while the
/// app is in the background.
final trackingStatusProvider = FutureProvider<TrackingAuthorizationStatus>(
  (ref) => ref.watch(trackingAuthorizationProvider).status(),
);

/// A request can be ignored while iOS is inactive or presenting another alert.
Future<void> waitForActiveApp() async {
  final binding = WidgetsBinding.instance;
  if (binding.lifecycleState == null ||
      binding.lifecycleState == AppLifecycleState.resumed) {
    return;
  }
  final observer = _ActiveObserver();
  binding.addObserver(observer);
  try {
    await observer.resumed.future;
  } finally {
    binding.removeObserver(observer);
  }
}

class _ActiveObserver extends WidgetsBindingObserver {
  final resumed = Completer<void>();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !resumed.isCompleted) {
      resumed.complete();
    }
  }
}

/// Every AdMob entry point waits here before UMP, SDK initialization or ads.
/// An undecided response never opens the gate; a real denial does.
class TrackingConsentGate {
  final TrackingAuthorization authorization;
  final _decision = Completer<void>();
  TrackingConsentGate(this.authorization);

  Future<void> wait() async {
    resolve(await authorization.status());
    await _decision.future;
  }

  void resolve(TrackingAuthorizationStatus status) {
    if (status != TrackingAuthorizationStatus.notDetermined &&
        !_decision.isCompleted) {
      _decision.complete();
    }
  }

  void dispose() {
    if (!_decision.isCompleted) _decision.complete();
  }
}

final trackingConsentGateProvider = Provider<TrackingConsentGate>((ref) {
  final gate = TrackingConsentGate(ref.watch(trackingAuthorizationProvider));
  ref.onDispose(gate.dispose);
  return gate;
});
