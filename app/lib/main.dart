import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'features/library/screens/library_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolved before the first frame so no screen has to render a loading
  // state just to find out where its data lives.
  final repository = await createProjectRepository();

  runApp(
    ProviderScope(
      overrides: [projectRepositoryProvider.overrideWithValue(repository)],
      child: const EndcrawlApp(),
    ),
  );
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
        home: const LibraryScreen(),
      ),
    );
  }
}
