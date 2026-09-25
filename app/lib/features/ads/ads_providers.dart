import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/ad_service.dart';

final adServiceProvider = Provider<AdService>((ref) => const PlaceholderAdService());
