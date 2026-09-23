import 'package:flutter/material.dart';

import '../theme/ec_type.dart';
import '../theme/theme_context.dart';
import '../theme/tokens.dart';
import 'ec_scaffold.dart';
import 'ec_surfaces.dart';

/// Shows [child] as a bottom sheet with the app's scrim and transparent
/// Material background, so the sheet draws its own [EcSheet] chrome.
Future<T?> showEcSheet<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: Colors.transparent,
    barrierColor: context.palette.scrim,
    builder: builder,
  );
}

/// Every bottom sheet's chrome: sheet colour, 28 px top radius, grab handle,
/// a serif title with a round ✕, and a scrollable body.
///
/// [header] replaces the title row when a sheet opens on something richer —
/// the project sheet (1.3) names the project with a thumbnail. [eyebrow]
/// adds the small mono context line above the title ("NEW PROJECT · SLOT 3
/// OF 3", "INSERT AFTER · CAST").
class EcSheet extends StatelessWidget {
  final String? title;
  final String? eyebrow;
  final Widget? header;
  final Widget child;
  final Widget? footer;
  final double maxHeightFraction;
  final bool showClose;
  final EdgeInsets padding;

  const EcSheet({
    super.key,
    this.title,
    this.eyebrow,
    this.header,
    required this.child,
    this.footer,
    this.maxHeightFraction = 0.9,
    this.showClose = true,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 24),
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final maxHeight = MediaQuery.sizeOf(context).height * maxHeightFraction;

    final titleRow = header ??
        (title == null
            ? const SizedBox(height: 12)
            : Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (eyebrow != null) ...[EcEyebrow(eyebrow!), const SizedBox(height: 6)],
                          Text(title!, style: t.displayM),
                        ],
                      ),
                    ),
                    if (showClose)
                      EcCircleButton.tint(
                        icon: Icons.close_rounded,
                        size: 34,
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                  ],
                ),
              ));

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: p.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(EcRadius.sheet)),
        boxShadow: p.sheetShadow,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(color: p.line2, borderRadius: BorderRadius.circular(EcRadius.pill)),
                ),
              ),
              titleRow,
              Flexible(child: SingleChildScrollView(padding: padding, child: child)),
              ?footer,
            ],
          ),
        ),
      ),
    );
  }
}

/// One row in an action sheet (1.3): round glyph, label, optional detail.
class EcSheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? detail;
  final bool destructive;
  final VoidCallback? onTap;

  const EcSheetAction({
    super.key,
    required this.icon,
    required this.label,
    this.detail,
    this.destructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(EcRadius.inner),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              EcIconBadge(icon, destructive: destructive),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: t.row.copyWith(fontSize: 15, color: destructive ? p.warn : p.ink)),
                    if (detail != null) ...[const SizedBox(height: 2), Text(detail!, style: t.caption)],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A mono, upper-cased group label — "CODEC", "TEMPLATES", "OPENERS 4".
class EcSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const EcSectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 6, bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(caps(text), style: context.type.section)),
          ?trailing,
        ],
      ),
    );
  }
}
