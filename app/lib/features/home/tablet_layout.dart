import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap.dart';
import '../../core/layout/layout_class.dart';
import '../access/controllers/web_access.dart';
import '../editor/controllers/editor_ui_controller.dart';
import '../library/controllers/library_controller.dart';
import '../monitor/controllers/playback_controller.dart';
import '../project/controllers/project_controller.dart';
import 'widgets/app_side_nav.dart';

/// How a native tablet holds the app (tablet handoff A): the landscape
/// T-screens, with the side rail, or the portrait P-screens, with the
/// bottom tab bar.
enum TabletLayout { landscape, portrait }

extension TabletLayoutContext on BuildContext {
  /// The tablet layout, or null for the phone, the web build and the
  /// native desktop app — none of which this layout changes.
  ///
  /// A tablet is a window of the iOS or Android app whose shortest side is
  /// at least 600 (Android's `sw600dp`), however wide: a 13" iPad in
  /// landscape (1366 or 1376 wide) is past the desktop breakpoint but still
  /// gets the T-screens, not the browser's D-screens. Rotating switches
  /// between the two orientations over the same providers, so the open
  /// project, the selection and the Settings section survive it.
  TabletLayout? get tabletLayout {
    if (layoutClass == LayoutClass.compact) return null;
    final size = MediaQuery.sizeOf(this);
    if (size.shortestSide < 600) return null;
    if (ProviderScope.containerOf(this, listen: false).read(verifiedWorkspaceProvider)) return null;
    return size.height > size.width ? TabletLayout.portrait : TabletLayout.landscape;
  }

  bool get isTablet => tabletLayout != null;

  /// The layout class the screens draw: a native tablet is always medium
  /// (the T- and P-screens), whatever its width.
  LayoutClass get screenClass => isTablet ? LayoutClass.medium : layoutClass;

  /// The desktop browser's (or the desktop app's) D-screens.
  bool get isDesktopLayout => screenClass == LayoutClass.expanded;
}

/// The Settings sections of the tablet's Settings tab (T7.1, P7.1).
enum SettingsSection {
  plan('plan', 'Plan'),
  defaults('defaults', 'Defaults'),
  app('app', 'App'),
  support('support', 'Support'),

  /// T9.1: the COOKOO tile and the team's other apps — after Support,
  /// before the privacy and legal sections, never first.
  makers('makers', 'From the makers'),
  privacy('privacy', 'Privacy & data'),
  legal('legal', 'Legal');

  final String id;
  final String title;
  const SettingsSection(this.id, this.title);
}

/// Which tab the tablet shell shows.
class HomeTab extends Notifier<HomeDestination> {
  @override
  HomeDestination build() => HomeDestination.projects;

  void select(HomeDestination tab) => state = tab;
}

final homeTabProvider = NotifierProvider<HomeTab, HomeDestination>(HomeTab.new);

/// The Settings section last opened in this session (§6: "remember the
/// last section per session").
class SettingsSectionChoice extends Notifier<SettingsSection> {
  @override
  SettingsSection build() => SettingsSection.plan;

  void select(SettingsSection section) => state = section;
}

final settingsSectionProvider = NotifierProvider<SettingsSectionChoice, SettingsSection>(SettingsSectionChoice.new);

/// The project the editor was left for Settings with (T7.2: "the avatar
/// button leaves the edit and lands here"). It stays open in memory —
/// document, undo history, selection and playhead — so opening the same
/// card again resumes where the edit was left.
class ParkedProject extends Notifier<String?> {
  @override
  String? build() => null;

  void park(String? id) => state = id;
}

final parkedProjectProvider = NotifierProvider<ParkedProject, String?>(ParkedProject.new);

/// Keeps the parked editor's selection alive while it is off screen; the
/// editor's own listener takes over when it is back.
ProviderSubscription<Object?>? _parkedUi;

/// T3.1's avatar + gear button: leaves the edit for the Settings tab on
/// Plan (§6), keeping the project open in memory so Projects → the same
/// card resumes it.
void leaveEditorForSettings(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  // The playhead stays where it was, not running on behind Settings.
  container.read(playbackControllerProvider.notifier).pause();
  _parkedUi?.close();
  _parkedUi = container.listen(editorUiControllerProvider, (_, _) {});
  container.read(parkedProjectProvider.notifier).park(container.read(projectControllerProvider).project.id);
  container.read(settingsSectionProvider.notifier).select(SettingsSection.plan);
  selectHomeTab(container, HomeDestination.settings, from: 'editor');
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// Whether opening [id] resumes the edit [leaveEditorForSettings] parked,
/// rather than loading the stored document afresh. Not if the stored
/// document has changed since — renamed from the library, or edited on
/// another device — so that change is never written over.
bool resumesParked(ProviderContainer container, String id) {
  if (container.read(parkedProjectProvider) != id) return false;
  final open = container.read(projectControllerProvider).project;
  if (open.id != id) return false;
  final stored = container.read(projectSummariesProvider).value?.where((s) => s.id == id).firstOrNull;
  return stored != null && stored.updatedAt.isAtSameMomentAs(open.updatedAt);
}

/// Called as the editor comes back on screen: the parked state is no
/// longer anyone's to keep. [resumed] is false when another project is
/// opened instead, whose editor must not inherit the parked selection.
void clearParked(ProviderContainer container, {required bool resumed}) {
  final keep = _parkedUi;
  if (keep == null) return;
  _parkedUi = null;
  container.read(parkedProjectProvider.notifier).park(null);
  if (resumed) {
    // A frame later, so the editor's own listener is already in place.
    WidgetsBinding.instance.addPostFrameCallback((_) => keep.close());
  } else {
    keep.close();
    container.invalidate(editorUiControllerProvider);
  }
}

/// Switches the shell's tab, and says so (`nav_tab_selected`).
void selectHomeTab(ProviderContainer container, HomeDestination tab, {String? from}) {
  final current = container.read(homeTabProvider);
  container.read(homeTabProvider.notifier).select(tab);
  container.read(analyticsProvider).logEvent('nav_tab_selected', {'tab': tab.name, 'from': from ?? current.name});
}
