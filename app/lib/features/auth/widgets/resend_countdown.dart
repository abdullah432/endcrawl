import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_button.dart';

/// "Resend in 0:42", becoming a "Resend" link when the cooldown ends.
///
/// Ticks once a second only while a cooldown is running, so it costs
/// nothing the rest of the time.
class ResendCountdown extends StatefulWidget {
  final Duration Function() remaining;
  final VoidCallback? onResend;
  final String label;

  const ResendCountdown({super.key, required this.remaining, required this.onResend, this.label = 'Resend'});

  @override
  State<ResendCountdown> createState() => _ResendCountdownState();
}

class _ResendCountdownState extends State<ResendCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ResendCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.remaining() > Duration.zero) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (widget.remaining() <= Duration.zero) {
          _timer?.cancel();
          _timer = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.remaining();
    if (left <= Duration.zero) {
      return EcButton.text(label: widget.label, size: EcButtonSize.small, onPressed: widget.onResend);
    }
    return Text('${widget.label} in ${formatCountdown(left)}', style: context.type.mono);
  }
}

/// m:ss, rounding up so the label never shows 0:00 while still waiting.
String formatCountdown(Duration d) {
  final seconds = (d.inMilliseconds / 1000).ceil();
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
