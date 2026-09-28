/// The signed-in account, as the app understands it.
///
/// A deliberately small projection of the provider's user object: nothing
/// above the data layer should depend on `firebase_auth`'s `User`, so that
/// swapping or mocking the provider stays a data-layer concern.
class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool isEmailVerified;

  /// How this account can sign in. Drives the verify-email gate (only
  /// email/password accounts need it) and the sign-in methods on 7.2.
  final Set<SignInMethod> methods;

  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.isEmailVerified = false,
    this.methods = const {},
  });

  /// An email/password sign-up that hasn't clicked its verification link.
  /// Apple and Google accounts arrive already verified by the provider, so
  /// any account that has one of those never sees the verify screen.
  bool get needsEmailVerification =>
      !isEmailVerified && methods.contains(SignInMethod.password) && methods.length == 1;

  /// The method shown on the Settings profile card ("Signed in with Apple").
  /// Social providers win over the password because that's the one people
  /// remember tapping.
  SignInMethod? get primaryMethod {
    for (final m in const [SignInMethod.apple, SignInMethod.google, SignInMethod.password]) {
      if (methods.contains(m)) return m;
    }
    return null;
  }

  AppUser copyWith({String? displayName, bool? isEmailVerified, Set<SignInMethod>? methods}) => AppUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        photoUrl: photoUrl,
        isEmailVerified: isEmailVerified ?? this.isEmailVerified,
        methods: methods ?? this.methods,
      );

  /// A method can be removed only while another remains — there must
  /// always be a way back in (7.2).
  bool canUnlink(SignInMethod method) => methods.contains(method) && methods.length > 1;

  /// What to show in the account menu: a name if there is one, otherwise the
  /// email, otherwise something that is at least not blank.
  String get label => displayName?.trim().isNotEmpty == true
      ? displayName!.trim()
      : (email?.trim().isNotEmpty == true ? email!.trim() : 'Signed in');

  /// One or two letters for the avatar.
  String get initials {
    final source = displayName?.trim().isNotEmpty == true ? displayName!.trim() : email?.trim() ?? '';
    if (source.isEmpty) return '?';
    final words = source.split(RegExp(r'[\s@._-]+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.characters(2);
    return '${words[0].characters(1)}${words[1].characters(1)}';
  }

  // Value equality over every field, not just the uid: the auth stream
  // re-emits the same account when it is verified or renamed, and a
  // uid-only == would let Riverpod swallow that update as "unchanged".
  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName &&
      other.photoUrl == photoUrl &&
      other.isEmailVerified == isEmailVerified &&
      other.methods.length == methods.length &&
      other.methods.containsAll(methods);

  @override
  int get hashCode => Object.hash(uid, email, displayName, photoUrl, isEmailVerified, Object.hashAllUnordered(methods));
}

/// The ways into an account.
enum SignInMethod {
  apple('Apple'),
  google('Google'),
  password('Email & password');

  final String label;
  const SignInMethod(this.label);
}

extension on String {
  String characters(int count) => substring(0, count.clamp(0, length)).toUpperCase();
}
