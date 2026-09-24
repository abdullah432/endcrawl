import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../theme/tokens.dart';

/// The dark toast with an optional action — "Duplicated · slots now full
/// **Undo**", "Removed “Filming locations” · runtime 2:38 **Undo**".
///
/// Drawn in the navigator's overlay rather than as a [SnackBar] — Material
/// keeps a snack bar with an action up until it's dismissed by hand, and
/// this always leaves on its own. Sheets opened after it stack above it, as
/// they would a snack bar; [showEcToastOn] with the root overlay outlives
/// the whole signed-in tree ("Account deleted"). It rises in
/// with a small spring, counts down along its bottom edge, and drops away
/// after [duration] (ten seconds for an undo, four otherwise), when its
/// action is tapped, or when swiped down. A new toast replaces the current
/// one.
EcToastHandle showEcToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
}) {
  return showEcToastOn(
    Overlay.of(context),
    message,
    actionLabel: actionLabel,
    onAction: onAction,
    duration: duration,
  );
}

/// [showEcToast] on an overlay captured earlier — for a toast raised after
/// the widget that asked for it has gone (a removed row, a deleted account).
EcToastHandle showEcToastOn(
  OverlayState overlay,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
}) {
  return EcToastHandle._show(
    overlay,
    message: message,
    actionLabel: actionLabel,
    onAction: onAction,
    duration: duration ?? (actionLabel == null ? const Duration(seconds: 4) : const Duration(seconds: 10)),
  );
}

/// Clears the toast when a sheet or dialog opens. A route pushed later is
/// laid out beneath the toast's overlay entry, so a lingering toast would
/// sit over the sheet's own buttons; a snack bar yields the same way.
class EcToastObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) EcToastHandle._current?.dismiss();
  }
}

/// The toast on screen, to dismiss early.
class EcToastHandle {
  static EcToastHandle? _current;

  final OverlayEntry _entry;
  final GlobalKey<_EcToastState> _key;
  bool _removed = false;

  EcToastHandle._(this._entry, this._key);

  factory EcToastHandle._show(
    OverlayState overlay, {
    required String message,
    required String? actionLabel,
    required VoidCallback? onAction,
    required Duration duration,
  }) {
    _current?.dismiss();
    final key = GlobalKey<_EcToastState>();
    late final EcToastHandle handle;
    final entry = OverlayEntry(
      builder: (_) => _EcToast(
        key: key,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        onGone: () => handle._remove(),
      ),
    );
    handle = EcToastHandle._(entry, key);
    _current = handle;
    overlay.insert(entry);
    return handle;
  }

  /// Animates the toast away.
  void dismiss() {
    final state = _key.currentState;
    if (state != null) {
      state.leave();
    } else {
      _remove();
    }
  }

  void _remove() {
    if (_removed) return;
    _removed = true;
    if (identical(_current, this)) _current = null;
    _entry.remove();
  }
}

class _EcToast extends StatefulWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onGone;

  const _EcToast({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.duration,
    required this.onGone,
  });

  @override
  State<_EcToast> createState() => _EcToastState();
}

class _EcToastState extends State<_EcToast> with TickerProviderStateMixin {
  late final _presence = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 260),
  );
  late final _countdown = AnimationController(vsync: this, duration: widget.duration);
  Timer? _timer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _presence.forward();
    // A Timer rather than the countdown animation decides when to leave, so
    // the toast goes on time even where animations are switched off.
    _timer = Timer(widget.duration, leave);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The draining bar is decoration; with reduce-motion on it stays full.
    if (MediaQuery.disableAnimationsOf(context)) {
      _countdown.stop();
    } else if (!_countdown.isAnimating && !_leaving) {
      _countdown.forward();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _presence.dispose();
    _countdown.dispose();
    super.dispose();
  }

  Future<void> leave() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    _timer?.cancel();
    _countdown.stop();
    await _presence.reverse();
    widget.onGone();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final enter = CurvedAnimation(parent: _presence, curve: EcMotion.easeSpring, reverseCurve: Curves.easeInCubic);

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16 + MediaQuery.paddingOf(context).bottom,
      child: SafeArea(
        top: false,
        bottom: false,
        child: AnimatedBuilder(
          animation: enter,
          builder: (context, child) {
            final v = enter.value;
            return FractionalTranslation(
              translation: Offset(0, (1 - v) * 1.1),
              child: Transform.scale(
                scale: 0.94 + 0.06 * v,
                child: Opacity(opacity: _presence.value.clamp(0.0, 1.0), child: child),
              ),
            );
          },
          child: Dismissible(
            key: const ValueKey('ec-toast'),
            direction: DismissDirection.down,
            onDismissed: (_) {
              _leaving = true;
              _timer?.cancel();
              widget.onGone();
            },
            child: Semantics(
              liveRegion: true,
              container: true,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: p.inkSurface,
                    borderRadius: BorderRadius.circular(EcRadius.card),
                    boxShadow: p.toastShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(18, 14, widget.actionLabel == null ? 18 : 6, 14),
                        child: Row(
                          children: [
                            Expanded(child: Text(widget.message, style: t.body.copyWith(fontSize: 13.5, color: p.onInk))),
                            if (widget.actionLabel != null)
                              TextButton(
                                onPressed: () {
                                  widget.onAction?.call();
                                  leave();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: p.accentOnBlack,
                                  textStyle: t.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                child: Text(widget.actionLabel!),
                              ),
                          ],
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _countdown,
                        builder: (context, _) => Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: 1 - _countdown.value,
                            child: Container(height: 2, decoration: BoxDecoration(gradient: p.primary)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
