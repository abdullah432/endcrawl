import 'dart:math';

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
}

class PairCastRow extends CastRow {
  final String role;
  final String actor;
  const PairCastRow({this.role = '', this.actor = ''});
  PairCastRow copyWith({String? role, String? actor}) =>
      PairCastRow(role: role ?? this.role, actor: actor ?? this.actor);
}

class GapCastRow extends CastRow {
  const GapCastRow();
}

class SpanCastRow extends CastRow {
  final String text;
  const SpanCastRow({this.text = 'and'});
  SpanCastRow copyWith({String? text}) => SpanCastRow(text: text ?? this.text);
}

/// Base for every block type in the document. The document is an ordered
/// list of typed blocks (§6 of the brief) — this is that typing.
sealed class CreditBlock {
  final String id;
  final bool muted;
  final bool fontMissing;

  const CreditBlock({required this.id, this.muted = false, this.fontMissing = false});

  /// Short glyph shown on the block card (matches prototype `TYPES`).
  String get glyph;
  String get typeLabel;

  CreditBlock withMuted(bool value);
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
}
