import 'package:flutter_riverpod/flutter_riverpod.dart';

enum EditorSheet { none, add, look, background, duration, paste, block, export }

class EditorUiState {
  final bool selectMode;
  final Set<String> selectedIds;
  final EditorSheet sheet;
  final String? sheetBlockId;
  final bool warnDismissed;

  const EditorUiState({
    this.selectMode = false,
    this.selectedIds = const {},
    this.sheet = EditorSheet.none,
    this.sheetBlockId,
    this.warnDismissed = false,
  });

  EditorUiState copyWith({
    bool? selectMode,
    Set<String>? selectedIds,
    EditorSheet? sheet,
    String? sheetBlockId,
    bool clearSheetBlockId = false,
    bool? warnDismissed,
  }) {
    return EditorUiState(
      selectMode: selectMode ?? this.selectMode,
      selectedIds: selectedIds ?? this.selectedIds,
      sheet: sheet ?? this.sheet,
      sheetBlockId: clearSheetBlockId ? null : (sheetBlockId ?? this.sheetBlockId),
      warnDismissed: warnDismissed ?? this.warnDismissed,
    );
  }
}

/// Editor-screen-only UI state that doesn't belong in the undo history:
/// which sheet is open, multi-select mode and selection, and whether the
/// judder/readability warning banner was dismissed for this session.
class EditorUiController extends Notifier<EditorUiState> {
  @override
  EditorUiState build() => const EditorUiState();

  void toggleSelectMode() {
    state = state.copyWith(selectMode: !state.selectMode, selectedIds: const {});
  }

  void toggleSelected(String id) {
    final next = {...state.selectedIds};
    if (!next.add(id)) next.remove(id);
    state = state.copyWith(selectedIds: next);
  }

  void clearSelection() => state = state.copyWith(selectedIds: const {});

  void openSheet(EditorSheet sheet, {String? blockId}) {
    state = state.copyWith(sheet: sheet, sheetBlockId: blockId, clearSheetBlockId: blockId == null);
  }

  void closeSheet() {
    state = state.copyWith(sheet: EditorSheet.none, clearSheetBlockId: true);
  }

  void dismissWarn() => state = state.copyWith(warnDismissed: true);
  void resetWarn() => state = state.copyWith(warnDismissed: false);
}

final editorUiControllerProvider = NotifierProvider<EditorUiController, EditorUiState>(EditorUiController.new);
