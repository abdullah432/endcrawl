import 'package:lastreel/features/tracking/tracking_authorization.dart';

/// iOS's tracking permission, scripted: [current] until asked, then
/// [answer]. Counts the asks.
class FakeTrackingAuthorization implements TrackingAuthorization {
  TrackingAuthorizationStatus current;
  TrackingAuthorizationStatus answer;
  int requests = 0;

  FakeTrackingAuthorization({
    this.current = TrackingAuthorizationStatus.notDetermined,
    this.answer = TrackingAuthorizationStatus.authorized,
  });

  @override
  Future<TrackingAuthorizationStatus> status() async => current;

  @override
  Future<TrackingAuthorizationStatus> request() async {
    requests++;
    if (current == TrackingAuthorizationStatus.notDetermined) current = answer;
    return current;
  }
}
