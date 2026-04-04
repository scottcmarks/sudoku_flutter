// puzzle_engine.dart — high-level game state wrapper
//
// Owns a PuzzleFFI handle, manages undo/redo in Dart, and exposes a clean
// ChangeNotifier API that the Flutter UI can listen to.

// ignore_for_file: unnecessary_import
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'puzzle_ffi.dart';
import 'puzzle_types.dart';

// ---------------------------------------------------------------------------
// Undo entry: snapshot of PUZZLE bytes + selected cell + marker
// ---------------------------------------------------------------------------

class _UndoEntry {
  final Uint8List puzzleBytes;
  final int selectedOffset;
  final SudokuMarker marker;
  final bool digitAssistant;

  _UndoEntry({
    required this.puzzleBytes,
    required this.selectedOffset,
    required this.marker,
    required this.digitAssistant,
  });
}

// ---------------------------------------------------------------------------
// PuzzleEngine
// ---------------------------------------------------------------------------

class PuzzleEngine extends ChangeNotifier {
  PuzzleFFI? _ffi;

  // UI state not stored inside the C engine
  int selectedOffset = -1;
  SudokuMarker currentMarker = SudokuMarker.pen;
  bool digitAssistant = false;
  bool checkAnswer    = false;
  bool userHasWon     = false;
  bool generating     = false;

  // The last generation parameters (for "new game same type" button)
  SudokuMapType  lastMapType   = SudokuMapType.square;
  SudokuAdjType  lastAdjType   = SudokuAdjType.normal;
  SudokuDifficulty lastDifficulty = SudokuDifficulty.medium;

  // Cached cell data (rebuilt after any mutation)
  final List<CellData?> _cells = List.filled(81, null);
  List<int> colorMap = List.filled(9, 0);

  // Undo / redo stacks
  final List<_UndoEntry> _undoStack = [];
  final List<_UndoEntry> _redoStack = [];

  bool get hasUndo => _undoStack.isNotEmpty;
  bool get hasRedo => _redoStack.isNotEmpty;
  bool get isLoaded => _ffi != null;

  CellData? cell(int offset) => _cells[offset];

  // ---------------------------------------------------------------------------
  // Generation
  // ---------------------------------------------------------------------------

  /// Generates a new puzzle on a background isolate, then rebuilds cell cache.
  Future<bool> generateNewPuzzle({
    SudokuMapType  mapType    = SudokuMapType.square,
    SudokuAdjType  adjType    = SudokuAdjType.normal,
    SudokuDifficulty difficulty = SudokuDifficulty.medium,
    SudokuQuality  quality    = SudokuQuality.compromise,
  }) async {
    generating = true;
    notifyListeners();

    lastMapType    = mapType;
    lastAdjType    = adjType;
    lastDifficulty = difficulty;

    // Free any existing puzzle
    _ffi?.dispose();
    _ffi = null;

    // Run blocking generation in an isolate
    final success = await _generateIsolate(mapType, adjType, difficulty, quality);

    if (success != null) {
      _ffi = success;
      _undoStack.clear();
      _redoStack.clear();
      selectedOffset  = -1;
      currentMarker   = SudokuMarker.pen;
      digitAssistant  = false;
      checkAnswer     = false;
      userHasWon      = false;
      _rebuildCache();
    }

    generating = false;
    notifyListeners();
    return success != null;
  }

  /// Runs the blocking C generation call in an isolate.
  static Future<PuzzleFFI?> _generateIsolate(
    SudokuMapType  mapType,
    SudokuAdjType  adjType,
    SudokuDifficulty difficulty,
    SudokuQuality  quality,
  ) async {
    // We can't pass Dart objects with native handles across isolates,
    // so we create the PuzzleFFI on the root isolate but run the generation
    // call synchronously in a compute-style isolate using a port trick.
    //
    // Simpler approach: create and generate inside the isolate, but since
    // PuzzleFFI wraps a native pointer, it can only be used on the thread
    // it was created on.  We therefore run generation on a dedicated
    // long-lived isolate and send the PuzzleData bytes back.
    //
    // For now (desktop/iOS dev build) we run synchronously on the main
    // isolate so as not to block the engine's thread-safety story.
    // TODO: replace with Isolate.run once the native pointer lifetime
    // semantics are sorted out (or use a SendPort-based worker isolate).

    final ffi = PuzzleFFI();
    debugPrint('FFI generate starting...');
    final ok = ffi.generate(
      mapType:    mapType,
      adjType:    adjType,
      difficulty: difficulty,
      quality:    quality,
    );
    debugPrint('FFI generate returned ok=$ok');
    if (!ok) {
      ffi.dispose();
      return null;
    }
    return ffi;
  }

  // ---------------------------------------------------------------------------
  // Cell cache
  // ---------------------------------------------------------------------------

  void _rebuildCache() {
    if (_ffi == null) return;
    for (int i = 0; i < 81; i++) {
      _cells[i] = _ffi!.getCell(i);
    }
    colorMap = _ffi!.getColorMap();
  }

  // ---------------------------------------------------------------------------
  // User interaction (each mutating op saves undo snapshot first)
  // ---------------------------------------------------------------------------

  void selectCell(int offset) {
    if (offset == selectedOffset) return;
    _pushUndo();
    selectedOffset = offset;
    notifyListeners();
  }

  void setUserAnswer(int offset, int digit) {
    if (_ffi == null) return;
    final c = _cells[offset];
    if (c == null || c.isClue) return;

    _pushUndo();
    _ffi!.setUserAnswer(offset, digit, c.userAnswer, digitAssistant: digitAssistant);
    _cells[offset] = _ffi!.getCell(offset);

    if (digitAssistant) {
      // Digit assistant may have touched neighbor cells
      _rebuildNeighbors(offset);
    }

    _checkWin();
    notifyListeners();
  }

  void clearUserAnswer(int offset) => setUserAnswer(offset, 0);

  void toggleElimBit(int offset, int digit) {
    if (_ffi == null) return;
    _pushUndo();
    _ffi!.toggleElimBit(offset, digit);
    _cells[offset] = _ffi!.getCell(offset);
    notifyListeners();
  }

  void toggleSmallMode(int offset) {
    if (_ffi == null) return;
    _pushUndo();
    _ffi!.toggleSmallMode(offset);
    _cells[offset] = _ffi!.getCell(offset);
    notifyListeners();
  }

  void toggleDigitAssistant() {
    if (_ffi == null) return;
    _pushUndo();
    digitAssistant = !digitAssistant;
    if (digitAssistant) {
      _ffi!.digitAssistantAll();
      _rebuildCache();
    }
    notifyListeners();
  }

  void toggleCheckAnswer() {
    checkAnswer = !checkAnswer;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Undo / redo
  // ---------------------------------------------------------------------------

  void undo() {
    if (_undoStack.isEmpty || _ffi == null) return;
    final entry = _undoStack.removeLast();
    _redoStack.add(_currentEntry());
    _applyEntry(entry);
  }

  void redo() {
    if (_redoStack.isEmpty || _ffi == null) return;
    final entry = _redoStack.removeLast();
    _undoStack.add(_currentEntry());
    _applyEntry(entry);
  }

  void _pushUndo() {
    _undoStack.add(_currentEntry());
    _redoStack.clear();
  }

  _UndoEntry _currentEntry() => _UndoEntry(
    puzzleBytes:    _ffi!.snapshotBytes(),
    selectedOffset: selectedOffset,
    marker:         currentMarker,
    digitAssistant: digitAssistant,
  );

  void _applyEntry(_UndoEntry e) {
    _ffi!.restoreBytes(e.puzzleBytes);
    selectedOffset = e.selectedOffset;
    currentMarker  = e.marker;
    digitAssistant = e.digitAssistant;
    _rebuildCache();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Restart
  // ---------------------------------------------------------------------------

  void restart() {
    if (_ffi == null) return;
    _pushUndo();
    _ffi!.restart();
    selectedOffset = -1;
    userHasWon     = false;
    _rebuildCache();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // State queries
  // ---------------------------------------------------------------------------

  SudokuPuzzleState get puzzleState {
    if (_ffi == null) return SudokuPuzzleState.unfinished;
    return _ffi!.getState();
  }

  int get distance => _ffi?.distance() ?? 81;

  List<bool> get maxedDigits => _ffi?.maxedDigits() ?? List.filled(10, false);

  bool sameGroupRight(int offset) => _ffi?.sameGroupRight(offset) ?? false;
  bool sameGroupBelow(int offset) => _ffi?.sameGroupBelow(offset) ?? false;
  bool areNeighbors(int o1, int o2) => _ffi?.areNeighbors(o1, o2) ?? false;

  /// Expose raw snapshot bytes for album persistence.
  Uint8List? snapshotBytes() => _ffi?.snapshotBytes();

  /// Load a pre-existing PuzzleFFI handle (e.g. restored from saved game).
  void loadFromFFI(PuzzleFFI ffi, {List<int>? colorMap}) {
    _ffi?.dispose();
    _ffi = ffi;
    _undoStack.clear();
    _redoStack.clear();
    selectedOffset = -1;
    currentMarker  = SudokuMarker.pen;
    digitAssistant = false;
    checkAnswer    = false;
    userHasWon     = false;
    _rebuildCache();
    if (colorMap != null) this.colorMap = List.of(colorMap);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _rebuildNeighbors(int offset) {
    // After digit assistant propagation, re-read all cells in the same
    // row, col, and group as `offset`.
    final c = _cells[offset];
    if (c == null) return;
    for (int i = 0; i < 81; i++) {
      final ci = _cells[i];
      if (ci == null) continue;
      if (ci.row == c.row || ci.col == c.col || ci.group == c.group) {
        _cells[i] = _ffi!.getCell(i);
      }
    }
  }

  void _checkWin() {
    if (!userHasWon && _ffi != null) {
      if (_ffi!.getState() == SudokuPuzzleState.correct) {
        userHasWon = true;
      }
    }
  }

  @override
  void dispose() {
    _ffi?.dispose();
    super.dispose();
  }
}
