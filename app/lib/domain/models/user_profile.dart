import 'json_support.dart';

/// Account-level data the app keeps beside the identity provider's user:
/// the marketing opt-in from 0.3 and the preferences on Settings (7.1, 7.4).
///
/// Stored at `users/{uid}`. Deliberately holds nothing about the plan: an
/// entitlement the client can write is an entitlement anyone can grant
/// themselves, so plan status lives behind `EntitlementRepository`.
class UserProfile {
  static const int currentSchemaVersion = 1;

  final bool marketingOptIn;
  final Preferences preferences;

  const UserProfile({this.marketingOptIn = false, this.preferences = const Preferences()});

  UserProfile copyWith({bool? marketingOptIn, Preferences? preferences}) => UserProfile(
        marketingOptIn: marketingOptIn ?? this.marketingOptIn,
        preferences: preferences ?? this.preferences,
      );

  Map<String, Object?> toJson() => {
        'schemaVersion': currentSchemaVersion,
        'marketingOptIn': marketingOptIn,
        'preferences': preferences.toJson(),
      };

  factory UserProfile.fromJson(Map<String, Object?> json) => UserProfile(
        marketingOptIn: asBool(json['marketingOptIn'], false),
        preferences: Preferences.fromJson(asMap(json['preferences'])),
      );
}

/// Settings that follow the account to every device.
///
/// Defaults are the design's: helpful switches on, and the two that share
/// data about the user — usage analytics and personalised ads — off.
class Preferences {
  /// Defaults for new projects.
  final double defaultFps;
  final String defaultFormatId;
  final bool safeGuides;
  final bool readabilityWarnings;

  // App.
  final bool haptics;
  final bool renderNotifications;

  // Privacy & data.
  final bool crashReports;
  final bool usageAnalytics;
  final bool personalisedAds;

  const Preferences({
    this.defaultFps = 24,
    this.defaultFormatId = '16x9',
    this.safeGuides = true,
    this.readabilityWarnings = true,
    this.haptics = true,
    this.renderNotifications = true,
    this.crashReports = true,
    this.usageAnalytics = false,
    this.personalisedAds = false,
  });

  Preferences copyWith({
    double? defaultFps,
    String? defaultFormatId,
    bool? safeGuides,
    bool? readabilityWarnings,
    bool? haptics,
    bool? renderNotifications,
    bool? crashReports,
    bool? usageAnalytics,
    bool? personalisedAds,
  }) {
    return Preferences(
      defaultFps: defaultFps ?? this.defaultFps,
      defaultFormatId: defaultFormatId ?? this.defaultFormatId,
      safeGuides: safeGuides ?? this.safeGuides,
      readabilityWarnings: readabilityWarnings ?? this.readabilityWarnings,
      haptics: haptics ?? this.haptics,
      renderNotifications: renderNotifications ?? this.renderNotifications,
      crashReports: crashReports ?? this.crashReports,
      usageAnalytics: usageAnalytics ?? this.usageAnalytics,
      personalisedAds: personalisedAds ?? this.personalisedAds,
    );
  }

  Map<String, Object?> toJson() => {
        'defaultFps': defaultFps,
        'defaultFormatId': defaultFormatId,
        'safeGuides': safeGuides,
        'readabilityWarnings': readabilityWarnings,
        'haptics': haptics,
        'renderNotifications': renderNotifications,
        'crashReports': crashReports,
        'usageAnalytics': usageAnalytics,
        'personalisedAds': personalisedAds,
      };

  factory Preferences.fromJson(Map<String, Object?> json) {
    const d = Preferences();
    return Preferences(
      defaultFps: asDouble(json['defaultFps'], d.defaultFps),
      defaultFormatId: asString(json['defaultFormatId'], d.defaultFormatId),
      safeGuides: asBool(json['safeGuides'], d.safeGuides),
      readabilityWarnings: asBool(json['readabilityWarnings'], d.readabilityWarnings),
      haptics: asBool(json['haptics'], d.haptics),
      renderNotifications: asBool(json['renderNotifications'], d.renderNotifications),
      crashReports: asBool(json['crashReports'], d.crashReports),
      usageAnalytics: asBool(json['usageAnalytics'], d.usageAnalytics),
      personalisedAds: asBool(json['personalisedAds'], d.personalisedAds),
    );
  }
}
