import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/config/features.dart';
import '../../../core/result.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_fields.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_settings.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../core/widgets/ec_toast.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../domain/models/app_user.dart';
import '../../../domain/models/password_policy.dart';
import '../controllers/account_controller.dart';

/// 7.2 — name, email, and how this account signs in. Methods are managed
/// here so someone who signed up with Apple can add an email login for a
/// second device; the only remaining method can't be removed.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen()));

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final _name = TextEditingController(text: ref.read(authStateProvider).value?.displayName ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool _changed(AppUser user) => _name.text.trim().isNotEmpty && _name.text.trim() != (user.displayName ?? '').trim();

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await ref.read(accountControllerProvider).rename(_name.text);
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Ok():
        showEcToast(context, 'Profile saved');
      case Err(:final failure):
        showEcToast(context, failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const SizedBox.shrink();
    final p = context.palette;
    final t = context.type;

    return EcScaffold(
      topBar: EcTopBar(
        title: 'Profile',
        trailing: TextButton(
          onPressed: _changed(user) && !_saving ? _save : null,
          style: TextButton.styleFrom(
            foregroundColor: p.accent,
            textStyle: t.bodyS.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          child: const Text('Save'),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: EcAvatar(initials: user.initials, size: 84, gradient: true)),
          const SizedBox(height: 8),
          Center(
            child: EcButton.text(
              label: 'Change photo',
              size: EcButtonSize.small,
              onPressed: () => showEcToast(context, 'Profile photos are coming soon'),
            ),
          ),
          const SizedBox(height: 14),
          EcTextField(
            controller: _name,
            label: 'Name',
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            onChanged: (_) => setState(() {}),
          ),
          if (user.email != null) ...[
            const SizedBox(height: 16),
            Text('Email', style: t.label),
            const SizedBox(height: 7),
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: p.tint,
                borderRadius: BorderRadius.circular(EcRadius.field),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(user.email!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyL.copyWith(color: p.ink2))),
                  if (user.isEmailVerified) const EcStatusPill('Verified', tone: EcTone.ok),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          EcGroup(label: 'Sign-in methods', children: [
            for (final method in SignInMethod.values)
              if (method != SignInMethod.apple || Features.appleSignIn || user.methods.contains(method))
                _MethodRow(user: user, method: method),
          ]),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(lastSignInMethod.message, style: t.caption.copyWith(height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _MethodRow extends ConsumerWidget {
  final AppUser user;
  final SignInMethod method;
  const _MethodRow({required this.user, required this.method});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final connected = user.methods.contains(method);
    final account = ref.read(accountControllerProvider);

    Future<void> report(Future<Result<AppUser>> action, String done) async {
      final result = await action;
      if (!context.mounted) return;
      switch (result) {
        case Ok():
          showEcToast(context, done);
        case Err(:final failure) when !isCancellation(failure):
          showEcToast(context, failure.message);
        case Err():
      }
    }

    Future<void> onTap() async {
      if (!connected) {
        if (method == SignInMethod.password) {
          final done = await _PasswordSetupSheet.show(context, email: user.email);
          if (done == true && context.mounted) showEcToast(context, 'Email & password connected');
          return;
        }
        await report(account.connect(method), '${method.label} connected');
        return;
      }
      if (!user.canUnlink(method)) {
        showEcToast(context, lastSignInMethod.message);
        return;
      }
      final confirm = await showEcSheet<bool>(
        context,
        builder: (sheet) => EcSheet(
          title: 'Disconnect ${method.label}?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('You’ll sign in with ${user.methods.where((m) => m != method).map((m) => m.label).join(' or ')} instead.', style: t.body),
              const SizedBox(height: 18),
              EcButton(
                label: 'Disconnect',
                variant: EcButtonVariant.destructive,
                onPressed: () => Navigator.of(sheet).pop(true),
              ),
            ],
          ),
        ),
      );
      if (confirm == true && context.mounted) await report(account.disconnect(method), '${method.label} disconnected');
    }

    final subtitle = switch (method) {
      SignInMethod.password when !connected => 'Sign in without Google',
      _ when connected && method != SignInMethod.password => user.email,
      _ => null,
    };

    return EcGroupRow(
      title: method.label,
      subtitle: subtitle,
      chevron: false,
      onTap: onTap,
      trailing: connected
          ? const EcStatusPill('Connected', tone: EcTone.ok)
          : Text(method == SignInMethod.password ? 'Set up ›' : 'Connect',
              style: t.bodyS.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: p.accent)),
    );
  }
}

/// Adds an email & password to an Apple or Google account.
class _PasswordSetupSheet extends ConsumerStatefulWidget {
  final String? email;
  const _PasswordSetupSheet({this.email});

  static Future<bool?> show(BuildContext context, {String? email}) =>
      showEcSheet<bool>(context, builder: (_) => _PasswordSetupSheet(email: email));

  @override
  ConsumerState<_PasswordSetupSheet> createState() => _PasswordSetupSheetState();
}

class _PasswordSetupSheetState extends ConsumerState<_PasswordSetupSheet> {
  late final _email = TextEditingController(text: widget.email ?? '');
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(accountControllerProvider)
        .connect(SignInMethod.password, email: _email.text, password: _password.text);
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop(true);
      case Err(:final failure):
        setState(() {
          _busy = false;
          _error = failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ok = _email.text.contains('@') && PasswordPolicy.isAcceptable(_password.text);
    return EcSheet(
      title: 'Email & password',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EcTextField(
            controller: _email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          EcPasswordField(controller: _password, isNewPassword: true, error: _error, onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),
          for (final rule in PasswordPolicy.rules) EcCheckItem(label: rule.label, met: rule.test(_password.text)),
          const SizedBox(height: 18),
          EcButton(label: 'Connect', busy: _busy, onPressed: ok && !_busy ? _submit : null),
        ],
      ),
    );
  }
}
