import 'package:flutter/material.dart';
import '../../plan/screens/pro_sheet.dart';

/// Compatibility entry for old upgrade callers. Web now uses the shared paywall.
class WebAccessScreen extends StatelessWidget {
  const WebAccessScreen({super.key});
  static Future<void> open(BuildContext context) => ProSheet.show(context);
  @override
  Widget build(BuildContext context) => const ProSheet();
}
