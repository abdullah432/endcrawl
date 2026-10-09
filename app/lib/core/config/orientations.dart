import 'dart:ui' show FlutterView;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The app outside the editor.
const kPortraitOnly = [DeviceOrientation.portraitUp];

/// The editor: rotating to landscape opens the review monitor (3.4).
const kEditorOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// One owner for orientation requests; tablets always defer to the OS.
class EcOrientationPolicy extends StatefulWidget {
  final Widget child;
  const EcOrientationPolicy({super.key, required this.child});
  static final _mode = ValueNotifier<(bool, bool)>((false, false));
  static void editor(bool enabled) => _mode.value = (enabled, false);
  static void exitPhoneReview() => _mode.value = (true, true);

  @override
  State<EcOrientationPolicy> createState() => _EcOrientationPolicyState();
}

class _EcOrientationPolicyState extends State<EcOrientationPolicy>
    with WidgetsBindingObserver {
  List<DeviceOrientation>? _last;
  FlutterView? _view;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    EcOrientationPolicy._mode.addListener(_apply);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _view = View.of(context);
    _apply();
  }

  @override
  void didChangeMetrics() => _apply();
  void _apply() {
    if (kIsWeb || !mounted) return;
    final display = _view?.display;
    if (display == null) return;
    final phone = display.size.shortestSide / display.devicePixelRatio < 600;
    final (editor, pinned) = EcOrientationPolicy._mode.value;
    final next = !phone
        ? <DeviceOrientation>[]
        : editor && !pinned
        ? kEditorOrientations
        : kPortraitOnly;
    if (!listEquals(_last, next)) {
      _last = next;
      SystemChrome.setPreferredOrientations(next);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    EcOrientationPolicy._mode.removeListener(_apply);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
