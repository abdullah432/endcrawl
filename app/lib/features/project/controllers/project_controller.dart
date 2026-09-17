import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/template_repository.dart';
import '../../../domain/engine/roll_engine.dart';
import '../../../domain/models/canvas_format.dart';
import '../../../domain/models/credit_block.dart';
import '../../../domain/models/credit_face.dart';
import '../../../domain/models/project.dart';
import '../../../domain/models/project_settings.dart';

enum SaveState { idle, saving, saved, failed }

class ProjectState {
  /// The open document. Always present — the editor is only reachable with
  /// a project open, so callers never have to null-check it.
  final Project project;

  /// Undo history of the block list only, matching the prototype: format,
  /// timing and look changes are not undoable steps.
  final List<List<CreditBlock>> history;
  final List<List<CreditBlock>> future;

  /// Laid-out block offsets. Transient view data, never persisted.
  final RollMeasurements measurements;

  final SaveState saveState;
  final AppFailure? saveFailure;

  ProjectState({
    required this.project,
    this.history = const [],
    this.future = const [],
    this.measurements = const RollMeasurements(),
    this.saveState = SaveState.idle,
    this.saveFailure,
  });

  ProjectState.newDocument() : this(project: Project.create());

  // Delegating accessors: the UI reads the document through the state.
  String get name => project.title;
  ProjectSettings get settings => project.settings;
  List<CreditBlock> get blocks => project.blocks;

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
    Project? project,
    List<List<CreditBlock>>? history,
    List<List<CreditBlock>>? future,
    RollMeasurements? measurements,
    SaveState? saveState,
    AppFailure? saveFailure,
    bool clearSaveFailure = false,
  }) {
    return ProjectState(
      project: project ?? this.project,
      history: history ?? this.history,
      future: future ?? this.future,
      measurements: measurements ?? this.measurements,
      saveState: saveState ?? this.saveState,
      saveFailure: clearSaveFailure ? null : (saveFailure ?? this.saveFailure),
    );
  }
}

/// Owns the open document: format/fps/timing settings and the ordered block
/// list, with bounded undo/redo, and persists it through
/// [ProjectRepository] with a debounced autosave.
///
/// Every content change routes through [_writeDocument], which is what keeps
/// `updatedAt` honest and guarantees a save is scheduled — no mutation can
/// forget to persist itself. Transient view state (measurements, save
/// status) deliberately does not.
class ProjectController extends Notifier<ProjectState> {
  static const _templates = TemplateRepository();

  /// Long enough to coalesce a burst of keystrokes into one write, short
  /// enough that a kill right after an edit loses nothing meaningful.
  static const _autosaveDebounce = Duration(milliseconds: 700);

  Timer? _debounce;

  @override
  ProjectState build() {
    ref.onDispose(() => _debounce?.cancel());
    return ProjectState.newDocument();
  }

  // ---------- document lifecycle ----------

  /// Starts a new document from a template. Not persisted until the editor
  /// opens it, so backing out of the format step leaves nothing behind.
  void createFromTemplate(ProjectTemplate t) {
    state = ProjectState(
      project: Project.create(
        title: t.projectName ?? 'UNTITLED',
        blocks: _templates.seed(t.id),
        settings: ProjectSettings(
          formatId: t.formatId,
          fps: t.fps,
          mode: TimingMode.duration,
          durationFrames: (t.durationSeconds * t.fps).round(),
        ),
      ),
    );
  }

  void createEmpty() => state = ProjectState.newDocument();

  /// Loads a stored project into the editor. Marking it open is the
  /// editor's job ([markOpened]), so the flag tracks what is actually on
  /// screen rather than what was merely loaded.
  Future<Result<Project>> openProject(String id) async {
    final result = await _repository.load(id);
    if (result case Ok(:final value)) state = ProjectState(project: value);
    return result;
  }

  /// Flags the document as open and persists it, so it shows up in the
  /// library and — if the app is killed before [closeProject] — is offered
  /// as a recovery on next launch.
  Future<void> markOpened() async {
    final opened = state.project.copyWith(openedAt: DateTime.now().toUtc());
    state = state.copyWith(project: opened);
    await _repository.writeLastOpenedId(opened.id);
    await _save(opened);
  }

  /// Clean close: clears the left-open flag so the next launch offers a
  /// plain "continue" rather than a crash recovery.
  Future<void> closeProject() async {
    _debounce?.cancel();
    final closed = state.project.copyWith(clearOpenedAt: true);
    state = state.copyWith(project: closed);
    await _save(closed);
  }

  void renameProject(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed == state.project.title) return;
    _writeDocument(state.project.copyWith(title: trimmed));
  }

  /// Writes any pending change immediately — used when the app is
  /// backgrounded, where waiting out the debounce risks losing the edit.
  Future<void> flushPendingSave() async {
    if (_debounce?.isActive != true) return;
    _debounce?.cancel();
    await _save(state.project);
  }

  // ---------- persistence ----------

  ProjectRepository get _repository => ref.read(projectRepositoryProvider);

  /// The single write path for document content.
  void _writeDocument(Project next) {
    state = state.copyWith(project: next.touch());
    _scheduleSave();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(_autosaveDebounce, () => _save(state.project));
  }

  Future<void> _save(Project project) async {
    state = state.copyWith(saveState: SaveState.saving, clearSaveFailure: true);
    final result = await _repository.save(project);
    switch (result) {
      case Ok():
        state = state.copyWith(saveState: SaveState.saved, clearSaveFailure: true);
      case Err(:final failure):
        state = state.copyWith(saveState: SaveState.failed, saveFailure: failure);
    }
  }

  // ---------- format / fps ----------

  void setFormat(String id) => _updateSettings((s) => s.copyWith(formatId: id));

  void applyCustomSize(int w, int h) =>
      _updateSettings((s) => s.copyWith(formatId: 'custom', customW: w, customH: h));

  void setFps(double v) {
    final e = state.engine;
    final newDurF = e.fps == 0 ? state.settings.durationFrames : (e.totalFrames / e.fps * v).round();
    _updateSettings((s) => s.copyWith(fps: v, durationFrames: newDurF));
  }

  // ---------- timing ----------

  void setModeDuration() {
    final e = state.engine;
    _updateSettings((s) => s.copyWith(mode: TimingMode.duration, durationFrames: e.totalFrames.round()));
  }

  void setModeSpeed() {
    final e = state.engine;
    _updateSettings((s) => s.copyWith(mode: TimingMode.speed, ppf: e.ppf.clamp(1, double.infinity).roundToDouble()));
  }

  void setDurationFrames(int frames) =>
      _updateSettings((s) => s.copyWith(mode: TimingMode.duration, durationFrames: frames));

  void durationUp() {
    final e = state.engine;
    setDurationFrames((e.totalFrames + state.settings.fps).round());
  }

  void durationDown() {
    final e = state.engine;
    final floor = (state.settings.fps * 5).round();
    setDurationFrames((e.totalFrames - state.settings.fps).round().clamp(floor, 1 << 30));
  }

  void setPpf(double v) => _updateSettings((s) => s.copyWith(mode: TimingMode.speed, ppf: v));

  void applySnap(int ppf) => _updateSettings((s) => s.copyWith(mode: TimingMode.speed, ppf: ppf.toDouble()));

  void setHead(double v) => _updateSettings((s) => s.copyWith(headSeconds: v.clamp(0.0, 1e6)));
  void setTail(double v) => _updateSettings((s) => s.copyWith(tailSeconds: v.clamp(0.0, 1e6)));
  void headUp() => setHead(double.parse((state.settings.headSeconds + 0.5).toStringAsFixed(1)));
  void headDown() => setHead(double.parse((state.settings.headSeconds - 0.5).toStringAsFixed(1)));
  void tailUp() => setTail(double.parse((state.settings.tailSeconds + 0.5).toStringAsFixed(1)));
  void tailDown() => setTail(double.parse((state.settings.tailSeconds - 0.5).toStringAsFixed(1)));

  // ---------- look / background ----------

  void setLook(RollLook look) => _updateSettings((s) => s.copyWith(look: look));
  void setTilt(double v) => _updateSettings((s) => s.copyWith(tilt: v));
  void setVanishingDistance(double v) => _updateSettings((s) => s.copyWith(vanishingDistance: v));
  void setBackground(MonitorBackground bg) => _updateSettings((s) => s.copyWith(background: bg));
  void toggleSafeGuides() => _updateSettings((s) => s.copyWith(safeGuides: !state.settings.safeGuides));

  void _updateSettings(ProjectSettings Function(ProjectSettings) fn) =>
      _writeDocument(state.project.copyWith(settings: fn(state.settings)));

  // ---------- history-tracked block edits ----------

  void _push(List<CreditBlock> next) {
    final hist = [...state.history, state.blocks];
    if (hist.length > 25) hist.removeAt(0);
    state = state.copyWith(history: hist, future: const []);
    _writeDocument(state.project.copyWith(blocks: next));
  }

  void patchBlock(String id, CreditBlock Function(CreditBlock) fn) {
    _push([for (final b in state.blocks) b.id == id ? fn(b) : b]);
  }

  void undo() {
    if (state.history.isEmpty) return;
    final hist = [...state.history];
    final prev = hist.removeLast();
    final future = [state.blocks, ...state.future];
    state = state.copyWith(history: hist, future: future);
    _writeDocument(state.project.copyWith(blocks: prev));
  }

  void redo() {
    if (state.future.isEmpty) return;
    final fut = [...state.future];
    final next = fut.removeAt(0);
    final history = [...state.history, state.blocks];
    state = state.copyWith(history: history, future: fut);
    _writeDocument(state.project.copyWith(blocks: next));
  }

  bool get canUndo => state.history.isNotEmpty;
  bool get canRedo => state.future.isNotEmpty;

  void addBlock(CreditBlock block) => _push([...state.blocks, block]);

  void addDepartmentSet() {
    _push([
      ...state.blocks,
      for (final h in TemplateRepository.standardDepartmentOrder) _templates.mkDept(h, const ['Name']),
    ]);
  }

  void duplicateBlock(String id) {
    final idx = state.blocks.indexWhere((b) => b.id == id);
    if (idx < 0) return;
    final copy = _cloneWithNewId(state.blocks[idx]);
    _push([...state.blocks]..insert(idx + 1, copy));
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

  /// Layout feedback from the monitor. Deliberately does not mark the
  /// document dirty — measuring the roll is not an edit.
  void updateMeasurements(RollMeasurements m) {
    if (state.measurements.closeTo(m)) return;
    state = state.copyWith(measurements: m);
  }
}

final projectControllerProvider = NotifierProvider<ProjectController, ProjectState>(ProjectController.new);
