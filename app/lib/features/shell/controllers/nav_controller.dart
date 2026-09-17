import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppTab { prototype, appendix }

enum DeviceOrientation { portrait, landscape }

enum EditorScreenStep { templates, format, editor }

class NavState {
  final AppTab tab;
  final DeviceOrientation device;
  final EditorScreenStep screen;

  const NavState({
    this.tab = AppTab.prototype,
    this.device = DeviceOrientation.portrait,
    this.screen = EditorScreenStep.templates,
  });

  NavState copyWith({AppTab? tab, DeviceOrientation? device, EditorScreenStep? screen}) {
    return NavState(
      tab: tab ?? this.tab,
      device: device ?? this.device,
      screen: screen ?? this.screen,
    );
  }
}

/// Top-level navigation state: which tab (prototype vs. tokens/appendix),
/// which simulated device orientation, and which step of the
/// templates -> format -> editor flow is showing. Mirrors the prototype's
/// `tab` / `device` / `screen` state fields.
class NavController extends Notifier<NavState> {
  @override
  NavState build() => const NavState();

  void goPrototype() => state = state.copyWith(tab: AppTab.prototype);
  void goAppendix() => state = state.copyWith(tab: AppTab.appendix);

  void devicePortrait() => state = state.copyWith(device: DeviceOrientation.portrait);
  void deviceLandscape() =>
      state = state.copyWith(device: DeviceOrientation.landscape, screen: EditorScreenStep.editor);

  void goTemplates() => state = state.copyWith(screen: EditorScreenStep.templates);
  void goFormat() => state = state.copyWith(screen: EditorScreenStep.format);
  void goEditor() => state = state.copyWith(screen: EditorScreenStep.editor);
}

final navControllerProvider = NotifierProvider<NavController, NavState>(NavController.new);
