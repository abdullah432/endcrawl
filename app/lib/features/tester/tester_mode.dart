import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../bootstrap.dart';

/// "Tester · LastReel Pro": a switch in Settings that makes the app behave
/// as Pro on this device — no ads, no trial offers, every format — so the
/// Pro experience can be checked without buying it.
///
/// It grants Pro to whoever can flip it, so it only appears for accounts
/// listed in Firestore at `testers/{uid}` (with `enabled: true`). Only an
/// admin can write that collection (firestore.rules); the app can only read
/// its own entry. Never on the web, where Pro is decided by the server.
final testerAllowedProvider = StreamProvider<bool>((ref) {
  if (kIsWeb) return Stream.value(false);
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(false);
  return ref
      .watch(firestoreProvider)
      .collection('testers')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists && doc.data()?['enabled'] == true)
      .transform(
        StreamTransformer<bool, bool>.fromHandlers(
          // handleError's return value is discarded. Emit a value so a
          // missing/offline tester check cannot leave the invite loading.
          handleError: (error, stack, sink) => sink.add(false),
        ),
      );
});

abstract interface class TesterStore {
  bool get proOn;
  Future<void> setProOn(bool on);
}

class PreferencesTesterStore implements TesterStore {
  static const _key = 'tester_pro_on';
  final SharedPreferences _prefs;
  PreferencesTesterStore(this._prefs);

  @override
  bool get proOn => _prefs.getBool(_key) ?? false;

  @override
  Future<void> setProOn(bool on) => _prefs.setBool(_key, on);
}

/// In-memory implementation, for tests.
class InMemoryTesterStore implements TesterStore {
  @override
  bool proOn;
  InMemoryTesterStore({this.proOn = false});

  @override
  Future<void> setProOn(bool on) async => proOn = on;
}

/// Overridden in `main` with the SharedPreferences-backed store, and in
/// tests with an in-memory one.
final testerStoreProvider = Provider<TesterStore>((ref) {
  throw StateError('testerStoreProvider was not overridden — see bootstrap().');
});

class TesterPro extends Notifier<bool> {
  @override
  bool build() =>
      (ref.watch(testerAllowedProvider).value ?? false) &&
      ref.watch(testerStoreProvider).proOn;

  Future<void> set(bool on) async {
    if (!(ref.read(testerAllowedProvider).value ?? false)) return;
    await ref.read(testerStoreProvider).setProOn(on);
    state = on;
  }
}

/// Whether the tester switch is on; the plan reads as Pro while it is.
final testerProProvider = NotifierProvider<TesterPro, bool>(TesterPro.new);
