import 'dart:math';

import 'credit_block.dart';
import 'json_support.dart';
import 'project_settings.dart';

const _autoIdAlphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
final _idRandom = Random();

/// A 20-character random id drawn from the same alphabet Firestore uses for
/// auto-ids, so ids minted offline are valid document ids when this project
/// is later written to `users/{uid}/projects/{projectId}` unchanged.
String newProjectId() =>
    List.generate(20, (_) => _autoIdAlphabet[_idRandom.nextInt(_autoIdAlphabet.length)]).join();

/// One credit-roll project: the whole editable document.
///
/// This is the persistence aggregate — it maps 1:1 onto a stored document.
/// Blocks are embedded rather than kept in a child collection because v1 has
/// no collaborative editing (deliberately out of scope, §13 of the brief),
/// documents are small (a 400-name cast is well under 50 KB of JSON against
/// Firestore's 1 MB document limit), and embedding keeps a save atomic and an
/// open a single read. If collaboration or oversized documents ever arrive,
/// `blocks` moves to a `blocks` subcollection and only the repository
/// implementations change.
class Project {
  /// Bump when a stored document can no longer be read by [Project.fromJson]
  /// without transformation, and add the migration in `migrateProjectJson`.
  static const int currentSchemaVersion = 1;

  final String id;
  final String title;

  /// Owner uid. Null while the app is local-only; populated once Firebase
  /// Authentication is wired up, and used as the parent path segment.
  final String? ownerId;

  final ProjectSettings settings;
  final List<CreditBlock> blocks;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Set when the project is opened in the editor and cleared on a clean
  /// close. A project that still has this set at launch was open when the
  /// app was killed — that is what makes crash recovery real rather than a
  /// hardcoded banner.
  final DateTime? openedAt;

  final int schemaVersion;

  const Project({
    required this.id,
    required this.title,
    required this.settings,
    required this.blocks,
    required this.createdAt,
    required this.updatedAt,
    this.ownerId,
    this.openedAt,
    this.schemaVersion = currentSchemaVersion,
  });

  factory Project.create({
    String? id,
    String title = 'UNTITLED',
    ProjectSettings settings = const ProjectSettings(),
    List<CreditBlock> blocks = const [],
    String? ownerId,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return Project(
      id: id ?? newProjectId(),
      title: title,
      settings: settings,
      blocks: blocks,
      ownerId: ownerId,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  bool get wasLeftOpen => openedAt != null;

  int get blockCount => blocks.length;

  ProjectSummary get summary => ProjectSummary(
        id: id,
        title: title,
        blockCount: blocks.length,
        settings: settings,
        updatedAt: updatedAt,
        wasLeftOpen: wasLeftOpen,
      );

  Project copyWith({
    String? title,
    String? ownerId,
    ProjectSettings? settings,
    List<CreditBlock>? blocks,
    DateTime? updatedAt,
    DateTime? openedAt,
    bool clearOpenedAt = false,
  }) {
    return Project(
      id: id,
      title: title ?? this.title,
      ownerId: ownerId ?? this.ownerId,
      settings: settings ?? this.settings,
      blocks: blocks ?? this.blocks,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      openedAt: clearOpenedAt ? null : (openedAt ?? this.openedAt),
      schemaVersion: schemaVersion,
    );
  }

  /// Marks the document as changed now. Every edit goes through this so
  /// `updatedAt` can never drift from the actual content.
  Project touch({DateTime? now}) => copyWith(updatedAt: (now ?? DateTime.now()).toUtc());

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'ownerId': ownerId,
        'title': title,
        'settings': settings.toJson(),
        'blocks': [for (final block in blocks) block.toJson()],
        'createdAt': toEpochMillis(createdAt),
        'updatedAt': toEpochMillis(updatedAt),
        'openedAt': openedAt == null ? null : toEpochMillis(openedAt!),
      };

  factory Project.fromJson(Map<String, Object?> raw) {
    final json = migrateProjectJson(raw);
    final now = DateTime.now().toUtc();
    return Project(
      id: asString(json['id'], newProjectId()),
      ownerId: json['ownerId'] is String ? json['ownerId'] as String : null,
      title: asString(json['title'], 'UNTITLED'),
      settings: ProjectSettings.fromJson(asMap(json['settings'])),
      blocks: [for (final block in asMapList(json['blocks'])) creditBlockFromJson(block)],
      createdAt: asDateTime(json['createdAt'], now),
      updatedAt: asDateTime(json['updatedAt'], now),
      openedAt: asDateTimeOrNull(json['openedAt']),
      schemaVersion: asInt(json['schemaVersion'], currentSchemaVersion),
    );
  }
}

/// Raised when a stored document is newer than this build understands.
class UnsupportedSchemaVersionException implements Exception {
  final int found;
  final int supported;
  const UnsupportedSchemaVersionException(this.found, this.supported);

  @override
  String toString() =>
      'Project uses schema v$found but this build understands up to v$supported.';
}

/// Brings a stored document up to [Project.currentSchemaVersion].
///
/// Migrations are applied in order and each one is responsible for a single
/// version step, so a document written by any earlier build can be opened.
/// There are no migrations yet — v1 is the first shipped schema — but the
/// hook exists so the first one has an obvious home and a forward-version
/// document fails loudly instead of being silently misread.
Map<String, Object?> migrateProjectJson(Map<String, Object?> json) {
  final version = asInt(json['schemaVersion'], Project.currentSchemaVersion);
  if (version > Project.currentSchemaVersion) {
    throw UnsupportedSchemaVersionException(version, Project.currentSchemaVersion);
  }
  return json;
}

/// The list-screen projection of a project: enough to render a row without
/// materialising every block.
class ProjectSummary {
  final String id;
  final String title;
  final int blockCount;
  final ProjectSettings settings;
  final DateTime updatedAt;
  final bool wasLeftOpen;

  const ProjectSummary({
    required this.id,
    required this.title,
    required this.blockCount,
    required this.settings,
    required this.updatedAt,
    required this.wasLeftOpen,
  });
}
