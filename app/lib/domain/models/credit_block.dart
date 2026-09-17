import 'dart:math';

import 'json_support.dart';

final _uidRandom = Random();

/// Short random block id — same shape as the prototype's `uid()`
/// (`'b' + Math.random().toString(36).slice(2,8)`).
String newBlockId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final s = List.generate(6, (_) => chars[_uidRandom.nextInt(chars.length)]).join();
  return 'b$s';
}

enum LeaderStyle { dots, clean, rule }

enum CastCollapseMode { auto, never, always }

/// One row of the two-column cast block: a role/actor pair, a blank
/// spacer, or a spanning "and" / "with" special-billing row.
sealed class CastRow {
  const CastRow();

  /// Stable schema discriminator. Never derive this from a UI label.
  String get wireType;

  Map<String, Object?> toJson();
}

class PairCastRow extends CastRow {
  final String role;
  final String actor;
  const PairCastRow({this.role = '', this.actor = ''});

  PairCastRow copyWith({String? role, String? actor}) =>
      PairCastRow(role: role ?? this.role, actor: actor ?? this.actor);

  @override
  String get wireType => 'pair';

  @override
  Map<String, Object?> toJson() => {'type': wireType, 'role': role, 'actor': actor};
}

class GapCastRow extends CastRow {
  const GapCastRow();

  @override
  String get wireType => 'gap';

  @override
  Map<String, Object?> toJson() => {'type': wireType};
}

class SpanCastRow extends CastRow {
  final String text;
  const SpanCastRow({this.text = 'and'});

  SpanCastRow copyWith({String? text}) => SpanCastRow(text: text ?? this.text);

  @override
  String get wireType => 'span';

  @override
  Map<String, Object?> toJson() => {'type': wireType, 'text': text};
}

/// Throws [UnknownDocumentTypeException] on an unrecognised row type rather
/// than skipping it — see [creditBlockFromJson] for why.
CastRow castRowFromJson(Map<String, Object?> json) {
  final type = asString(json['type'], '');
  return switch (type) {
    'pair' => PairCastRow(role: asString(json['role'], ''), actor: asString(json['actor'], '')),
    'gap' => const GapCastRow(),
    'span' => SpanCastRow(text: asString(json['text'], 'and')),
    _ => throw UnknownDocumentTypeException('cast row', type),
  };
}

/// Base for every block type in the document. The document is an ordered
/// list of typed blocks (§6 of the brief) — this is that typing.
sealed class CreditBlock {
  final String id;
  final bool muted;

  /// True when this block references a font file that isn't available on
  /// this device. Derived at load time from the device's font set, never
  /// persisted — a font missing on one device is not missing on another.
  final bool fontMissing;

  const CreditBlock({required this.id, this.muted = false, this.fontMissing = false});

  /// Stable schema discriminator, written to storage. Deliberately separate
  /// from [glyph]/[typeLabel]: UI copy must be free to change without
  /// migrating stored documents.
  String get wireType;

  /// Short glyph shown on the block card (matches prototype `TYPES`).
  String get glyph;
  String get typeLabel;

  CreditBlock withMuted(bool value);

  Map<String, Object?> toJson();

  /// Fields shared by every block type.
  Map<String, Object?> baseJson() => {'type': wireType, 'id': id, 'muted': muted};
}

class TitleBlock extends CreditBlock {
  final String banner;
  final String title;
  final String byline;
  final double titleScale;

  const TitleBlock({
    required super.id,
    super.muted,
    super.fontMissing,
    this.banner = '',
    this.title = '',
    this.byline = '',
    this.titleScale = 3.1,
  });

  @override
  String get wireType => 'title';
  @override
  String get glyph => 'TTL';
  @override
  String get typeLabel => 'Title card';

  TitleBlock copyWith({
    String? banner,
    String? title,
    String? byline,
    double? titleScale,
    bool? muted,
  }) {
    return TitleBlock(
      id: id,
      muted: muted ?? this.muted,
      fontMissing: fontMissing,
      banner: banner ?? this.banner,
      title: title ?? this.title,
      byline: byline ?? this.byline,
      titleScale: titleScale ?? this.titleScale,
    );
  }

  @override
  CreditBlock withMuted(bool value) => copyWith(muted: value);

  @override
  Map<String, Object?> toJson() => {
        ...baseJson(),
        'banner': banner,
        'title': title,
        'byline': byline,
        'titleScale': titleScale,
      };

  factory TitleBlock.fromJson(Map<String, Object?> json) => TitleBlock(
        id: asString(json['id'], newBlockId()),
        muted: asBool(json['muted'], false),
        banner: asString(json['banner'], ''),
        title: asString(json['title'], ''),
        byline: asString(json['byline'], ''),
        titleScale: asDouble(json['titleScale'], 3.1),
      );
}

class DeptBlock extends CreditBlock {
  final String header;
  final List<String> names;

  const DeptBlock({
    required super.id,
    super.muted,
    super.fontMissing,
    this.header = 'DEPARTMENT',
    this.names = const ['Name'],
  });

  @override
  String get wireType => 'dept';
  @override
  String get glyph => 'DEPT';
  @override
  String get typeLabel => 'Department';

  DeptBlock copyWith({String? header, List<String>? names, bool? muted}) {
    return DeptBlock(
      id: id,
      muted: muted ?? this.muted,
      fontMissing: fontMissing,
      header: header ?? this.header,
      names: names ?? this.names,
    );
  }

  @override
  CreditBlock withMuted(bool value) => copyWith(muted: value);

  @override
  Map<String, Object?> toJson() => {...baseJson(), 'header': header, 'names': names};

  factory DeptBlock.fromJson(Map<String, Object?> json) => DeptBlock(
        id: asString(json['id'], newBlockId()),
        muted: asBool(json['muted'], false),
        header: asString(json['header'], 'DEPARTMENT'),
        names: asStringList(json['names']),
      );
}

class CastBlock extends CreditBlock {
  final String header;
  final LeaderStyle leader;
  final double gutter; // fraction of canvas width, e.g. .06
  final CastCollapseMode collapse;
  final List<CastRow> rows;

  const CastBlock({
    required super.id,
    super.muted,
    super.fontMissing,
    this.header = 'CAST',
    this.leader = LeaderStyle.dots,
    this.gutter = 0.06,
    this.collapse = CastCollapseMode.auto,
    this.rows = const [],
  });

  @override
  String get wireType => 'cast';
  @override
  String get glyph => 'CAST';
  @override
  String get typeLabel => 'Two-column cast';

  CastBlock copyWith({
    String? header,
    LeaderStyle? leader,
    double? gutter,
    CastCollapseMode? collapse,
    List<CastRow>? rows,
    bool? muted,
  }) {
    return CastBlock(
      id: id,
      muted: muted ?? this.muted,
      fontMissing: fontMissing,
      header: header ?? this.header,
      leader: leader ?? this.leader,
      gutter: gutter ?? this.gutter,
      collapse: collapse ?? this.collapse,
      rows: rows ?? this.rows,
    );
  }

  @override
  CreditBlock withMuted(bool value) => copyWith(muted: value);

  @override
  Map<String, Object?> toJson() => {
        ...baseJson(),
        'header': header,
        'leader': leader.name,
        'gutter': gutter,
        'collapse': collapse.name,
        'rows': [for (final row in rows) row.toJson()],
      };

  factory CastBlock.fromJson(Map<String, Object?> json) => CastBlock(
        id: asString(json['id'], newBlockId()),
        muted: asBool(json['muted'], false),
        header: asString(json['header'], 'CAST'),
        leader: asEnum(LeaderStyle.values, json['leader'], LeaderStyle.dots),
        gutter: asDouble(json['gutter'], 0.06),
        collapse: asEnum(CastCollapseMode.values, json['collapse'], CastCollapseMode.auto),
        rows: [for (final row in asMapList(json['rows'])) castRowFromJson(row)],
      );
}

class SongBlock extends CreditBlock {
  final String songTitle;
  final String artist;
  final String courtesy;

  const SongBlock({
    required super.id,
    super.muted,
    super.fontMissing,
    this.songTitle = '',
    this.artist = '',
    this.courtesy = '',
  });

  @override
  String get wireType => 'song';
  @override
  String get glyph => 'SONG';
  @override
  String get typeLabel => 'Soundtrack';

  SongBlock copyWith({String? songTitle, String? artist, String? courtesy, bool? muted}) {
    return SongBlock(
      id: id,
      muted: muted ?? this.muted,
      fontMissing: fontMissing,
      songTitle: songTitle ?? this.songTitle,
      artist: artist ?? this.artist,
      courtesy: courtesy ?? this.courtesy,
    );
  }

  @override
  CreditBlock withMuted(bool value) => copyWith(muted: value);

  @override
  Map<String, Object?> toJson() => {
        ...baseJson(),
        'songTitle': songTitle,
        'artist': artist,
        'courtesy': courtesy,
      };

  factory SongBlock.fromJson(Map<String, Object?> json) => SongBlock(
        id: asString(json['id'], newBlockId()),
        muted: asBool(json['muted'], false),
        songTitle: asString(json['songTitle'], ''),
        artist: asString(json['artist'], ''),
        courtesy: asString(json['courtesy'], ''),
      );
}

class LogosBlock extends CreditBlock {
  final List<String> logos;

  const LogosBlock({
    required super.id,
    super.muted,
    super.fontMissing,
    this.logos = const [],
  });

  @override
  String get wireType => 'logos';
  @override
  String get glyph => 'LOGO';
  @override
  String get typeLabel => 'Logo row';

  LogosBlock copyWith({List<String>? logos, bool? muted}) {
    return LogosBlock(
      id: id,
      muted: muted ?? this.muted,
      fontMissing: fontMissing,
      logos: logos ?? this.logos,
    );
  }

  @override
  CreditBlock withMuted(bool value) => copyWith(muted: value);

  @override
  Map<String, Object?> toJson() => {...baseJson(), 'logos': logos};

  factory LogosBlock.fromJson(Map<String, Object?> json) => LogosBlock(
        id: asString(json['id'], newBlockId()),
        muted: asBool(json['muted'], false),
        logos: asStringList(json['logos']),
      );
}

class ThanksBlock extends CreditBlock {
  final String header;
  final List<String> names;

  const ThanksBlock({
    required super.id,
    super.muted,
    super.fontMissing,
    this.header = 'SPECIAL THANKS',
    this.names = const [],
  });

  @override
  String get wireType => 'thanks';
  @override
  String get glyph => 'THX';
  @override
  String get typeLabel => 'Special thanks';

  ThanksBlock copyWith({String? header, List<String>? names, bool? muted}) {
    return ThanksBlock(
      id: id,
      muted: muted ?? this.muted,
      fontMissing: fontMissing,
      header: header ?? this.header,
      names: names ?? this.names,
    );
  }

  @override
  CreditBlock withMuted(bool value) => copyWith(muted: value);

  @override
  Map<String, Object?> toJson() => {...baseJson(), 'header': header, 'names': names};

  factory ThanksBlock.fromJson(Map<String, Object?> json) => ThanksBlock(
        id: asString(json['id'], newBlockId()),
        muted: asBool(json['muted'], false),
        header: asString(json['header'], 'SPECIAL THANKS'),
        names: asStringList(json['names']),
      );
}

class HoldBlock extends CreditBlock {
  final List<String> lines;
  final double hold;
  final double fadeIn;
  final double fadeOut;

  const HoldBlock({
    required super.id,
    super.muted,
    super.fontMissing,
    this.lines = const ['HOLD CARD'],
    this.hold = 3,
    this.fadeIn = 1,
    this.fadeOut = 1,
  });

  @override
  String get wireType => 'hold';
  @override
  String get glyph => 'HOLD';
  @override
  String get typeLabel => 'Hold card';

  HoldBlock copyWith({
    List<String>? lines,
    double? hold,
    double? fadeIn,
    double? fadeOut,
    bool? muted,
  }) {
    return HoldBlock(
      id: id,
      muted: muted ?? this.muted,
      fontMissing: fontMissing,
      lines: lines ?? this.lines,
      hold: hold ?? this.hold,
      fadeIn: fadeIn ?? this.fadeIn,
      fadeOut: fadeOut ?? this.fadeOut,
    );
  }

  @override
  CreditBlock withMuted(bool value) => copyWith(muted: value);

  @override
  Map<String, Object?> toJson() => {
        ...baseJson(),
        'lines': lines,
        'hold': hold,
        'fadeIn': fadeIn,
        'fadeOut': fadeOut,
      };

  factory HoldBlock.fromJson(Map<String, Object?> json) => HoldBlock(
        id: asString(json['id'], newBlockId()),
        muted: asBool(json['muted'], false),
        lines: asStringList(json['lines']),
        hold: asDouble(json['hold'], 3),
        fadeIn: asDouble(json['fadeIn'], 1),
        fadeOut: asDouble(json['fadeOut'], 1),
      );
}

class SpacerBlock extends CreditBlock {
  final double seconds;

  const SpacerBlock({
    required super.id,
    super.muted,
    super.fontMissing,
    this.seconds = 1.5,
  });

  @override
  String get wireType => 'spacer';
  @override
  String get glyph => 'SPC';
  @override
  String get typeLabel => 'Spacer';

  SpacerBlock copyWith({double? seconds, bool? muted}) {
    return SpacerBlock(
      id: id,
      muted: muted ?? this.muted,
      fontMissing: fontMissing,
      seconds: seconds ?? this.seconds,
    );
  }

  @override
  CreditBlock withMuted(bool value) => copyWith(muted: value);

  @override
  Map<String, Object?> toJson() => {...baseJson(), 'seconds': seconds};

  factory SpacerBlock.fromJson(Map<String, Object?> json) => SpacerBlock(
        id: asString(json['id'], newBlockId()),
        muted: asBool(json['muted'], false),
        seconds: asDouble(json['seconds'], 1.5),
      );
}

/// Decodes one stored block.
///
/// An unrecognised `type` throws instead of being skipped: a build that
/// silently dropped blocks it didn't understand would destroy the user's
/// content the next time the project autosaved. Failing here surfaces as a
/// "this project was made with a newer version" error, which is recoverable;
/// silent data loss is not.
CreditBlock creditBlockFromJson(Map<String, Object?> json) {
  final type = asString(json['type'], '');
  return switch (type) {
    'title' => TitleBlock.fromJson(json),
    'dept' => DeptBlock.fromJson(json),
    'cast' => CastBlock.fromJson(json),
    'song' => SongBlock.fromJson(json),
    'logos' => LogosBlock.fromJson(json),
    'thanks' => ThanksBlock.fromJson(json),
    'hold' => HoldBlock.fromJson(json),
    'spacer' => SpacerBlock.fromJson(json),
    _ => throw UnknownDocumentTypeException('block', type),
  };
}

class UnknownDocumentTypeException implements Exception {
  final String what;
  final String type;
  const UnknownDocumentTypeException(this.what, this.type);

  @override
  String toString() => 'Unknown $what type "$type" — written by a newer version of the app.';
}
