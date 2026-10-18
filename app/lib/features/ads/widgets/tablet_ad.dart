import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_dashed_border.dart';
import '../data/ad_service.dart';

/// The tablet's ad surfaces (§5): the library's foot strip and the
/// Settings list card. Always labelled "Ad", always with "Remove ads",
/// on a quieter surface than a project card and never on the primary
/// gradient.
///
/// The card ([TabletAdCard]) is drawn here; the ad itself — the network's
/// native view, or [TabletAdPlaceholder] — fills its inside. "Remove ads"
/// sits over the creative in a space the creative leaves for it.
abstract final class TabletAdMetrics {
  /// The whole card, so a slot can reserve it before the ad loads: the
  /// still, the padding and the hairline border.
  /// The compact card's "Ad" row grows with the text size ([text]).
  static double height(AdLayout layout, {bool portrait = false, TextScaler text = TextScaler.noScaling}) =>
      switch (layout) {
        AdLayout.strip => portrait ? 126 : 134,
        AdLayout.compact => 104 + (text.scale(16) - 16).clamp(0, 40),
        AdLayout.row => 76,
      };

  static EdgeInsets padding(AdLayout layout, {bool portrait = false}) => switch (layout) {
    AdLayout.strip => EdgeInsets.fromLTRB(14, 14, portrait ? 16 : 18, 14),
    _ => const EdgeInsets.all(10),
  };

  static double radius(AdLayout layout) => layout == AdLayout.compact ? 16 : 22;

  /// The 16:9 still in a strip; the compact card's is 72 × 56.
  static Size image(AdLayout layout, {bool portrait = false}) => switch (layout) {
    AdLayout.strip => portrait ? const Size(168, 96) : const Size(184, 104),
    _ => const Size(72, 56),
  };

  static double imageGap(AdLayout layout, {bool portrait = false}) =>
      layout == AdLayout.strip ? (portrait ? 16 : 18) : 10;
}

/// "AD": mono 9.5, upper case, on the tint fill with a strong border.
class AdTag extends StatelessWidget {
  const AdTag({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: p.tint,
        border: Border.all(color: p.line2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'AD',
        style: context.type.mono.copyWith(
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
          letterSpacing: 9.5 * .12,
          color: p.ink2,
          height: 1.3,
        ),
      ),
    );
  }
}

/// The card around a tablet ad, and its "Remove ads" link (→ the Pro
/// screen). [onRemoveAds] is null where the build sells nothing.
class TabletAdCard extends StatelessWidget {
  final AdLayout layout;
  final bool portrait;
  final Widget creative;
  final VoidCallback? onRemoveAds;

  /// The card's height; [TabletAdMetrics.height] by default.
  final double? height;

  const TabletAdCard({
    super.key,
    required this.layout,
    this.portrait = false,
    required this.creative,
    this.onRemoveAds,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final link = onRemoveAds == null
        ? const SizedBox.shrink()
        : RemoveAdsLink(onTap: onRemoveAds!, compact: layout == AdLayout.compact);
    return Semantics(
      container: true,
      label: 'Advertisement',
      child: Container(
        height: height ?? TabletAdMetrics.height(layout, portrait: portrait),
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: .55),
          border: Border.all(color: p.line),
          borderRadius: BorderRadius.circular(TabletAdMetrics.radius(layout)),
        ),
        padding: TabletAdMetrics.padding(layout, portrait: portrait),
        child: Stack(
          fit: StackFit.expand,
          children: [
            creative,
            // Laid out like the creative's own rows, so the link lands in
            // the space it leaves: under the action, under the headline in
            // portrait, or opposite the tag on the compact card.
            switch (layout) {
              AdLayout.compact => Align(
                alignment: Alignment.topCenter,
                child: Row(
                  children: [
                    const Visibility.maintain(visible: false, child: AdTag()),
                    const Spacer(),
                    link,
                  ],
                ),
              ),
              AdLayout.strip when portrait => Row(
                children: [
                  SizedBox(
                    width:
                        TabletAdMetrics.image(layout, portrait: true).width +
                        TabletAdMetrics.imageGap(layout, portrait: true),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Visibility.maintain(visible: false, child: AdTag()),
                          const SizedBox(height: 6),
                          const Visibility.maintain(visible: false, child: AdHeadline('', fontSize: 15.5)),
                          const SizedBox(height: 6),
                          link,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              _ => Align(
                alignment: Alignment.centerRight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(height: AdAction.height + 8),
                    link,
                  ],
                ),
              ),
            },
          ],
        ),
      ),
    );
  }
}

class RemoveAdsLink extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;
  const RemoveAdsLink({super.key, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Text(
          'Remove ads',
          style: context.type.bodyS.copyWith(
            fontSize: compact ? 11.5 : 12,
            fontWeight: FontWeight.w600,
            color: p.accent,
            height: 1.25,
          ),
        ),
      ),
    );
  }
}

/// The ad's headline line, 16 / 600 (15.5 in portrait, 13 on the card).
class AdHeadline extends StatelessWidget {
  final String text;
  final double fontSize;
  final int maxLines;
  const AdHeadline(this.text, {super.key, this.fontSize = 16, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: context.type.titleM.copyWith(fontSize: fontSize, fontWeight: FontWeight.w600, height: 1.25),
  );
}

/// The ad's action, a 40-tall white pill.
class AdAction extends StatelessWidget {
  static const height = 40.0;
  final String label;
  final double padding;
  const AdAction(this.label, {super.key, this.padding = 18});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: padding),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.type.bodyS.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: p.ink),
      ),
    );
  }
}

/// House copy in the tablet ad shapes — what a slot shows where no ad
/// network is wired in (tests, previews): the dashed still, the "Ad" tag,
/// advertiser, headline, body and action.
class TabletAdPlaceholder extends StatelessWidget {
  final AdPlacement placement;
  final AdLayout layout;
  final bool portrait;

  const TabletAdPlaceholder({super.key, required this.placement, required this.layout, this.portrait = false});

  String get _advertiser => placement.houseHeadline.split(' — ').first;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final size = TabletAdMetrics.image(layout, portrait: portrait);
    final image = EcDashedBorder(
      radius: layout == AdLayout.compact ? 10 : 14,
      child: Container(
        width: size.width,
        height: size.height,
        color: p.tint,
        alignment: Alignment.center,
        child: Text(
          layout == AdLayout.compact ? '[Image]' : '[Ad image\n16:9 · static]',
          textAlign: TextAlign.center,
          style: t.mono.copyWith(fontSize: layout == AdLayout.compact ? 9 : 10, color: p.muted, height: 1.4),
        ),
      ),
    );
    final tagRow = Row(
      children: [
        const AdTag(),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _advertiser,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.bodyS.copyWith(fontSize: 12, color: p.muted),
          ),
        ),
      ],
    );
    final headline = placement.houseHeadline.split(' — ').last;

    switch (layout) {
      case AdLayout.compact:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(children: [AdTag()]),
            const SizedBox(height: 8),
            Row(
              children: [
                image,
                SizedBox(width: TabletAdMetrics.imageGap(layout)),
                Expanded(child: AdHeadline(headline, fontSize: 13, maxLines: 2)),
              ],
            ),
          ],
        );
      case _ when portrait:
        return Row(
          children: [
            image,
            SizedBox(width: TabletAdMetrics.imageGap(layout, portrait: true)),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tagRow,
                  const SizedBox(height: 6),
                  AdHeadline(headline, fontSize: 15.5),
                  const SizedBox(height: 6),
                  // "Remove ads" goes here (TabletAdCard).
                  const Visibility.maintain(visible: false, child: RemoveAdsLink(onTap: _noop)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const AdAction('Learn more', padding: 16),
          ],
        );
      case _:
        return Row(
          children: [
            image,
            SizedBox(width: TabletAdMetrics.imageGap(layout)),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tagRow,
                  const SizedBox(height: 6),
                  AdHeadline(headline),
                  const SizedBox(height: 6),
                  Text(
                    placement.houseBody,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyS.copyWith(fontSize: 12.5, color: p.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AdAction('Learn more'),
                SizedBox(height: 8),
                // "Remove ads" goes here (TabletAdCard).
                Visibility.maintain(visible: false, child: RemoveAdsLink(onTap: _noop)),
              ],
            ),
          ],
        );
    }
  }
}

void _noop() {}
