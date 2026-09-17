import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/canvas_format.dart';
import '../models/credit_block.dart';
import '../models/project_settings.dart';
import '../models/roll_engine.dart';
import '../repository/template_repository.dart';

class ProjectState {
  final String name;
  final ProjectSettings settings;
  final List<CreditBlock> blocks;
  final List<List<CreditBlock>> history;
  final List<List<CreditBlock>> future;
  final RollMeasurements measurements;
  final bool hasRecoverableProject;
  final bool offline;

  const ProjectState({
    this.name = 'UNTITLED',
    this.settings = const ProjectSettings(),
    this.blocks = const [],
    this.history = const [],
    this.future = const [],
    this.measurements = const RollMeasurements(),
    this.hasRecoverableProject = true,
    this.offline = false,
  });

  List<CreditBlock> get activeBlocks => blocks.where((b) => !b.muted).toList();

  int get formatW => settings.formatId == 'custom' ? settings.customW : CanvasFormat.byId(settings.formatId).w;
  int get formatH => settings.formatId == 'custom' ? settings.customH : CanvasFormat.byId(settings.formatId).h;

  CreditFace get face => settings.face ?? CreditFace.grotesque;

  RollGeometry get geometry => computeGeometry(formatW: formatW, formatH: formatH, face: face);

  RollEngineResult get engine => computeEngine(
        project: settings,
        activeBlocks: activeBlocks,
        measurements: measurements,
        geometry: geometry,
      );

  ProjectState copyWith({
    String? name,
    ProjectSettings? settings,
    List<CreditBlock>? blocks,
    List<List<CreditBlock>>? history,
    List<List<CreditBlock>>? future,
    RollMeasurements? measurements,
    bool? hasRecoverableProject,
    bool? offline,
  }) {
    return ProjectState(
      name: name ?? this.name,
      settings: settings ?? this.settings,
      blocks: blocks ?? this.blocks,
      history: history ?? this.history,
      future: future ?? this.future,
      measurements: measurements ?? this.measurements,
      hasRecoverableProject: hasRecoverableProject ?? this.hasRecoverableProject,
      offline: offline ?? this.offline,
    );
  }
}

/// Owns the project document: format/fps/timing settings and the ordered
/// block list, with bounded undo/redo — the direct port of the
/// prototype's `state.project` + `state.blocks` + `push()`/`patch()`.
class ProjectController extends Notifier<ProjectState> {
  static const _repo = TemplateRepository();

  @override
  ProjectState build() => const ProjectState();

  // ---------- lifecycle ----------

  void loadTemplate(ProjectTemplate t) {
    state = ProjectState(
      name: t.projectName ?? state.name,
      blocks: _repo.seed(t.id),
      settings: state.settings.copyWith(
        formatId: t.formatId,
        fps: t.fps,
        mode: TimingMode.duration,
        durationFrames: (t.durationSeconds * t.fps).round(),
      ),
      measurements: const RollMeasurements(),
    );
  }

  void startEmpty() {
    state = state.copyWith(blocks: []);
  }

  void openRecovered() {
    state = ProjectState(
      name: 'THE LONG WAY DOWN',
      blocks: _repo.seed('short'),
      settings: state.settings,
      hasRecoverableProject: false,
    );
  }

  void discardRecovery() => state = state.copyWith(hasRecoverableProject: false);

  // ---------- format / fps ----------

  void setFormat(String id) => state = state.copyWith(settings: state.settings.copyWith(formatId: id));

  void applyCustomSize(int w, int h) {
    state = state.copyWith(settings: state.settings.copyWith(formatId: 'custom', customW: w, customH: h));
  }

  void setFps(double v) {
    final e = state.engine;
    final newDurF = e.fps == 0 ? state.settings.durationFrames : (e.totalFrames / e.fps * v).round();
    state = state.copyWith(settings: state.settings.copyWith(fps: v, durationFrames: newDurF));
  }

  // ---------- timing ----------

  void setModeDuration() {
    final e = state.engine;
    state = state.copyWith(
      settings: state.settings.copyWith(mode: TimingMode.duration, durationFrames: e.totalFrames.round()),
    );
  }

  void setModeSpeed() {
    final e = state.engine;
    state = state.copyWith(
      settings: state.settings.copyWith(mode: TimingMode.speed, ppf: e.ppf.clamp(1, double.infinity).roundToDouble()),
    );
  }

  void setDurationFrames(int frames) {
    state = state.copyWith(settings: state.settings.copyWith(mode: TimingMode.duration, durationFrames: frames));
  }

  void durationUp() {
    final e = state.engine;
    setDurationFrames((e.totalFrames + state.settings.fps).round());
  }

  void durationDown() {
    final e = state.engine;
    final floor = (state.settings.fps * 5).round();
    setDurationFrames((e.totalFrames - state.settings.fps).round().clamp(floor, 1 << 30));
  }

  void setPpf(double v) => state = state.copyWith(settings: state.settings.copyWith(mode: TimingMode.speed, ppf: v));

  void applySnap(int ppf) =>
      state = state.copyWith(settings: state.settings.copyWith(mode: TimingMode.speed, ppf: ppf.toDouble()));

  void setHead(double v) => state = state.copyWith(settings: state.settings.copyWith(headSeconds: v.clamp(0.0, 1e6)));
  void setTail(double v) => state = state.copyWith(settings: state.settings.copyWith(tailSeconds: v.clamp(0.0, 1e6)));
  void headUp() => setHead(double.parse((state.settings.headSeconds + 0.5).toStringAsFixed(1)));
  void headDown() => setHead(double.parse((state.settings.headSeconds - 0.5).toStringAsFixed(1)));
  void tailUp() => setTail(double.parse((state.settings.tailSeconds + 0.5).toStringAsFixed(1)));
  void tailDown() => setTail(double.parse((state.settings.tailSeconds - 0.5).toStringAsFixed(1)));

  // ---------- look / background ----------

  void setLook(RollLook look) => state = state.copyWith(settings: state.settings.copyWith(look: look));
  void setTilt(double v) => state = state.copyWith(settings: state.settings.copyWith(tilt: v));
  void setVanishingDistance(double v) => state = state.copyWith(settings: state.settings.copyWith(vanishingDistance: v));
  void setBackground(MonitorBackground bg) => state = state.copyWith(settings: state.settings.copyWith(background: bg));
  void toggleSafeGuides() => state = state.copyWith(settings: state.settings.copyWith(safeGuides: !state.settings.safeGuides));

  // ---------- history-tracked block edits ----------

  void _push(List<CreditBlock> next) {
    final hist = [...state.history, state.blocks];
    if (hist.length > 25) hist.removeAt(0);
    state = state.copyWith(blocks: next, history: hist, future: const []);
  }

  void patchBlock(String id, CreditBlock Function(CreditBlock) fn) {
    _push([for (final b in state.blocks) b.id == id ? fn(b) : b]);
  }

  void undo() {
    if (state.history.isEmpty) return;
    final hist = [...state.history];
    final prev = hist.removeLast();
    state = state.copyWith(blocks: prev, history: hist, future: [state.blocks, ...state.future]);
  }

  void redo() {
    if (state.future.isEmpty) return;
    final fut = [...state.future];
    final next = fut.removeAt(0);
    state = state.copyWith(blocks: next, history: [...state.history, state.blocks], future: fut);
  }

  bool get canUndo => state.history.isNotEmpty;
  bool get canRedo => state.future.isNotEmpty;

  void addBlock(CreditBlock block) => _push([...state.blocks, block]);

  void addDepartmentSet() {
    _push([
      ...state.blocks,
      for (final h in TemplateRepository.standardDepartmentOrder) _repo.mkDept(h, const ['Name']),
    ]);
  }

  void duplicateBlock(String id) {
    final idx = state.blocks.indexWhere((b) => b.id == id);
    if (idx < 0) return;
    final b = state.blocks[idx];
    final copy = _cloneWithNewId(b);
    final next = [...state.blocks]..insert(idx + 1, copy);
    _push(next);
  }

  CreditBlock _cloneWithNewId(CreditBlock b) {
    final id = newBlockId();
    return switch (b) {
      TitleBlock v => TitleBlock(id: id, banner: v.banner, title: v.title, byline: v.byline, titleScale: v.titleScale),
      DeptBlock v => DeptBlock(id: id, header: v.header, names: v.names),
      CastBlock v => CastBlock(id: id, header: v.header, leader: v.leader, gutter: v.gutter, collapse: v.collapse, rows: v.rows),
      SongBlock v => SongBlock(id: id, songTitle: v.songTitle, artist: v.artist, courtesy: v.courtesy),
      LogosBlock v => LogosBlock(id: id, logos: v.logos),
      ThanksBlock v => ThanksBlock(id: id, header: v.header, names: v.names),
      HoldBlock v => HoldBlock(id: id, lines: v.lines, hold: v.hold, fadeIn: v.fadeIn, fadeOut: v.fadeOut),
      SpacerBlock v => SpacerBlock(id: id, seconds: v.seconds),
    };
  }

  void toggleMute(String id) => patchBlock(id, (b) => b.withMuted(!b.muted));

  void deleteBlock(String id) => _push(state.blocks.where((b) => b.id != id).toList());

  void reorder(int from, int to) {
    if (from == to || from < 0 || to < 0) return;
    final next = [...state.blocks];
    final moved = next.removeAt(from);
    next.insert(to, moved);
    _push(next);
  }

  void bulkToggleCastLeader(Set<String> ids) {
    _push([
      for (final b in state.blocks)
        if (ids.contains(b.id) && b is CastBlock)
          b.copyWith(leader: b.leader == LeaderStyle.dots ? LeaderStyle.clean : LeaderStyle.dots)
        else
          b,
    ]);
  }

  void bulkMute(Set<String> ids) {
    _push([for (final b in state.blocks) ids.contains(b.id) ? b.withMuted(!b.muted) : b]);
  }

  void bulkDelete(Set<String> ids) {
    _push(state.blocks.where((b) => !ids.contains(b.id)).toList());
  }

  // ---------- cast block editing ----------

  void setCastLeader(String blockId, LeaderStyle leader) =>
      patchBlock(blockId, (b) => (b as CastBlock).copyWith(leader: leader));

  void setCastGutter(String blockId, double gutter) =>
      patchBlock(blockId, (b) => (b as CastBlock).copyWith(gutter: gutter));

  void setCastCollapse(String blockId, CastCollapseMode mode) =>
      patchBlock(blockId, (b) => (b as CastBlock).copyWith(collapse: mode));

  void setCastRows(String blockId, List<CastRow> rows) =>
      patchBlock(blockId, (b) => (b as CastBlock).copyWith(rows: rows));

  void addCastRow(String blockId) =>
      patchBlock(blockId, (b) => (b as CastBlock).copyWith(rows: [...b.rows, const PairCastRow()]));

  void addCastBillingRow(String blockId) =>
      patchBlock(blockId, (b) => (b as CastBlock).copyWith(rows: [...b.rows, const SpanCastRow()]));

  void addCastGapRow(String blockId) =>
      patchBlock(blockId, (b) => (b as CastBlock).copyWith(rows: [...b.rows, const GapCastRow()]));

  void updateCastRow(String blockId, int index, CastRow Function(CastRow) fn) {
    patchBlock(blockId, (b) {
      final cast = b as CastBlock;
      return cast.copyWith(rows: [for (var i = 0; i < cast.rows.length; i++) i == index ? fn(cast.rows[i]) : cast.rows[i]]);
    });
  }

  void removeCastRow(String blockId, int index) {
    patchBlock(blockId, (b) {
      final cast = b as CastBlock;
      return cast.copyWith(rows: [for (var i = 0; i < cast.rows.length; i++) if (i != index) cast.rows[i]]);
    });
  }

  void appendCastEntry(String blockId, String role, String actor) {
    if (role.isEmpty && actor.isEmpty) return;
    patchBlock(blockId, (b) => (b as CastBlock).copyWith(rows: [...b.rows, PairCastRow(role: role, actor: actor)]));
  }

  // ---------- measurement ----------

  void updateMeasurements(RollMeasurements m) {
    if (state.measurements.closeTo(m)) return;
    state = state.copyWith(measurements: m);
  }
}

final projectControllerProvider = NotifierProvider<ProjectController, ProjectState>(ProjectController.new);
