import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../bootstrap.dart';
import '../../../core/config/app_links.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_logo.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../domain/models/app_user.dart';
import '../../settings/controllers/settings_controller.dart';
import '../controllers/web_access.dart';

/// D2–D6 — LastReel Pro on the web: what the desk adds, the hand-off to
/// the phone (Pro is bought in the Android app through Google Play), and
/// the check when the person comes back. The web never sells or bills.
///
/// Free accounts land here after signing in on the web; "Preview the app
/// first" goes on to the read-only library, and every locked action in the
/// preview leads back here.
class WebAccessScreen extends ConsumerWidget {
  const WebAccessScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WebAccessScreen()));

  /// Leaves for the app: back to where it was opened from, or — as the
  /// signed-in landing page — on into the library.
  static void leave(BuildContext context, WidgetRef ref) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      ref.read(webEntryProvider.notifier).enter();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final check = ref.watch(accessCheckProvider);
    final unlocked = check.phase == AccessPhase.unlocked;
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    final pitch = _Pitch(wide: wide);
    final card = unlocked ? _UnlockedCard(user: user) : _HowToCard(user: user, check: check);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: EcGround(
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(user: user, showPreview: !unlocked),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(wide ? 96 : 24, wide ? 0 : 12, wide ? 96 : 24, 40),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: wide ? constraints.maxHeight - 40 : 0),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: pitch),
                                const SizedBox(width: 72),
                                SizedBox(width: 540, child: card),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [pitch, const SizedBox(height: 32), card],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  final AppUser? user;
  final bool showPreview;
  const _TopBar({required this.user, required this.showPreview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final narrow = MediaQuery.sizeOf(context).width < 720;
    return SizedBox(
      height: 68,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: narrow ? 20 : 40),
        child: Row(
          children: [
            const EcLogo(size: 13),
            const SizedBox(width: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: p.line2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('WEB', style: t.eyebrow.copyWith(fontSize: 10, letterSpacing: 1.2)),
            ),
            const Spacer(),
            if (showPreview)
              TextButton(
                onPressed: () => WebAccessScreen.leave(context, ref),
                style: TextButton.styleFrom(foregroundColor: p.accent, minimumSize: const Size(44, 44)),
                child: Text('Preview the app first', style: t.buttonSmall.copyWith(fontSize: 13.5, color: p.accent)),
              ),
            if (user != null && !narrow) ...[
              const SizedBox(width: 18),
              Container(
                height: 40,
                padding: const EdgeInsets.only(left: 14, right: 6),
                decoration: BoxDecoration(
                  color: p.glass,
                  border: Border.all(color: p.glassEdge),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Text(user!.email ?? user!.label, style: t.bodyS.copyWith(fontSize: 12.5)),
                    const SizedBox(width: 10),
                    EcAvatar(initials: user!.initials, size: 30),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pitch extends StatelessWidget {
  final bool wide;
  const _Pitch({required this.wide});

  static const _features = [
    (Icons.view_column_outlined, 'Three panes, nothing modal', 'Blocks, monitor and settings side by side.'),
    (Icons.straighten_rounded, 'A time-true timeline', 'Every block drawn at its real length.'),
    (Icons.keyboard_outlined, 'Keyboard-fast entry', 'Paste a call sheet, Tab through every row.'),
    (Icons.download_rounded, 'Every Pro format', 'ProRes, PNG alpha and 4K. No ads.'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final headline = t.displayXL.copyWith(fontSize: wide ? 76 : 48, height: 0.98);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LASTREEL PRO · ON THE WEB', style: t.eyebrow.copyWith(fontSize: 11, letterSpacing: 2, color: p.accent)),
        const SizedBox(height: 26),
        Semantics(
          header: true,
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Your credits, '),
                TextSpan(
                  text: 'at a desk.',
                  style: headline.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
            style: headline,
          ),
        ),
        const SizedBox(height: 26),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            'The web app is part of LastReel Pro. Subscribe once in the mobile app and this account opens '
            'the full desk editor here, with the projects you already made.',
            style: t.bodyL.copyWith(fontSize: wide ? 17 : 15.5, height: 1.55, color: p.ink2),
          ),
        ),
        const SizedBox(height: 32),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          // Two by two on the desktop (D2), however wide the column ends up.
          child: LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 32,
              runSpacing: 22,
              children: [
                for (final (icon, title, body) in _features)
                  SizedBox(
                    width: wide ? (constraints.maxWidth - 32) / 2 : 420,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: p.line),
                          ),
                          child: Icon(icon, size: 18, color: p.accent),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: t.titleS),
                              const SizedBox(height: 3),
                              Text(body, style: t.bodyS.copyWith(fontSize: 13, color: p.muted, height: 1.45)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (wide) ...[const SizedBox(height: 32), const _CastStrip()],
      ],
    );
  }
}

/// The small black credit strip under the pitch — a cast block, as a
/// render would set it.
class _CastStrip extends StatelessWidget {
  const _CastStrip();

  @override
  Widget build(BuildContext context) {
    final credit = GoogleFonts.archivoNarrow(fontSize: 12.5, letterSpacing: 1.5, height: 1.9, color: Colors.white);
    Widget row(String role, String name) => SizedBox(
      width: 360,
      child: Row(
        children: [
          Expanded(
            child: Text(
              role.toUpperCase(),
              textAlign: TextAlign.right,
              style: credit.copyWith(color: Colors.white.withValues(alpha: .6)),
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Text(name.toUpperCase(), style: credit.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        height: 118,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x990C6EC8), offset: Offset(0, 30), blurRadius: 60, spreadRadius: -34),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('CAST', style: credit.copyWith(fontSize: 9, letterSpacing: 3, color: Colors.white54)),
                  const SizedBox(height: 4),
                  row('Renny', 'Sofia Alvarez'),
                  row('Marcus', 'Idris Oyelaran'),
                ],
              ),
            ),
            Positioned(
              left: 14,
              bottom: 10,
              child: Text(
                'THE LONG WAY DOWN · 02:41',
                style: context.type.mono.copyWith(fontSize: 9.5, letterSpacing: 1, color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The white card the right column is built on.
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card({required this.child, this.padding = const EdgeInsets.fromLTRB(32, 30, 32, 26)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.line),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Color(0x733C2814), offset: Offset(0, 40), blurRadius: 80, spreadRadius: -40),
        ],
      ),
      child: child,
    );
  }
}

/// D2–D5: three steps to Pro on the phone, then the check.
class _HowToCard extends ConsumerWidget {
  final AppUser? user;
  final AccessCheck check;
  const _HowToCard({required this.user, required this.check});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final email = user?.email ?? 'this account';
    final links = ref.read(externalLinksProvider);
    final controller = ref.read(accessCheckProvider.notifier);

    Widget step(int n, String lead, String rest) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
            child: Text('$n', style: t.mono.copyWith(fontSize: 11, color: p.onInk)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: lead,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: ' $rest',
                    style: TextStyle(color: p.muted),
                  ),
                ],
              ),
              style: t.bodyS.copyWith(fontSize: 13.5, height: 1.45, color: p.ink),
            ),
          ),
        ],
      ),
    );

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('HOW TO GET PRO', style: t.eyebrow.copyWith(fontSize: 10.5)),
          const SizedBox(height: 6),
          Text('Subscribe in the mobile app.', style: t.displayM.copyWith(fontSize: 32, height: 1.05)),
          const SizedBox(height: 20),
          step(1, 'Get LastReel on Android.', 'Scan the code or use the button below.'),
          step(2, 'Sign in as $email.', 'The same account as this browser.'),
          step(3, 'Open Settings › LastReel Pro.', 'Subscribe through Google Play, then come back here.'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.sheet,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.line),
            ),
            child: Row(
              children: [
                Semantics(
                  label: 'QR code that opens LastReel in Google Play',
                  image: true,
                  child: Container(
                    width: 118,
                    height: 118,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.line),
                    ),
                    child: QrImageView(
                      data: AppLinks.playStoreListing.toString(),
                      padding: EdgeInsets.zero,
                      eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: p.ink),
                      dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: p.ink),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Scan with your phone’s camera.', style: t.bodyS.copyWith(color: p.muted)),
                      const SizedBox(height: 10),
                      _PlayBadge(onTap: () => links.openUrl(AppLinks.playStoreListing)),
                      const SizedBox(height: 10),
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.line2),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('iPhone & iPad', style: t.bodyS.copyWith(color: p.muted)),
                            ),
                            Text('COMING SOON', style: t.pill.copyWith(fontSize: 10, color: p.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          switch (check.phase) {
            AccessPhase.checking => _Checking(step: check.step),
            AccessPhase.notFound => _Problem(
              title: 'No Pro subscription on this account.',
              body:
                  'We checked $email. If you subscribed with another account, sign in with that one. '
                  'Still locked? In the app, tap Settings › LastReel Pro › Restore purchase, then try again.',
              onRetry: controller.check,
              onSwitch: () => ref.read(settingsControllerProvider).signOut(),
            ),
            AccessPhase.failed => _Problem(
              title: 'We couldn’t check right now.',
              body: check.message ?? 'Check your connection and try again.',
              onRetry: controller.check,
            ),
            _ => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EcButton(label: 'I’ve subscribed — check access', onPressed: controller.check),
                const SizedBox(height: 10),
                Text(
                  'We ask Google Play about this account. Nothing is charged here.',
                  textAlign: TextAlign.center,
                  style: t.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          },
          const SizedBox(height: 20),
          Divider(height: 1, color: p.line),
          const SizedBox(height: 14),
          Text(
            'Google Play shows the price before you confirm, and handles billing and cancellation.',
            style: t.fine.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  final VoidCallback onTap;
  const _PlayBadge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Semantics(
      link: true,
      label: 'Get it on Google Play',
      excludeSemantics: true,
      child: Material(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GET IT ON', style: t.pill.copyWith(fontSize: 9, color: Colors.white70)),
                      Text('Google Play', style: t.titleM.copyWith(fontSize: 15.5, color: Colors.white, height: 1.05)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// D3: the button becomes its own progress state, with a three-part status
/// line saying where the check is.
class _Checking extends StatelessWidget {
  final int step;
  const _Checking({required this.step});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final status = t.mono.copyWith(fontSize: 11);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          label: 'Checking access',
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: p.accentWash,
              border: Border.all(color: p.accentLine),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: p.accentSolid),
                ),
                const SizedBox(width: 12),
                Text('Checking access…', style: t.button.copyWith(fontSize: 15.5, color: p.accent)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('✓ Signed in', style: status.copyWith(color: p.ok)),
              Text(
                step >= 2 ? '✓ Asked Google Play' : '● Asking Google Play',
                style: status.copyWith(color: step >= 2 ? p.ok : p.accent),
              ),
              Text(
                step >= 2 ? '● Unlocking' : '○ Unlocking',
                style: status.copyWith(color: step >= 2 ? p.accent : p.faint),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// D5: names the account that was checked, with the two ways out.
class _Problem extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onRetry;
  final VoidCallback? onSwitch;
  const _Problem({required this.title, required this.body, required this.onRetry, this.onSwitch});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: p.warnWash,
          border: Border.all(color: p.warnLine),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, size: 18, color: p.warn),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.titleS.copyWith(color: p.warn)),
                      const SizedBox(height: 4),
                      Text(body, style: t.bodyS.copyWith(height: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                EcButton(
                  label: 'Try again',
                  variant: EcButtonVariant.ink,
                  size: EcButtonSize.medium,
                  expand: false,
                  onPressed: onRetry,
                ),
                if (onSwitch != null)
                  EcButton.secondary(
                    label: 'Switch account',
                    size: EcButtonSize.medium,
                    expand: false,
                    onPressed: onSwitch,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// D6: success replaces the card in place — what just unlocked, and one
/// way forward to the projects.
class _UnlockedCard extends ConsumerWidget {
  final AppUser? user;
  const _UnlockedCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    Widget gained(String text) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(Icons.check_rounded, size: 16, color: p.ok),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: t.bodyL.copyWith(fontSize: 14))),
        ],
      ),
    );
    return Semantics(
      liveRegion: true,
      child: _Card(
        padding: const EdgeInsets.fromLTRB(36, 40, 36, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: p.okWash, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, color: p.ok, size: 28),
              ),
            ),
            const SizedBox(height: 22),
            Text('ACCESS CONFIRMED', style: t.eyebrow.copyWith(fontSize: 10.5, color: p.ok)),
            const SizedBox(height: 8),
            Text('Pro is active.', style: t.displayL.copyWith(fontSize: 46)),
            const SizedBox(height: 8),
            Text(
              '${user?.email ?? 'Your account'} · via Google Play. The desk editor is unlocked and your projects are ready.',
              style: t.body.copyWith(fontSize: 14.5),
            ),
            const SizedBox(height: 12),
            gained('Editing, new projects and paste'),
            gained('Every export format, up to 4K'),
            gained('No ads, on every device'),
            const SizedBox(height: 22),
            EcButton(
              label: 'Open my projects  →',
              onPressed: () {
                WebAccessScreen.leave(context, ref);
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Manage or cancel the subscription in Google Play.',
              textAlign: TextAlign.center,
              style: t.fine.copyWith(fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}
