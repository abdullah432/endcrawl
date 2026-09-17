import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/models/app_user.dart';

enum _AccountAction { signOut }

/// Who is signed in, and the way out.
///
/// Signing out doesn't navigate: the auth stream emits null and the gate
/// swaps the tree, so there is one path out of the app regardless of where
/// it was triggered from.
class AccountMenu extends ConsumerWidget {
  final AppUser user;

  const AccountMenu({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_AccountAction>(
      tooltip: 'Account',
      color: EcColors.surfaceOverlay,
      offset: const Offset(0, 44),
      onSelected: (action) async {
        switch (action) {
          case _AccountAction.signOut:
            final result = await ref.read(authRepositoryProvider).signOut();
            if (result case Err(:final failure)) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
            }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.label, style: const TextStyle(fontSize: 13, color: EcColors.textPrimary)),
              if (user.email != null && user.email != user.label)
                Text(user.email!, style: const TextStyle(fontSize: 11, color: EcColors.textTertiary)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: _AccountAction.signOut, child: Text('Sign out')),
      ],
      child: Padding(
        padding: const EdgeInsets.all(EcSpace.s2),
        child: CircleAvatar(
          radius: 14,
          backgroundColor: EcColors.accentWash,
          foregroundImage: user.photoUrl == null ? null : NetworkImage(user.photoUrl!),
          child: Text(
            user.initials,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EcColors.accentPrimary),
          ),
        ),
      ),
    );
  }
}
