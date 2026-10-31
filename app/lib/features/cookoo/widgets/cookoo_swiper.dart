import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/config/app_links.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../home/tablet_layout.dart';
import '../controllers/cookoo_promo_controller.dart';
import '../models/cookoo_content.dart';
import '../screens/cookoo_contact_screen.dart';
import 'cookoo_promo_card.dart';
import 'cookoo_style.dart';

/// The COOKOO block in Settings, under Legal & privacy and above Sign out:
/// the swiper, or — once hidden from here — a one-line Undo row for the
/// rest of the session. Lays itself out edge to edge, so the next slide can
/// peek in from the right.
class CookooPromoBlock extends ConsumerWidget {
  /// "1 of 4" beside the label, and the leads tagged as the tablet's (T9.1).
  final bool counter;
  const CookooPromoBlock({super.key, this.counter = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cookooPromoProvider);
    return AnimatedSize(
      duration: EcMotion.base,
      curve: EcMotion.easeOut,
      alignment: Alignment.topCenter,
      child: switch (state) {
        CookooPromoState(hidden: false) => CookooSwiper(counter: counter),
        CookooPromoState(undoable: true) => const Padding(
          padding: EdgeInsets.fromLTRB(16, 22, 16, 0),
          child: _HiddenRow(),
        ),
        _ => const SizedBox(width: double.infinity),
      },
    );
  }
}

class _HiddenRow extends ConsumerWidget {
  const _HiddenRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(EcRadius.field)),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Hidden. You can turn it back on below.',
                style: context.cookooUi(13, color: p.muted, height: 1.35),
              ),
            ),
          ),
          Semantics(
            button: true,
            child: InkWell(
              onTap: ref.read(cookooPromoProvider.notifier).undo,
              borderRadius: BorderRadius.circular(EcRadius.field),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    widthFactor: 1,
                    child: Text('Undo', style: context.cookooUi(14, weight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label row, the four slides and their dots. No auto-play; always opens
/// on the first slide.
class CookooSwiper extends ConsumerStatefulWidget {
  /// The tablet's Settings section (T9.1): "1 of 4" opposite the label,
  /// the first tile flush with the section, and leads tagged
  /// `lastreel-tablet` with the orientation.
  final bool counter;
  const CookooSwiper({super.key, this.counter = false});

  @override
  ConsumerState<CookooSwiper> createState() => _CookooSwiperState();
}

class _CookooSwiperState extends ConsumerState<CookooSwiper> {
  static const _gap = 10.0;
  double get _leadingInset => widget.counter ? 0 : 16.0 - _gap / 2;

  PageController? _pages;
  double _slideWidth = CookooPromoCard.width;
  int _index = 0;

  /// Settings' own scroll view. The card sits near the foot of Settings, so
  /// it only counts as seen once it is scrolled at least halfway into view.
  ScrollPosition? _scroll;
  bool _seen = false;

  CookooPromoController get _promo => ref.read(cookooPromoProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSeen());
  }

  void _checkSeen() {
    if (_seen || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final half = box.size.height / 2;
    if (top + half < MediaQuery.sizeOf(context).height && top + half > 0) {
      _seen = true;
      _scroll?.removeListener(_checkSeen);
      _promo.viewed(_index, surface: _surface);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scroll = Scrollable.maybeOf(context)?.position;
    if (scroll != _scroll) {
      _scroll?.removeListener(_checkSeen);
      _scroll = scroll;
      if (!_seen) _scroll?.addListener(_checkSeen);
    }
    _sizeFor(MediaQuery.sizeOf(context).width);
  }

  /// Sizes the pages for the width the swiper actually has — the screen on
  /// a phone, a pane in Settings on a tablet or desktop.
  /// The pager's own width, once laid out — what the counter reads.
  double? _width;

  void _sizeFor(double width) {
    // 358 wide with 16 at each side; narrow widths keep the 16 and shrink
    // the card. Each page carries half the 10 px gap on either side.
    _slideWidth = width < 380 ? width - 32 : CookooPromoCard.width;
    final fraction = ((_slideWidth + _gap) / (width - _leadingInset)).clamp(0.1, 1.0);
    if (_pages?.viewportFraction != fraction) {
      final old = _pages;
      _pages = PageController(viewportFraction: fraction, initialPage: _index);
      // Disposed after this frame: the PageView still holds it until it
      // rebuilds with the new one.
      if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  @override
  void dispose() {
    _scroll?.removeListener(_checkSeen);
    _pages?.dispose();
    super.dispose();
  }

  /// "1 of 4", or "1–2 of 4" while two tiles fit across (P7.1).
  String get _counter {
    final width = _width;
    final across = width != null && width - _leadingInset >= 2 * (_slideWidth + _gap) ? 2 : 1;
    final last = (_index + across).clamp(1, cookooSlides.length);
    final shown = last > _index + 1 ? '${_index + 1}–$last' : '${_index + 1}';
    return '$shown of ${cookooSlides.length}';
  }

  void _onPage(int index) {
    setState(() => _index = index);
    _promo
      ..swiped(index)
      ..viewed(index, surface: _surface);
  }

  /// Where the card is, for the promotion reports.
  String? get _surface => switch (context.tabletLayout) {
    null => null,
    final layout => 'tablet_${layout.name}',
  };

  void _tellUs(CookooSlide slide) {
    _promo.ctaTapped(slide.id, surface: _surface);
    final tablet = context.tabletLayout;
    CookooContactScreen.open(
      context,
      source: slide.id,
      need: slide.need,
      surface: tablet == null ? null : 'lastreel-tablet · ${tablet.name}',
    );
  }

  void _openCase(CookooSlide slide) {
    _promo.siteOpened(slide.id, surface: _surface);
    ref.read(externalLinksProvider).openUrl(AppLinks.cookooCase(slide.caseSlug!, content: slide.id));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The label keeps the 44-tall row the (hidden) Hide button gave it,
        // plus the gap above that separates it from the group before.
        Padding(
          padding: widget.counter ? EdgeInsets.zero : const EdgeInsets.fromLTRB(20, 22, 8, 0),
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'FROM THE MAKERS OF LASTREEL',
                    style: context.cookooMono(11, tracking: 2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.counter)
                  Text(_counter, style: context.cookooMono(11, tracking: 1)),
                // Hidden for now: the "Hide" button.
                //               Semantics(
                //                 button: true,
                //                 label: 'Hide the COOKOO card',
                //                 excludeSemantics: true,
                //                 child: InkWell(
                //                   onTap: () => _promo.hide(_index),
                //                   borderRadius: BorderRadius.circular(EcRadius.inner),
                //                   child: SizedBox(
                //                     height: 44,
                //                     child: Padding(
                //                       padding: const EdgeInsets.symmetric(horizontal: 12),
                //                       child: Center(
                //                         widthFactor: 1,
                //                         child: Text(
                //                           'Hide',
                //                           style: context.cookooUi(13, weight: FontWeight.w600, color: p.muted),
                //                         ),
                //                       ),
                //                     ),
                //                   ),
                //                 ),
                //               ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: CookooPromoCard.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _sizeFor(constraints.maxWidth);
              if (widget.counter && _width != constraints.maxWidth) {
                _width = constraints.maxWidth;
                // The counter sits above, already built for this frame.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() {});
                });
              }
              return Padding(
                // Keep the first card aligned with the Settings groups rather
                // than centering it in the available tablet or desktop width.
                padding: EdgeInsetsDirectional.only(start: _leadingInset),
                child: PageView.builder(
                  controller: _pages,
                  padEnds: false,
                  itemCount: cookooSlides.length,
                  onPageChanged: _onPage,
                  itemBuilder: (context, i) {
                    final slide = cookooSlides[i];
                    return Semantics(
                      container: true,
                      label: 'Slide ${i + 1} of ${cookooSlides.length}',
                      child: Padding(
                        // Flush with the section on a tablet: the gap all
                        // goes after the tile.
                        padding: widget.counter
                            ? const EdgeInsetsDirectional.only(end: _gap)
                            : const EdgeInsets.symmetric(horizontal: _gap / 2),
                        child: CookooPromoCard(
                          slide: slide,
                          onTellUs: () => _tellUs(slide),
                          onFooterTap: slide.caseSlug == null ? null : () => _openCase(slide),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < cookooSlides.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                AnimatedContainer(
                  duration: EcMotion.base,
                  curve: EcMotion.easeOut,
                  width: i == _index ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index ? p.ink : p.line2,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
