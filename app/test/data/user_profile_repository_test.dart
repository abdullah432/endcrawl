import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/data/repositories/user_profile_repository.dart';
import 'package:lastreel/domain/models/user_profile.dart';

void main() {
  test(
    'settings merge preserves server identity/count, consent, and unknown metadata',
    () async {
      final db = FakeFirebaseFirestore();
      final doc = db.doc('users/pilot');
      await doc.set({
        'schemaVersion': 1,
        'name': 'Abdullah',
        'email': 'abdullah234ktk@gmail.com',
        'projectCount': 7,
        'futureServerField': 'keep',
        'marketingOptIn': true,
        'preferences': const Preferences(usageAnalytics: false).toJson(),
      });
      final repository = FirestoreUserProfileRepository(db, uid: 'pilot');
      final before = await repository.watch().first;
      expect(before.projectCount, 7);
      expect(before.email, 'abdullah234ktk@gmail.com');
      final updated = before.copyWith(
        preferences: before.preferences.copyWith(haptics: false),
      );
      expect(updated.name, 'Abdullah');
      expect((await repository.save(updated)).isOk, true);
      final data = (await doc.get()).data()!;
      expect(data['name'], 'Abdullah');
      expect(data['projectCount'], 7);
      expect(data['futureServerField'], 'keep');
      expect(data['marketingOptIn'], true);
      expect(data['preferences']['usageAnalytics'], false);
      expect(data['preferences']['haptics'], false);
      expect(updated.toJson().containsKey('projectCount'), false);
    },
  );

  test(
    'legacy and missing profiles remain readable with unknown count',
    () async {
      final db = FakeFirebaseFirestore();
      final repository = FirestoreUserProfileRepository(db, uid: 'missing');
      expect((await repository.watch().first).projectCount, null);
      expect((await repository.save(const UserProfile())).isOk, true);
      final profile = await repository.watch().first;
      expect(profile.name, null);
      expect(profile.marketingOptIn, false);
      expect(profile.preferences.defaultFps, 24);
    },
  );
}
