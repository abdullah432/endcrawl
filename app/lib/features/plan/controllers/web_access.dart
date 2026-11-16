import 'package:flutter_riverpod/flutter_riverpod.dart';

final webAccessRequiredProvider = Provider<bool>(
  (ref) => false,
);
final webAccessAllowedProvider = Provider<bool>((ref) => true);
