import 'package:app_tracking_transparency/app_tracking_transparency.dart' as att;
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

  static TrackingAuthorizationStatus _map(att.TrackingStatus status) => switch (status) {
    att.TrackingStatus.notDetermined => TrackingAuthorizationStatus.notDetermined,
    att.TrackingStatus.restricted => TrackingAuthorizationStatus.restricted,
    att.TrackingStatus.denied => TrackingAuthorizationStatus.denied,
    att.TrackingStatus.authorized => TrackingAuthorizationStatus.authorized,
    att.TrackingStatus.notSupported => TrackingAuthorizationStatus.notSupported,
  };

  @override
  Future<TrackingAuthorizationStatus> status() async {
    try {
      return _map(await att.AppTrackingTransparency.trackingAuthorizationStatus);
    } on Object {
      return TrackingAuthorizationStatus.notSupported;
    }
  }

  @override
  Future<TrackingAuthorizationStatus> request() async {
    try {
      return _map(await att.AppTrackingTransparency.requestTrackingAuthorization());
    } on Object {
      return TrackingAuthorizationStatus.notSupported;
    }
  }
}

final trackingAuthorizationProvider = Provider<TrackingAuthorization>((ref) => const PluginTrackingAuthorization());

/// The current status. Invalidated after iOS answers and whenever the
/// Privacy row is shown — the answer can change in iOS Settings while the
/// app is in the background.
final trackingStatusProvider = FutureProvider<TrackingAuthorizationStatus>(
  (ref) => ref.watch(trackingAuthorizationProvider).status(),
);
