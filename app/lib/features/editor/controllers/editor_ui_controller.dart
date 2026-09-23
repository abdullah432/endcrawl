import 'package:flutter_riverpod/flutter_riverpod.dart';

class EditorUiState {
  /// The block last tapped: outlined in the list, and where "+ Block"
  /// inserts (4.1) and pasted rows land (4.2).
  final String? focusedId;
  final bool selectMode;
  final Set<String> selectedIds;

  /// The readability warning was dismissed with "Ignore" for this session.
  final bool warnDismissed;

  const EditorUiState({
    this.focusedId,
    this.selectMode = false,
    this.selectedIds = const {},
    this.warnDismissed = false,
  });

  EditorUiState copyWith({
    String? focusedId,
    bool clearFocus = false,
    bool? selectMode,
    Set<String>? selectedIds,
    bool? warnDismissed,
  }) {
    return EditorUiState(
      focusedId: clearFocus ? null : (focusedId ?? this.focusedId),
      selectMode: selectMode ?? this.selectMode,
      selectedIds: selectedIds ?? this.selectedIds,
      warnDismissed: warnDismissed ?? this.warnDismissed,
    );
  }
}

/// Editor-screen state that isn't part of the document and so stays out of
/// the undo history: focus, multi-select (3.3), and whether the warning
/// banner (3.2) was dismissed.
class EditorUiController extends Notifier<EditorUiState> {
  @override
  EditorUiState build() => const EditorUiState();

  void focus(String? id) => state = id == null ? state.copyWith(clearFocus: true) : state.copyWith(focusedId: id);

  void enterSelectMode() => state = state.copyWith(selectMode: true, selectedIds: const {});

  void exitSelectMode() => state = state.copyWith(selectMode: false, selectedIds: const {});

  void toggleSelected(String id) {
    final next = {...state.selectedIds};
    if (!next.add(id)) next.remove(id);
    state = state.copyWith(selectedIds: next);
  }

  void dismissWarn() => state = state.copyWith(warnDismissed: true);
  void resetWarn() => state = state.copyWith(warnDismissed: false);
}

/// Auto-disposed with the editor, so focus and selection never carry over
/// into the next project opened.
final editorUiControllerProvider =
    NotifierProvider.autoDispose<EditorUiController, EditorUiState>(EditorUiController.new);
