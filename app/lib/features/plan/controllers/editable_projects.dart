import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../domain/models/entitlement.dart';
import '../../library/controllers/library_controller.dart';

/// The projects the free plan can't edit right now.
///
/// When a trial or Pro ends, nothing is deleted: every project stays, but
/// the free plan edits only as many as it holds — the most recently updated
/// ones. The rest open read-only: they still play and still render. Picking
/// a different one to edit just touches it (see `keepEditable`), which
/// makes it the most recent; no choice is stored anywhere, so every device
/// agrees.
///
/// This holds because nothing touches a read-only project: edits are
/// refused, and opening it or recording a render saves without changing
/// `updatedAt`. Empty on Pro and whenever the projects fit the plan.
final readOnlyProjectIdsProvider = Provider<Set<String>>((ref) {
  final limit = (ref.watch(entitlementProvider).value ?? const Entitlement.free()).projectLimit;
  final summaries = ref.watch(projectSummariesProvider).value;
  if (limit == null || summaries == null || summaries.length <= limit) return const {};
  final newestFirst = [...summaries]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return {for (final s in newestFirst.skip(limit)) s.id};
});
