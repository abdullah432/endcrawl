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
}
