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

// ---------------------------------------------------------------------------
// The catalogue
// ---------------------------------------------------------------------------

/// The seven groups of the add-block library (4.1).
enum BlockGroup {
  openers('Openers'),
  people('People'),
  music('Music'),
  logos('Logos & images'),
  text('Text'),
  legal('Legal'),
  layout('Layout');

  final String label;
  const BlockGroup(this.label);
}

/// Every kind of block a roll can contain — the design's 27 (4.1).
///
/// The single source of a kind's code ("CST"), label, one-line description
/// and group; the add-block sheet, the block list, template contents and the
/// renderer all read from here, so a kind is described in exactly one place.
///
/// [wire] is the stable name written to storage. The eight kinds that
/// existed before v2 keep their original names ("dept", "cast", …) so older
/// documents read without migration; UI copy can change freely because it
/// is never stored.
enum BlockKind {
  // Openers
  title('title', 'TTL', 'Title card', 'Film title, full frame', BlockGroup.openers),
  presents('presents', 'PRS', 'Presents card', '“A Northlight production”', BlockGroup.openers),
  directedBy('directedBy', 'DIR', 'Directed by', 'One card, one name', BlockGroup.openers),
  mainCredits('mainCredits', 'MAIN', 'Main credits', 'Solo cards before the roll', BlockGroup.openers),
  // People
  castTwoColumn('cast', 'CST', 'Cast · two column', 'Role left, name right', BlockGroup.people),
  castStacked('castStacked', 'CSS', 'Cast · stacked', 'Name over role, centred', BlockGroup.people),
  department('dept', 'DPT', 'Department', 'A header and its names', BlockGroup.people),
  crewTwoColumn('crew', 'CRW', 'Crew · two column', 'Job left, name right', BlockGroup.people),
  nameList('nameList', 'LST', 'Name list', 'Many names in 2–3 columns', BlockGroup.people),
  stunts('stunts', 'STN', 'Stunts', 'Coordinator and performers', BlockGroup.people),
  // Music
  musicCue('song', 'SNG', 'Music cue', 'Title, writers, performer', BlockGroup.music),
  scoreBy('scoreBy', 'SCR', 'Score by', 'Composer card', BlockGroup.music),
  // Logos & images
  logoRow('logos', 'LGO', 'Logo row', 'Marks at one shared height', BlockGroup.logos),
  singleLogo('logo', 'LG1', 'Single logo', 'One mark, centred', BlockGroup.logos),
  still('still', 'IMG', 'Still image', 'Photo or frame grab', BlockGroup.logos),
  // Text
  thanks('thanks', 'THX', 'Special thanks', 'Names, one or more columns', BlockGroup.text),
  dedication('dedication', 'DED', 'Dedication', '“In memory of…”', BlockGroup.text),
  quote('quote', 'QTE', 'Quote', 'Line plus attribution', BlockGroup.text),
  freeText('text', 'TXT', 'Free text', 'Any paragraph', BlockGroup.text),
  locations('locations', 'LOC', 'Filming locations', 'Places, grouped by country', BlockGroup.text),
  // Legal
  copyright('copyright', 'CPY', 'Copyright notice', '© year and owner', BlockGroup.legal),
  disclaimer('disclaimer', 'DSC', 'Disclaimer', 'Fictitious persons, animals', BlockGroup.legal),
  guild('guild', 'GLD', 'Guild & union marks', 'Logos plus required lines', BlockGroup.legal),
  // Layout
  hold('hold', 'HLD', 'Hold card', 'Stops the roll for N seconds', BlockGroup.layout),
  spacer('spacer', 'SPC', 'Spacer', 'A blank gap', BlockGroup.layout),
  divider('divider', 'RUL', 'Divider', 'A thin rule or ornament', BlockGroup.layout),
  sectionHeading('heading', 'HDR', 'Section heading', 'e.g. “Second unit”', BlockGroup.layout);

  final String wire;
  final String code;
  final String label;
  final String description;
  final BlockGroup group;

  const BlockKind(this.wire, this.code, this.label, this.description, this.group);

  static final _byWire = {for (final k in values) k.wire: k};

  static BlockKind? fromWire(String wire) => _byWire[wire];
}

// ---------------------------------------------------------------------------
// Cast / crew rows
// ---------------------------------------------------------------------------

enum LeaderStyle { dots, clean, rule }

enum CastCollapseMode { auto, never, always }

/// One row of a two-column list: a role/name pair, a blank spacer, or a
/// spanning "and" / "with" special-billing row.
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

// ---------------------------------------------------------------------------
// Blocks
// ---------------------------------------------------------------------------

/// Base for every block in the document — an ordered list of typed blocks.
///
/// Twenty-seven kinds share nine shapes: kinds that hold the same data (a
/// header and names; a list of role/name pairs; a set of marks) share a
/// class and differ only in [kind], which drives their label, defaults and
/// how the roll draws them. A new kind with an existing shape is one enum
/// value, not a new class.
sealed class CreditBlock {
  final String id;
  final bool muted;

  /// True when this block references a font file that isn't available on
  /// this device. Derived at load time from the device's font set, never
  /// persisted — a font missing on one device is not missing on another.
  final bool fontMissing;

  const CreditBlock({required this.id, this.muted = false, this.fontMissing = false});

  BlockKind get kind;

  String get wireType => kind.wire;

  CreditBlock withMuted(bool value);

  /// The same content under a new id — duplicating a block.
  CreditBlock withId(String id);

  Map<String, Object?> toJson();

  /// Fields shared by every block type.
  Map<String, Object?> baseJson() => {'type': wireType, 'id': id, 'muted': muted};
}

/// TTL — the film title, full frame.
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
  BlockKind get kind => BlockKind.title;

  TitleBlock copyWith({String? id, String? banner, String? title, String? byline, double? titleScale, bool? muted}) {
    return TitleBlock(
      id: id ?? this.id,
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
  CreditBlock withId(String id) => copyWith(id: id);

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

/// A single card: an optional small header over one or more lines, and an
/// optional footer. PRS, DIR, SCR, DED, QTE, TXT, CPY, DSC and HDR are all
/// this shape; [kind] decides how the lines are set (a name, a paragraph, a
/// quotation with its attribution in [footer]).
class CardBlock extends CreditBlock {
  static const kinds = {
    BlockKind.presents,
    BlockKind.directedBy,
    BlockKind.scoreBy,
    BlockKind.dedication,
    BlockKind.quote,
    BlockKind.freeText,
    BlockKind.copyright,
    BlockKind.disclaimer,
    BlockKind.sectionHeading,
  };

  @override
  final BlockKind kind;
  final String header;
  final List<String> lines;
  final String footer;

  const CardBlock({
    required super.id,
    required this.kind,
    super.muted,
    super.fontMissing,
    this.header = '',
    this.lines = const [],
    this.footer = '',
  }) : assert(kind == BlockKind.presents ||
            kind == BlockKind.directedBy ||
            kind == BlockKind.scoreBy ||
            kind == BlockKind.dedication ||
            kind == BlockKind.quote ||
            kind == BlockKind.freeText ||
            kind == BlockKind.copyright ||
            kind == BlockKind.disclaimer ||
            kind == BlockKind.sectionHeading);

  CardBlock copyWith({String? id, String? header, List<String>? lines, String? footer, bool? muted}) {
    return CardBlock(
      id: id ?? this.id,
      kind: kind,
      muted: muted ?? this.muted,
      fontMissing: fontMissing,
      header: header ?? this.header,
      lines: lines ?? this.lines,
      footer: footer ?? this.footer,
    );
  }

  @override
  CreditBlock withMuted(bool value) => copyWith(muted: value);

  @override
  CreditBlock withId(String id) => copyWith(id: id);

  @override
  Map<String, Object?> toJson() => {...baseJson(), 'header': header, 'lines': lines, 'footer': footer};

  factory CardBlock.fromJson(BlockKind kind, Map<String, Object?> json) => CardBlock(
        id: asString(json['id'], newBlockId()),
        kind: kind,
        muted: asBool(json['muted'], false),
        header: asString(json['header'], ''),
        lines: asStringList(json['lines']),
        footer: asString(json['footer'], ''),
      );
}

/// One solo card inside [MainCreditsBlock].
class CreditEntry {
  final String header;
  final List<String> names;

  const CreditEntry({this.header = '', this.names = const []});

  CreditEntry copyWith({String? header, List<String>? names}) =>
      CreditEntry(header: header ?? this.header, names: names ?? this.names);

  Map<String, Object?> toJson() => {'header': header, 'names': names};

  factory CreditEntry.fromJson(Map<String, Object?> json) =>
      CreditEntry(header: asString(json['header'], ''), names: asStringList(json['names']));
}

/// MAIN — the solo cards before the roll ("Casting by", "Edited by"…).
class MainCreditsBlock extends CreditBlock {
  final List<CreditEntry> cards;

  const MainCreditsBlock({required super.id, super.muted, super.fontMissing, this.cards = const []});

  @override
  BlockKind get kind => BlockKind.mainCredits;

  MainCreditsBlock copyWith({String? id, List<CreditEntry>? cards, bool? muted}) => MainCreditsBlock(
        id: id ?? this.id,
        muted: muted ?? this.muted,
        fontMissing: fontMissing,
        cards: cards ?? this.cards,
      );

  @override
  CreditBlock withMuted(bool value) => copyWith(muted: value);

  @override
  CreditBlock withId(String id) => copyWith(id: id);

  @override
  Map<String, Object?> toJson() => {...baseJson(), 'cards': [for (final c in cards) c.toJson()]};

  factory MainCreditsBlock.fromJson(Map<String, Object?> json) => MainCreditsBlock(
        id: asString(json['id'], newBlockId()),
        muted: asBool(json['muted'], false),
        cards: [for (final c in asMapList(json['cards'])) CreditEntry.fromJson(c)],
      );
}

/// Role/name pairs: CST (two columns), CSS (stacked, name over role) and
/// CRW (job left, name right).
class PairListBlock extends CreditBlock {
  static const kinds = {BlockKind.castTwoColumn, BlockKind.castStacked, BlockKind.crewTwoColumn};

  @override
  final BlockKind kind;
  final String header;
  final LeaderStyle leader;
  final double gutter; // fraction of canvas width, e.g. .06
  final CastCollapseMode collapse;
  final List<CastRow> rows;

  const PairListBlock({
    required super.id,
    this.kind = BlockKind.castTwoColumn,
    super.muted,
    super.fontMissing,
    this.header = 'CAST',
    this.leader = LeaderStyle.dots,
    this.gutter = 0.06,
    this.collapse = CastCollapseMode.auto,
    this.rows = const [],
  }) : assert(kind == BlockKind.castTwoColumn || kind == BlockKind.castStacked || kind == BlockKind.crewTwoColumn);

  /// Stacked cast always renders name over role; the two-column kinds
  /// collapse to that only when the canvas is too narrow (or forced).
  bool get alwaysStacked => kind == BlockKind.castStacked || collapse == CastCollapseMode.always;

  PairListBlock copyWith({
    String? id,
    String? header,
    LeaderStyle? leader,
    double? gutter,
    CastCollapseMode? collapse,
    List<CastRow>? rows,
    bool? muted,
  }) {
    return PairListBlock(
      id: id ?? this.id,
      kind: kind,
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
  CreditBlock withId(String id) => copyWith(id: id);

  @override
  Map<String, Object?> toJson() => {
        ...baseJson(),
        'header': header,
        'leader': leader.name,
        'gutter': gutter,
        'collapse': collapse.name,
        'rows': [for (final row in rows) row.toJson()],
      };

  factory PairListBlock.fromJson(BlockKind kind, Map<String, Object?> json) => PairListBlock(
        id: asString(json['id'], newBlockId()),
        kind: kind,
        muted: asBool(json['muted'], false),
        header: asString(json['header'], 'CAST'),
        leader: asEnum(LeaderStyle.values, json['leader'], LeaderStyle.dots),
        gutter: asDouble(json['gutter'], 0.06),
        collapse: asEnum(CastCollapseMode.values, json['collapse'], CastCollapseMode.auto),
        rows: [for (final row in asMapList(json['rows'])) castRowFromJson(row)],
      );
}

/// A header and its names: DPT, LST, STN, THX and LOC.
///
/// [columns] of 0 lets the renderer choose (one column for a short list,
/// more as it grows and as the canvas allows).
class NameListBlock extends CreditBlock {
  static const kinds = {
    BlockKind.department,
    BlockKind.nameList,
    BlockKind.stunts,
    BlockKind.thanks,
    BlockKind.locations,
  };

  @override
  final BlockKind kind;
  final String header;
  final List<String> names;
  final int columns;

  const NameListBlock({
    required super.id,
    this.kind = BlockKind.department,
    super.muted,
    super.fontMissing,
    this.header = 'DEPARTMENT',
    this.names = const [],
    this.columns = 0,
  }) : assert(kind == BlockKind.department ||
            kind == BlockKind.nameList ||
            kind == BlockKind.stunts ||
            kind == BlockKind.thanks ||
            kind == BlockKind.locations);

  NameListBlock copyWith({String? id, String? header, List<String>? names, int? columns, bool? muted}) {
    return NameListBlock(
      id: id ?? this.id,
      kind: kind,
      muted: muted ?? this.muted,
      fontMissing: fontMissing,
      header: header ?? this.header,
      names: names ?? this.names,
      columns: columns ?? this.columns,
    );
  }

  @override
  CreditBlock withMuted(bool value) => copyWith(muted: value);

  @override
  CreditBlock withId(String id) => copyWith(id: id);

  @override
  Map<String, Object?> toJson() => {...baseJson(), 'header': header, 'names': names, 'columns': columns};

  factory NameListBlock.fromJson(BlockKind kind, Map<String, Object?> json) => NameListBlock(
        id: asString(json['id'], newBlockId()),
        kind: kind,
        muted: asBool(json['muted'], false),
        header: asString(json['header'], kind == BlockKind.thanks ? 'SPECIAL THANKS' : 'DEPARTMENT'),
        names: asStringList(json['names']),
        columns: asInt(json['columns'], 0),
      );
}

/// SNG — one music cue.
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
  BlockKind get kind => BlockKind.musicCue;

  SongBlock copyWith({String? id, String? songTitle, String? artist, String? courtesy, bool? muted}) {
    return SongBlock(
      id: id ?? this.id,
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
  CreditBlock withId(String id) => copyWith(id: id);

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

/// Marks at a shared height: LGO (a row), LG1 (one, centred), GLD (guild
/// marks plus their required [lines]) and IMG (a still, captioned by
/// [lines]).
///
/// Marks are named placeholders in this build — the roll draws each as a
/// labelled plate. Image upload needs storage, which arrives with the real
/// render pipeline; the document shape already has room for it.
class MarkBlock extends CreditBlock {
  static const kinds = {BlockKind.logoRow, BlockKind.singleLogo, BlockKind.guild, BlockKind.still};

  @override
  final BlockKind kind;
  final List<String> marks;
  final List<String> lines;

  const MarkBlock({
    required super.id,
    this.kind = BlockKind.logoRow,
    super.muted,
    super.fontMissing,
    this.marks = const [],
    this.lines = const [],
  }) : assert(kind == BlockKind.logoRow || kind == BlockKind.singleLogo || kind == BlockKind.guild || kind == BlockKind.still);

  MarkBlock copyWith({String? id, List<String>? marks, List<String>? lines, bool? muted}) {
    return MarkBlock(
      id: id ?? this.id,
      kind: kind,
      muted: muted ?? this.muted,
      fontMissing: fontMissing,
      marks: marks ?? this.marks,
      lines: lines ?? this.lines,
    );
  }

  @override
  CreditBlock withMuted(bool value) => copyWith(muted: value);

  @override
  CreditBlock withId(String id) => copyWith(id: id);

  @override
  Map<String, Object?> toJson() => {...baseJson(), 'marks': marks, 'lines': lines};

  factory MarkBlock.fromJson(BlockKind kind, Map<String, Object?> json) => MarkBlock(
        id: asString(json['id'], newBlockId()),
        kind: kind,
        muted: asBool(json['muted'], false),
        // v1 logo rows stored their marks under "logos".
        marks: asStringList(json['marks'] ?? json['logos']),
        lines: asStringList(json['lines']),
      );
}

/// HLD — stops the roll on a card for [hold] seconds.
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
  BlockKind get kind => BlockKind.hold;

  HoldBlock copyWith({String? id, List<String>? lines, double? hold, double? fadeIn, double? fadeOut, bool? muted}) {
    return HoldBlock(
      id: id ?? this.id,
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
  CreditBlock withId(String id) => copyWith(id: id);

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

/// SPC — a blank gap, measured in seconds of roll.
class SpacerBlock extends CreditBlock {
  final double seconds;

  const SpacerBlock({required super.id, super.muted, super.fontMissing, this.seconds = 1.5});

  @override
  BlockKind get kind => BlockKind.spacer;

  SpacerBlock copyWith({String? id, double? seconds, bool? muted}) {
    return SpacerBlock(
      id: id ?? this.id,
      muted: muted ?? this.muted,
      fontMissing: fontMissing,
      seconds: seconds ?? this.seconds,
    );
  }

  @override
  CreditBlock withMuted(bool value) => copyWith(muted: value);

  @override
  CreditBlock withId(String id) => copyWith(id: id);

  @override
  Map<String, Object?> toJson() => {...baseJson(), 'seconds': seconds};

  factory SpacerBlock.fromJson(Map<String, Object?> json) => SpacerBlock(
        id: asString(json['id'], newBlockId()),
        muted: asBool(json['muted'], false),
        seconds: asDouble(json['seconds'], 1.5),
      );
}

enum DividerStyle { rule, ornament }

/// RUL — a thin rule or an ornament between sections.
class DividerBlock extends CreditBlock {
  final DividerStyle style;

  const DividerBlock({required super.id, super.muted, super.fontMissing, this.style = DividerStyle.rule});

  @override
  BlockKind get kind => BlockKind.divider;

  DividerBlock copyWith({String? id, DividerStyle? style, bool? muted}) => DividerBlock(
        id: id ?? this.id,
        muted: muted ?? this.muted,
        fontMissing: fontMissing,
        style: style ?? this.style,
      );

  @override
  CreditBlock withMuted(bool value) => copyWith(muted: value);

  @override
  CreditBlock withId(String id) => copyWith(id: id);

  @override
  Map<String, Object?> toJson() => {...baseJson(), 'style': style.name};

  factory DividerBlock.fromJson(Map<String, Object?> json) => DividerBlock(
        id: asString(json['id'], newBlockId()),
        muted: asBool(json['muted'], false),
        style: asEnum(DividerStyle.values, json['style'], DividerStyle.rule),
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
  final kind = BlockKind.fromWire(type);
  if (kind == null) throw UnknownDocumentTypeException('block', type);
  return switch (kind) {
    BlockKind.title => TitleBlock.fromJson(json),
    BlockKind.mainCredits => MainCreditsBlock.fromJson(json),
    BlockKind.musicCue => SongBlock.fromJson(json),
    BlockKind.hold => HoldBlock.fromJson(json),
    BlockKind.spacer => SpacerBlock.fromJson(json),
    BlockKind.divider => DividerBlock.fromJson(json),
    _ when CardBlock.kinds.contains(kind) => CardBlock.fromJson(kind, json),
    _ when PairListBlock.kinds.contains(kind) => PairListBlock.fromJson(kind, json),
    _ when NameListBlock.kinds.contains(kind) => NameListBlock.fromJson(kind, json),
    _ when MarkBlock.kinds.contains(kind) => MarkBlock.fromJson(kind, json),
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
