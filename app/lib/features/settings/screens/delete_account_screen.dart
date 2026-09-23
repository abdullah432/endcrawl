import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/config/app_links.dart';
import '../../../core/result.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_fields.dart';
import '../../../core/widgets/ec_headline.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../core/theme/ec_type.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../domain/models/app_user.dart';
import '../../../domain/models/render_summary.dart';
import '../../library/controllers/library_controller.dart';
import '../controllers/account_controller.dart';

/// 7.6 — what goes, the warning that an App Store subscription keeps
/// billing, and a typed DELETE. The safe button is named by its outcome.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DeleteAccountScreen()));

  static const confirmWord = 'DELETE';

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirm = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _confirm.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete(bool needsPassword) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    // Held before the account goes: the gate swaps the whole tree to the
    // welcome screen, and the toast has to outlive this screen.
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(accountControllerProvider)
        .deleteAccount(password: needsPassword ? _password.text : null);
    switch (result) {
      case Ok():
        messenger.showSnackBar(const SnackBar(content: Text('Account deleted')));
      case Err(:final failure):
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = isCancellation(failure) ? null : failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final user = ref.watch(authStateProvider).value;
    final summaries = ref.watch(projectSummariesProvider).value ?? const [];
    final renders = summaries.where((s) => s.lastRender?.outcome == RenderOutcome.rendered).length;
    final needsPassword = user?.primaryMethod == SignInMethod.password;
    final typed = _confirm.text.trim() == DeleteAccountScreen.confirmWord;
    final ready = typed && (!needsPassword || _password.text.isNotEmpty) && !_busy;

    Widget item(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('–  $text', style: t.body.copyWith(color: p.ink2)),
        );

    return EcScaffold(
      topBar: const EcTopBar(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(caps('Delete account'), style: t.eyebrow.copyWith(color: p.warn)),
          const SizedBox(height: 8),
          EcHeadline('Delete your account and ', emphasis: 'everything in it?', style: t.displayM),
          const SizedBox(height: 16),
          item('${plural(summaries.length, 'project')} and ${plural(renders, 'render')}'),
          item('Profile, email and sign-in methods'),
          item('Settings and preferences'),
          const SizedBox(height: 12),
          EcNotice(
            tone: EcTone.warn,
            title: 'Deleting doesn’t cancel a subscription.',
            body: 'Apple handles billing. Cancel Pro in App Store settings first.',
            actions: [
              EcButton.text(
                label: 'Open subscriptions ›',
                size: EcButtonSize.small,
                onPressed: () => ref.read(externalLinksProvider).openUrl(AppLinks.manageSubscriptions),
              ),
            ],
          ),
          const SizedBox(height: 20),
          EcTextField(
            controller: _confirm,
            label: 'Type ${DeleteAccountScreen.confirmWord} to confirm',
            hint: DeleteAccountScreen.confirmWord,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
          if (needsPassword) ...[
            const SizedBox(height: 14),
            EcPasswordField(
              controller: _password,
              label: 'Your password',
              onChanged: (_) => setState(() {}),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: t.bodyS.copyWith(color: p.warn)),
          ],
          const Spacer(),
          const SizedBox(height: 20),
          EcButton(
            label: 'Delete account permanently',
            variant: EcButtonVariant.destructive,
            busy: _busy,
            onPressed: ready ? () => _delete(needsPassword) : null,
          ),
          const SizedBox(height: 6),
          EcButton.secondary(label: 'Keep my account', onPressed: _busy ? null : () => Navigator.of(context).maybePop()),
          const SizedBox(height: 12),
          Text(
            'This can’t be undone. Backups are purged within 30 days.',
            textAlign: TextAlign.center,
            style: t.caption,
          ),
        ],
      ),
    );
  }
}
