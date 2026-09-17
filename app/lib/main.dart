import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/templates/screens/templates_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: EndcrawlApp()));
}

class EndcrawlApp extends StatelessWidget {
  const EndcrawlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: MaterialApp(
        title: 'EndCrawl',
        debugShowCheckedModeBanner: false,
        theme: buildEndcrawlTheme(),
        home: const TemplatesScreen(),
      ),
    );
  }
}
