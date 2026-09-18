import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// On-device document store: one JSON file per project, plus a small session
/// file holding the last-opened project id.
///
/// Deliberately document-shaped rather than relational, so the local layout
/// mirrors the eventual `users/{uid}/projects/{projectId}` documents and the
/// Firestore repository can reuse the same encoded maps unchanged.
///
/// Takes its [root] directory rather than resolving one itself, so tests can
/// point it at a temp directory without stubbing platform channels.
class ProjectLocalStore {
  static const _sessionFileName = 'session.json';
  static const _tempSuffix = '.tmp';

  /// Project ids are app-minted, but the store still refuses anything that
  /// isn't a plain id — a `../` in a document id must never be able to
  /// address a path outside [root].
  static final _safeId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  final Directory root;

  ProjectLocalStore(this.root);

  Future<void> ensureReady() async {
    if (!await root.exists()) await root.create(recursive: true);
  }

  File _fileFor(String id) {
    if (!_safeId.hasMatch(id)) throw ArgumentError.value(id, 'id', 'Not a valid project id');
    return File(p.join(root.path, '$id.json'));
  }

  /// Every stored project, skipping any file that fails to parse so one
  /// corrupt document can't make the whole library unreadable.
  Future<List<Map<String, Object?>>> readAll() async {
    await ensureReady();
    final out = <Map<String, Object?>>[];
    await for (final entity in root.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name == _sessionFileName || !name.endsWith('.json')) continue;
      try {
        final decoded = jsonDecode(await entity.readAsString());
        if (decoded is Map) out.add(decoded.cast<String, Object?>());
      } on FormatException {
        continue;
      } on FileSystemException {
        continue;
      }
    }
    return out;
  }

  Future<Map<String, Object?>?> read(String id) async {
    final file = _fileFor(id);
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) return null;
    return decoded.cast<String, Object?>();
  }

  /// Writes to a temp file and renames it into place. A rename within one
  /// filesystem is atomic, so a crash mid-save leaves the previous version
  /// intact instead of a half-written document.
  Future<void> write(String id, Map<String, Object?> json) async {
    await ensureReady();
    final target = _fileFor(id);
    final temp = File('${target.path}$_tempSuffix');
    await temp.writeAsString(jsonEncode(json), flush: true);
    await temp.rename(target.path);
  }

  Future<void> delete(String id) async {
    final file = _fileFor(id);
    if (await file.exists()) await file.delete();
  }

  File get _sessionFile => File(p.join(root.path, _sessionFileName));

  Future<String?> readLastOpenedId() async {
    final file = _sessionFile;
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map && decoded['lastOpenedProjectId'] is String) {
        return decoded['lastOpenedProjectId'] as String;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  Future<void> writeLastOpenedId(String? id) async {
    await ensureReady();
    final file = _sessionFile;
    final temp = File('${file.path}$_tempSuffix');
    await temp.writeAsString(jsonEncode({'lastOpenedProjectId': id}), flush: true);
    await temp.rename(file.path);
  }
}
