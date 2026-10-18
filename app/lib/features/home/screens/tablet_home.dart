import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../library/screens/tablet_library.dart';
import '../../settings/screens/tablet_settings.dart';
import '../tablet_layout.dart';
import '../widgets/app_side_nav.dart';
import '../widgets/tablet_tab_bar.dart';

/// The tablet's home (§2): Projects and Settings as two tabs — the side
/// rail in landscape (T1.1, T7.1), the bottom tab bar in portrait (P1.1,
/// P7.1). Settings is a tab, not a pushed screen, so it has no back button
/// at its root and the rail or tab bar stays.
///
/// Both tabs stay mounted, and each keeps one [GlobalKey] across the two
/// orientations, so rotating keeps the tab, its scroll position and the
/// Settings section. The editor is pushed over this and shows neither.
class TabletHome extends ConsumerStatefulWidget {
  const TabletHome({super.key});

  @override
  ConsumerState<TabletHome> createState() => _TabletHomeState();
}

class _TabletHomeState extends ConsumerState<TabletHome> {
  final _projects = GlobalKey();
  final _settings = GlobalKey();
  TabletLayout? _reported;
  late final ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
  }

  @override
  void dispose() {
    // Signed out, or no longer a tablet: nothing is parked any more. A
    // microtask later, since providers can't change while widgets dispose.
    final container = _container;
    Future.microtask(() {
      try {
        clearParked(container, resumed: false);
      } on StateError {
        // The whole app is gone (a test's teardown): nothing to clear.
      }
    });
    super.dispose();
  }

  void _select(HomeDestination tab) => selectHomeTab(ProviderScope.containerOf(context, listen: false), tab);

  @override
  Widget build(BuildContext context) {
    final layout = context.tabletLayout ?? TabletLayout.landscape;
    if (_reported != layout) {
      _reported = layout;
      ref.read(analyticsProvider).logEvent('tablet_layout_shown', {'orientation': layout.name});
    }
    final tab = ref.watch(homeTabProvider);
    final body = IndexedStack(
      index: tab.index,
      sizing: StackFit.expand,
      children: [
        TabletLibrary(key: _projects),
        TabletSettings(key: _settings),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: EcGround(
        child: switch (layout) {
          TabletLayout.landscape => SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSideNav(selected: tab, onSelect: _select),
                Expanded(child: body),
              ],
            ),
          ),
          TabletLayout.portrait => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: SafeArea(bottom: false, child: body)),
              TabletTabBar(selected: tab, onSelect: _select),
            ],
          ),
        },
      ),
    );
  }
}
