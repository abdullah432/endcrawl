import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/result.dart';
import 'package:lastreel/features/export/data/export_destinations_native.dart';
import 'package:lastreel/features/export/models/export_artifact.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('gal');
  const destinations = PlatformExportDestinations();
  const artifact = ExportArtifact(
    location: '/renders/credits.mp4',
    filename: 'credits.mp4',
    mimeType: 'video/mp4',
    bytes: 500,
  );
  late List<String> calls;
  var allowed = false;
  var grantsPermission = true;
  String? saveError;
  setUp(() {
    calls = [];
    allowed = false;
    grantsPermission = true;
    saveError = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'hasAccess':
              return allowed;
            case 'requestAccess':
              return allowed = allowed || grantsPermission;
            case 'putVideo':
              if (saveError != null) throw PlatformException(code: saveError!);
              expect(call.arguments['path'], artifact.location);
              return null;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'first save requests access and writes the actual rendered file',
    () async {
      expect(await destinations.saveToPhotos(artifact), isA<Ok<void>>());
      expect(calls.first, 'hasAccess');
      expect(
        calls.indexOf('requestAccess'),
        lessThan(calls.indexOf('putVideo')),
      );
      expect(calls.where((c) => c == 'putVideo'), hasLength(1));
    },
  );
  test('denied access never claims to save or writes a video', () async {
    grantsPermission = false;
    final result = await destinations.saveToPhotos(artifact);
    expect(result, isA<Err<void>>());
    expect((result as Err<void>).failure.kind, FailureKind.permission);
    expect(result.failure.message, contains('Settings'));
    expect(calls, isNot(contains('putVideo')));
  });
  test(
    'library errors remain delivery failures, with recovery instructions',
    () async {
      allowed = true;
      saveError = 'NOT_ENOUGH_SPACE';
      final result = await destinations.saveToPhotos(artifact);
      expect(result, isA<Err<void>>());
      expect((result as Err<void>).failure.message, contains('space'));
    },
  );
}
