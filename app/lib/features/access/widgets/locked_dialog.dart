import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_dialog.dart';
import '../controllers/web_access.dart';
import '../screens/web_access_screen.dart';

/// D8 — what every locked action in the web preview opens, worded for the
/// action that was tried. It lists what the preview already allows, so it
/// reads as an explanation rather than a wall. Esc or "Keep previewing"
/// closes it; "How to get Pro" opens the access page.
Future<void> showWebLockedDialog(BuildContext context, LockedAction action) async {
  final getPro = await showEcDialog<bool>(context, builder: (_) => _LockedDialog(action));
  if (getPro == true && context.mounted) await WebAccessScreen.open(context);
}

class _LockedDialog extends StatelessWidget {
  final LockedAction action;
  const _LockedDialog(this.action);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final line = t.bodyS.copyWith(fontSize: 13, color: p.ink);
    Widget column(String label, List<String> items, {required bool pro}) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: pro ? p.accentWash : p.sheet,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pro ? p.accentLine : p.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: t.eyebrow.copyWith(fontSize: 10, color: pro ? p.accent : p.muted)),
            for (final item in items) ...[const SizedBox(height: 8), Text(item, style: line)],
          ],
        ),
      ),
    );

    return EcDialog(
      semanticLabel: action.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: p.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: p.primaryShadow,
              ),
              child: Icon(Icons.lock_outline_rounded, color: p.onInk, size: 22),
            ),
          ),
          const SizedBox(height: 20),
          Text('PRO ON THE WEB', style: t.eyebrow.copyWith(fontSize: 10.5, color: p.accent)),
          const SizedBox(height: 8),
          Semantics(header: true, child: Text(action.title, style: t.displayL.copyWith(fontSize: 38, height: 1.02))),
          const SizedBox(height: 8),
          Text(
            'You can open this project, play it and read every setting. '
            'To ${action.verb} here, subscribe in the LastReel app, then check access.',
            style: t.body.copyWith(fontSize: 14, height: 1.55),
          ),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                column('In preview', ['✓ Open every project', '✓ Play the roll', '✓ Read every setting'], pro: false),
                const SizedBox(width: 12),
                column('With Pro', [
                  '+ Edit and add blocks',
                  '+ Start new projects',
                  '+ Export every format',
                ], pro: true),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: EcButton(
                  label: 'How to get Pro',
                  size: EcButtonSize.medium,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EcButton.secondary(
                  label: 'Keep previewing',
                  size: EcButtonSize.medium,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The guard every workspace action calls first: in the web preview it
/// explains with the locked dialog and returns true (stop); elsewhere it
/// returns false and the action goes ahead. One check per entry point, so
/// every way into an action — dock, keyboard, menu — is covered.
bool lockedOnWeb(BuildContext context, LockedAction action) {
  if (!ProviderScope.containerOf(context, listen: false).read(webPreviewProvider)) return false;
  showWebLockedDialog(context, action);
  return true;
}
