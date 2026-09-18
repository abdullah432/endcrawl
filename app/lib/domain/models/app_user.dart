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

  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.isEmailVerified = false,
  });

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

  @override
  bool operator ==(Object other) => other is AppUser && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;
}

extension on String {
  String characters(int count) => substring(0, count.clamp(0, length)).toUpperCase();
}
