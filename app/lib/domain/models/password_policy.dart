/// The password rules from 0.3, as data the screen renders and the
/// controller enforces — one definition, so the checklist can never tick a
/// rule the submit button doesn't actually check.
///
/// Required: at least 8 characters and one number. A symbol is shown as a
/// rule but is advisory (the design ships it unticked while the button is
/// live), so it strengthens a password without blocking sign-up.
class PasswordRule {
  final String label;
  final bool required;
  final bool Function(String password) test;

  const PasswordRule(this.label, this.test, {this.required = true});
}

abstract final class PasswordPolicy {
  static const minLength = 8;

  static final rules = <PasswordRule>[
    PasswordRule('At least $minLength characters', (p) => p.length >= minLength),
    PasswordRule('One number', (p) => p.contains(RegExp(r'\d'))),
    PasswordRule('One symbol', (p) => p.contains(RegExp(r'[^A-Za-z0-9\s]')), required: false),
  ];

  static bool isAcceptable(String password) =>
      rules.where((r) => r.required).every((r) => r.test(password));
}
