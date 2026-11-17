/// The curated set of credit typefaces the roll itself is set in — distinct
/// from the interface face used for app chrome (§5 of the design brief:
/// ship a curated list, not a font zoo).
///
/// This is a domain concept (it is stored in the project document), so it
/// lives here rather than in the theme layer; `core/theme/app_theme.dart`
/// maps each case onto a concrete `TextStyle`.
enum CreditFace {
  grotesque,
  serif,
  condensed;

  String get displayName => switch (this) {
        CreditFace.grotesque => 'Grotesque · Archivo',
        CreditFace.serif => 'Transitional serif · EB Garamond',
        CreditFace.condensed => 'Condensed · Archivo Narrow',
      };

  /// The style name on its own — the font sheet's row title (5.4).
  String get label => switch (this) {
        CreditFace.grotesque => 'Grotesque',
        CreditFace.serif => 'Transitional serif',
        CreditFace.condensed => 'Condensed',
      };

  /// The typeface — the font sheet's mono line under [label].
  String get family => switch (this) {
        CreditFace.grotesque => 'Archivo',
        CreditFace.serif => 'EB Garamond',
        CreditFace.condensed => 'Archivo Narrow',
      };
}
