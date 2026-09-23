import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/sources/session_store.dart';
import '../../../data/repositories/template_repository.dart';
import '../../../domain/engine/roll_engine.dart';
import '../../../domain/engine/roll_engine.dart' as roll show blockSeconds, readabilityCulprit;
import '../../../domain/models/credit_block.dart';
import '../../../domain/models/credit_face.dart';
import '../../../domain/models/project.dart';
import '../../../domain/models/project_settings.dart';
import '../../../domain/models/render_summary.dart';

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

  int get formatW => settings.format.w;
  int get formatH => settings.format.h;

  CreditFace get face => settings.face ?? CreditFace.grotesque;

  RollGeometry get geometry => computeGeometry(formatW: formatW, formatH: formatH, face: face);

  RollEngineResult get engine => computeEngine(
        project: settings,
        activeBlocks: activeBlocks,
        measurements: measurements,
        geometry: geometry,
      );

  /// Seconds each active block is on screen, by id.
  Map<String, double> get blockSeconds => roll.blockSeconds(engine, activeBlocks, measurements);

  /// The block a "too fast" warning is pinned on, if any.
  String? get readabilityCulprit => roll.readabilityCulprit(engine, activeBlocks);

  /// The whole roll, head to tail.
  Duration get runtime => Duration(milliseconds: (engine.totalFrames / engine.fps * 1000).round());

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

  /// True while a new document is still being set up (2.2, 2.3). Edits then
  /// change it in memory only: the first write is [markOpened], so backing
  /// out of the flow leaves nothing behind.
  bool _draft = false;

  @override
  ProjectState build() {
    ref.onDispose(() => _debounce?.cancel());
    return ProjectState.newDocument();
  }

  // ---------- document lifecycle ----------

  /// Starts a new document from a template, with only the [include]d
  /// sections (all of its defaults when null). Not persisted until the
  /// editor opens it, so backing out of the new-project flow leaves nothing
  /// behind.
  void createFromTemplate(ProjectTemplate t, {Set<String>? include}) {
    _debounce?.cancel();
    _draft = true;
    state = ProjectState(
      project: Project.create(
        title: t.defaultTitle,
        blocks: _templates.blocksFor(t.id, include: include),
        settings: ProjectSettings(
          formatId: t.formatId,
          fps: t.fps,
          mode: TimingMode.duration,
          durationFrames: (t.durationSeconds * t.fps).round(),
        ),
      ),
    );
  }

  /// Starts an empty document using the account's defaults for new
  /// projects (Settings → Defaults).
  void createEmpty({double fps = 24, String formatId = '16x9', bool safeGuides = true}) {
    _debounce?.cancel();
    _draft = true;
    state = ProjectState(
      project: Project.create(
        settings: ProjectSettings(
          formatId: formatId,
          fps: fps,
          safeGuides: safeGuides,
          durationFrames: (60 * fps).round(),
        ),
      ),
    );
  }

  /// Loads a stored project into the editor. Marking it open is the
  /// editor's job ([markOpened]), so the flag tracks what is actually on
  /// screen rather than what was merely loaded.
  Future<Result<Project>> openProject(String id) async {
    final result = await _repository.load(id);
    if (result case Ok(:final value)) {
      _debounce?.cancel();
      _draft = false;
      state = ProjectState(project: value);
    }
    return result;
  }

  /// Records that this device has the document open and persists it, so it
  /// shows up in the library and — if the app is killed before
  /// [closeProject] — is offered as a recovery on next launch.
  ///
  /// The open/left-open marks go to the device session rather than the
  /// document: with a cloud store the document is shared across devices, and
  /// "I had this open" is not true of all of them.
  Future<void> markOpened() async {
    _draft = false;
    final project = state.project;
    await _session.setLastOpened(project.id);
    await _session.setLeftOpen(project.id);
    await _save(project);
  }

  /// Clean close: clears the left-open mark so the next launch offers a
  /// plain "continue" rather than a crash recovery.
  Future<void> closeProject() async {
    _debounce?.cancel();
    await _save(state.project);
    await _session.setLeftOpen(null);
  }

  /// Stores the outcome of a render (6.3/6.4) straight away, so the library
  /// can show it. Not an edit, so it leaves `updatedAt` — and the library's
  /// order — alone.
  Future<void> recordRender(RenderSummary summary) async {
    state = state.copyWith(project: state.project.copyWith(lastRender: summary));
    if (_draft) return;
    _debounce?.cancel();
    await _save(state.project);
  }

  void renameProject(String title) {
    final clean = sanitizeProjectTitle(title);
    if (clean == null || clean == state.project.title) return;
    _writeDocument(state.project.copyWith(title: clean));
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
  SessionStore get _session => ref.read(sessionStoreProvider);

  /// The single write path for document content.
  void _writeDocument(Project next) {
    state = state.copyWith(project: next.touch());
    _scheduleSave();
  }

  void _scheduleSave() {
    if (_draft) return;
    _debounce?.cancel();
    _debounce = Timer(_autosaveDebounce, () => _save(state.project));
  }

  Future<void> _save(Project project) async {
    state = state.copyWith(saveState: SaveState.saving, clearSaveFailure: true);
    final result = await _repository.save(project);
    switch (result) {
      case Ok(:final value):
        // The store may enrich what it persisted — Firestore stamps the
        // owning uid on first write. Adopt only that, and only when no newer
        // edit has landed, so a slow save can't clobber newer local content.
        final current = state.project;
        final adopted = current.id == value.id && current.ownerId == null && value.ownerId != null
            ? current.copyWith(ownerId: value.ownerId)
            : current;
        state = state.copyWith(project: adopted, saveState: SaveState.saved, clearSaveFailure: true);
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

  /// History is bounded: the oldest step drops off past this many.
  static const historyLimit = 50;

  /// Typing into one field is one undo step, not one per keystroke: edits
  /// sharing a [coalesce] key within this window fold into the last step.
  static const _coalesceWindow = Duration(milliseconds: 1500);
  String? _coalesceKey;
  DateTime? _coalesceAt;

  void _push(List<CreditBlock> next, {String? coalesce}) {
    final now = DateTime.now();
    final fold = coalesce != null &&
        coalesce == _coalesceKey &&
        _coalesceAt != null &&
        now.difference(_coalesceAt!) < _coalesceWindow &&
        state.history.isNotEmpty;
    _coalesceKey = coalesce;
    _coalesceAt = now;
    if (!fold) {
      final hist = [...state.history, state.blocks];
      if (hist.length > historyLimit) hist.removeAt(0);
      state = state.copyWith(history: hist, future: const []);
    }
    _writeDocument(state.project.copyWith(blocks: next));
  }

  /// Replaces one block with [fn] of it. [field] names the text field being
  /// typed into, so a burst of keystrokes there is a single undo step.
  void patchBlock(String id, CreditBlock Function(CreditBlock) fn, {String? field}) {
    _push([for (final b in state.blocks) b.id == id ? fn(b) : b], coalesce: field == null ? null : '$id/$field');
  }

  void undo() {
    if (state.history.isEmpty) return;
    _coalesceKey = null;
    final hist = [...state.history];
    final prev = hist.removeLast();
    final future = [state.blocks, ...state.future];
    state = state.copyWith(history: hist, future: future);
    _writeDocument(state.project.copyWith(blocks: prev));
  }

  void redo() {
    if (state.future.isEmpty) return;
    _coalesceKey = null;
    final fut = [...state.future];
    final next = fut.removeAt(0);
    final history = [...state.history, state.blocks];
    state = state.copyWith(history: history, future: fut);
    _writeDocument(state.project.copyWith(blocks: next));
  }

  bool get canUndo => state.history.isNotEmpty;
  bool get canRedo => state.future.isNotEmpty;

  void addBlock(CreditBlock block) => _push([...state.blocks, block]);

  /// Inserts [block] after [afterId] — the block in focus when "+ Block"
  /// was tapped (4.1) — or at the end when there is none.
  void insertBlock(CreditBlock block, {String? afterId}) {
    final at = afterId == null ? -1 : state.blocks.indexWhere((b) => b.id == afterId);
    _push([...state.blocks]..insert(at < 0 ? state.blocks.length : at + 1, block));
  }

  /// Puts a removed block back where it was — the toast's Undo (3.5), which
  /// restores that block even if other edits have happened since.
  void restoreBlock(CreditBlock block, int index) {
    if (state.blocks.any((b) => b.id == block.id)) return;
    _push([...state.blocks]..insert(index.clamp(0, state.blocks.length), block));
  }

  /// Duplicates the block in place and returns the copy's id.
  String? duplicateBlock(String id) {
    final idx = state.blocks.indexWhere((b) => b.id == id);
    if (idx < 0) return null;
    final copy = state.blocks[idx].withId(newBlockId());
    _push([...state.blocks]..insert(idx + 1, copy));
    return copy.id;
  }

  void toggleMute(String id) => patchBlock(id, (b) => b.withMuted(!b.muted));

  /// Removes a block and returns it, for the "Removed … Undo" toast.
  CreditBlock? deleteBlock(String id) {
    final idx = state.blocks.indexWhere((b) => b.id == id);
    if (idx < 0) return null;
    final removed = state.blocks[idx];
    _push([...state.blocks]..removeAt(idx));
    return removed;
  }

  void reorder(int from, int to) {
    if (from == to || from < 0 || to < 0) return;
    final next = [...state.blocks];
    final moved = next.removeAt(from);
    next.insert(to, moved);
    _push(next);
  }

  /// Restyles the selected blocks that have the style: [leader] applies to
  /// cast and crew lists, [columns] to name lists. Others are left alone.
  void restyle(Set<String> ids, {LeaderStyle? leader, int? columns}) {
    _push([
      for (final b in state.blocks)
        if (!ids.contains(b.id))
          b
        else
          switch (b) {
            PairListBlock() when leader != null => b.copyWith(leader: leader),
            NameListBlock() when columns != null => b.copyWith(columns: columns),
            _ => b,
          },
    ]);
  }

  /// Mutes the selection — or unmutes it, when every selected block is
  /// already muted — so the same button reverses itself.
  void bulkMute(Set<String> ids) {
    final selected = state.blocks.where((b) => ids.contains(b.id));
    final mute = !selected.every((b) => b.muted);
    _push([for (final b in state.blocks) ids.contains(b.id) ? b.withMuted(mute) : b]);
  }

  void bulkDelete(Set<String> ids) {
    _push(state.blocks.where((b) => !ids.contains(b.id)).toList());
  }

  // ---------- cast block editing ----------

  void setCastLeader(String blockId, LeaderStyle leader) =>
      patchBlock(blockId, (b) => (b as PairListBlock).copyWith(leader: leader));

  void setCastGutter(String blockId, double gutter) =>
      patchBlock(blockId, (b) => (b as PairListBlock).copyWith(gutter: gutter));

  void setCastCollapse(String blockId, CastCollapseMode mode) =>
      patchBlock(blockId, (b) => (b as PairListBlock).copyWith(collapse: mode));

  void setCastRows(String blockId, List<CastRow> rows) =>
      patchBlock(blockId, (b) => (b as PairListBlock).copyWith(rows: rows));

  void addCastRow(String blockId) =>
      patchBlock(blockId, (b) => (b as PairListBlock).copyWith(rows: [...b.rows, const PairCastRow()]));

  void addCastBillingRow(String blockId) =>
      patchBlock(blockId, (b) => (b as PairListBlock).copyWith(rows: [...b.rows, const SpanCastRow()]));

  void addCastGapRow(String blockId) =>
      patchBlock(blockId, (b) => (b as PairListBlock).copyWith(rows: [...b.rows, const GapCastRow()]));

  /// Edits one row; [field] ("role", "name") coalesces typing into one
  /// undo step.
  void updateCastRow(String blockId, int index, CastRow Function(CastRow) fn, {String? field}) {
    patchBlock(blockId, (b) {
      final cast = b as PairListBlock;
      return cast.copyWith(rows: [for (var i = 0; i < cast.rows.length; i++) i == index ? fn(cast.rows[i]) : cast.rows[i]]);
    }, field: field == null ? null : 'row$index/$field');
  }

  void removeCastRow(String blockId, int index) {
    patchBlock(blockId, (b) {
      final cast = b as PairListBlock;
      return cast.copyWith(rows: [for (var i = 0; i < cast.rows.length; i++) if (i != index) cast.rows[i]]);
    });
  }

  /// Appends pasted rows (4.2) to a cast or crew block in one undo step.
  void appendCastRows(String blockId, List<CastRow> rows) {
    if (rows.isEmpty) return;
    patchBlock(blockId, (b) => (b as PairListBlock).copyWith(rows: [...b.rows, ...rows]));
  }

  void appendCastEntry(String blockId, String role, String actor) {
    if (role.isEmpty && actor.isEmpty) return;
    patchBlock(blockId, (b) => (b as PairListBlock).copyWith(rows: [...b.rows, PairCastRow(role: role, actor: actor)]));
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
