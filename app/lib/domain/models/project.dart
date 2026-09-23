import 'dart:math';

import 'credit_block.dart';
import 'json_support.dart';
import 'project_settings.dart';
import 'render_summary.dart';

const _autoIdAlphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
final _idRandom = Random();

/// A 20-character random id drawn from the same alphabet Firestore uses for
/// auto-ids, so ids minted offline are valid document ids when this project
/// is later written to `users/{uid}/projects/{projectId}` unchanged.
String newProjectId() =>
    List.generate(20, (_) => _autoIdAlphabet[_idRandom.nextInt(_autoIdAlphabet.length)]).join();

/// Trims a user-entered title and clamps it to [Project.maxTitleLength].
/// Returns null when nothing usable is left, so callers can no-op.
String? sanitizeProjectTitle(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.length <= Project.maxTitleLength
      ? trimmed
      : trimmed.substring(0, Project.maxTitleLength).trimRight();
}

/// Drops sub-millisecond precision, in UTC.
///
/// `DateTime.now()` is microsecond-precise, but every store this schema
/// targets is not: epoch-millisecond JSON and Firestore's `Timestamp` both
/// truncate. Normalising on the way in means an in-memory project and the
/// same project read back always compare equal, instead of drifting by a few
/// hundred microseconds the first time it round-trips.
DateTime atStorablePrecision(DateTime value) =>
    DateTime.fromMillisecondsSinceEpoch(value.toUtc().millisecondsSinceEpoch, isUtc: true);

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
  static const int currentSchemaVersion = 2;

  /// The design's "17/60": the title becomes the file name of every render,
  /// so it stays short. Mirrors the cap in `firestore.rules`; enforced here
  /// so an over-long title is trimmed at the point of entry rather than
  /// coming back as an opaque permission-denied from the server.
  static const int maxTitleLength = 60;

  final String id;
  final String title;

  /// The owning account's uid. Also the parent path segment the document
  /// lives under (`users/{ownerId}/projects/{id}`), and what the security
  /// rules check a request against. Nullable only so a document can be
  /// constructed before it is attributed to a signed-in user.
  final String? ownerId;

  final ProjectSettings settings;
  final List<CreditBlock> blocks;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// The last finished render, if any (schema v2).
  final RenderSummary? lastRender;

  final int schemaVersion;

  const Project({
    required this.id,
    required this.title,
    required this.settings,
    required this.blocks,
    required this.createdAt,
    required this.updatedAt,
    this.ownerId,
    this.lastRender,
    this.schemaVersion = currentSchemaVersion,
  });

  factory Project.create({
    String? id,
    String title = 'Untitled project',
    ProjectSettings settings = const ProjectSettings(),
    List<CreditBlock> blocks = const [],
    String? ownerId,
    DateTime? now,
  }) {
    final timestamp = atStorablePrecision(now ?? DateTime.now());
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

  int get blockCount => blocks.length;

  ProjectSummary get summary => ProjectSummary(
        id: id,
        title: title,
        blockCount: blocks.length,
        settings: settings,
        createdAt: createdAt,
        updatedAt: updatedAt,
        lastRender: lastRender,
        preview: CreditPreview.of(blocks),
      );

  Project copyWith({
    String? title,
    String? ownerId,
    ProjectSettings? settings,
    List<CreditBlock>? blocks,
    DateTime? updatedAt,
    RenderSummary? lastRender,
  }) {
    return Project(
      id: id,
      title: title ?? this.title,
      ownerId: ownerId ?? this.ownerId,
      settings: settings ?? this.settings,
      blocks: blocks ?? this.blocks,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastRender: lastRender ?? this.lastRender,
      schemaVersion: schemaVersion,
    );
  }

  /// Marks the document as changed now. Every edit goes through this so
  /// `updatedAt` can never drift from the actual content.
  Project touch({DateTime? now}) => copyWith(updatedAt: atStorablePrecision(now ?? DateTime.now()));

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'ownerId': ownerId,
        'title': title,
        'settings': settings.toJson(),
        'blocks': [for (final block in blocks) block.toJson()],
        'createdAt': toEpochMillis(createdAt),
        'updatedAt': toEpochMillis(updatedAt),
        if (lastRender != null) 'lastRender': lastRender!.toJson(),
      };

  factory Project.fromJson(Map<String, Object?> raw) {
    final json = migrateProjectJson(raw);
    final now = DateTime.now().toUtc();
    return Project(
      id: asString(json['id'], newProjectId()),
      ownerId: json['ownerId'] is String ? json['ownerId'] as String : null,
      // Clamped on the way in: titles written before the 60-character cap
      // must still save once they're edited.
      title: sanitizeProjectTitle(asString(json['title'], '')) ?? 'Untitled project',
      settings: ProjectSettings.fromJson(asMap(json['settings'])),
      blocks: [for (final block in asMapList(json['blocks'])) creditBlockFromJson(block)],
      createdAt: asDateTime(json['createdAt'], now),
      updatedAt: asDateTime(json['updatedAt'], now),
      lastRender: RenderSummary.fromJson(json['lastRender']),
      schemaVersion: currentSchemaVersion,
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
/// A forward-version document fails loudly instead of being silently misread.
///
/// v1 → v2 adds the optional `lastRender`; a v1 document simply has none, so
/// the step is a no-op beyond the version number, which [Project.fromJson]
/// stamps as current.
Map<String, Object?> migrateProjectJson(Map<String, Object?> json) {
  final version = asInt(json['schemaVersion'], Project.currentSchemaVersion);
  if (version > Project.currentSchemaVersion) {
    throw UnsupportedSchemaVersionException(version, Project.currentSchemaVersion);
  }
  return json;
}

/// The list-screen projection of a project: enough to render a library card
/// without materialising every block.
class ProjectSummary {
  final String id;
  final String title;
  final int blockCount;
  final ProjectSettings settings;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RenderSummary? lastRender;
  final CreditPreview preview;

  const ProjectSummary({
    required this.id,
    required this.title,
    required this.blockCount,
    required this.settings,
    required this.createdAt,
    required this.updatedAt,
    this.lastRender,
    this.preview = const CreditPreview.empty(),
  });

  /// The runtime when it is an input (duration-locked). In speed-lock the
  /// runtime falls out of the roll's measured height, which a summary
  /// doesn't have, so it is left unknown rather than guessed.
  Duration? get runtime => settings.mode == TimingMode.duration
      ? Duration(milliseconds: (settings.durationFrames / settings.fps * 1000).round())
      : null;
}

/// The first credit card of a project, as its library thumbnail shows it —
/// "DIRECTED BY / MAYA OKONKWO".
class CreditPreview {
  final String header;
  final List<String> names;

  const CreditPreview({required this.header, required this.names});

  const CreditPreview.empty()
      : header = '',
        names = const [];

  bool get isEmpty => header.isEmpty && names.isEmpty;

  /// Picks the block that best stands for the project: the first card with
  /// both a header and names, falling back to the title.
  factory CreditPreview.of(List<CreditBlock> blocks) {
    final live = blocks.where((b) => !b.muted);
    for (final block in live) {
      final preview = switch (block) {
        DeptBlock(:final header, :final names) when names.isNotEmpty => CreditPreview(header: header, names: names.take(2).toList()),
        CastBlock(:final header, :final rows) => CreditPreview(
            header: header.isEmpty ? 'Cast' : header,
            names: rows.whereType<PairCastRow>().map((r) => r.actor).take(2).toList(),
          ),
        _ => null,
      };
      if (preview != null && preview.names.isNotEmpty) return preview;
    }
    for (final block in live) {
      if (block case TitleBlock(:final title) when title.isNotEmpty) {
        return CreditPreview(header: '', names: [title]);
      }
    }
    return const CreditPreview.empty();
  }
}
