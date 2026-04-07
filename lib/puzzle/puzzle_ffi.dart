// puzzle_ffi.dart — dart:ffi bindings to the C engine (sudoku_ffi.h)
//
// On iOS/macOS the symbols live in the process itself (compiled into the app).
// On Android they live in libsudoku_engine.so.
// On desktop (macOS app) they can also live in the process.

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'puzzle_types.dart';

// ---------------------------------------------------------------------------
// Load the native library
// ---------------------------------------------------------------------------

DynamicLibrary _openLib() {
  if (Platform.isIOS || Platform.isMacOS) {
    return DynamicLibrary.process();
  }
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libsudoku_engine.so');
  }
  if (Platform.isLinux) {
    return DynamicLibrary.open('libsudoku_engine.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('sudoku_engine.dll');
  }
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}

final _lib = _openLib();

// ---------------------------------------------------------------------------
// C struct layout for SudokuCell (must match sudoku_ffi.h exactly)
// 9 × int32 = 36 bytes
// ---------------------------------------------------------------------------

// ignore_for_file: non_constant_identifier_names
final class _SudokuCellNative extends Struct {
  @Int32() external int solution;
  @Int32() external int mask;
  @Int32() external int elim_bits;
  @Int32() external int user_answer;
  @Int32() external int display_small_digits;
  @Int32() external int display_marker;
  @Int32() external int group;
  @Int32() external int row;
  @Int32() external int col;
}

// ---------------------------------------------------------------------------
// Native function typedefs
// ---------------------------------------------------------------------------

typedef _SetGroupMapsDirNative = Void Function(Pointer<Utf8>);
typedef _SetGroupMapsDirDart  = void Function(Pointer<Utf8>);

typedef _NewNative  = Pointer<Void> Function();
typedef _FreeNative = Void         Function(Pointer<Void>);
typedef _GenerateNative = Int32 Function(
    Pointer<Void>, Int32, Int32, Int32, Int32);
typedef _CancelNative = Void Function(Pointer<Void>);
typedef _GetCellNative = Void Function(
    Pointer<Void>, Int32, Pointer<_SudokuCellNative>);
typedef _GetColorMapNative = Void Function(Pointer<Void>, Pointer<Int32>);
typedef _SameGroupNative   = Int32 Function(Pointer<Void>, Int32);
typedef _AreNeighborsNative= Int32 Function(Pointer<Void>, Int32, Int32);
typedef _SetAnswerNative   = Void  Function(Pointer<Void>, Int32, Int32, Int32, Int32);
typedef _ToggleElimNative  = Void  Function(Pointer<Void>, Int32, Int32);
typedef _ToggleSmallNative = Int32 Function(Pointer<Void>, Int32);
typedef _DaAllNative       = Void  Function(Pointer<Void>);
typedef _GetStateNative    = Int32 Function(Pointer<Void>, Pointer<Int32>);
typedef _DistanceNative    = Int32 Function(Pointer<Void>);
typedef _MaxedNative       = Void  Function(Pointer<Void>, Pointer<Int32>);
typedef _ByteSizeNative    = Int32 Function();
typedef _GetBytesNative    = Void  Function(Pointer<Void>, Pointer<Uint8>);
typedef _SetBytesNative    = Void  Function(Pointer<Void>, Pointer<Uint8>);
typedef _SetupLoadedNative = Void  Function(Pointer<Void>, Int32, Int32);
typedef _RestartNative     = Void  Function(Pointer<Void>);

// Dart-callable typedefs
typedef _NewDart       = Pointer<Void> Function();
typedef _FreeDart      = void          Function(Pointer<Void>);
typedef _GenerateDart  = int  Function(Pointer<Void>, int, int, int, int);
typedef _CancelDart    = void Function(Pointer<Void>);
typedef _GetCellDart   = void Function(Pointer<Void>, int, Pointer<_SudokuCellNative>);
typedef _GetColorDart  = void Function(Pointer<Void>, Pointer<Int32>);
typedef _SameGroupDart = int  Function(Pointer<Void>, int);
typedef _NeighborsDart = int  Function(Pointer<Void>, int, int);
typedef _SetAnswerDart = void Function(Pointer<Void>, int, int, int, int);
typedef _ToggleElimDart= void Function(Pointer<Void>, int, int);
typedef _ToggleSmallDart=int  Function(Pointer<Void>, int);
typedef _DaAllDart     = void Function(Pointer<Void>);
typedef _GetStateDart  = int  Function(Pointer<Void>, Pointer<Int32>);
typedef _DistanceDart  = int  Function(Pointer<Void>);
typedef _MaxedDart     = void Function(Pointer<Void>, Pointer<Int32>);
typedef _ByteSizeDart  = int  Function();
typedef _GetBytesDart  = void Function(Pointer<Void>, Pointer<Uint8>);
typedef _SetBytesDart  = void Function(Pointer<Void>, Pointer<Uint8>);
typedef _SetupLoadedDart = void Function(Pointer<Void>, int, int);
typedef _RestartDart   = void Function(Pointer<Void>);

// ---------------------------------------------------------------------------
// Bound functions
// ---------------------------------------------------------------------------

final _sudokuSetGroupMapsDir = _lib
    .lookup<NativeFunction<_SetGroupMapsDirNative>>('sudoku_set_group_maps_dir')
    .asFunction<_SetGroupMapsDirDart>();

final _sudokuNew = _lib
    .lookup<NativeFunction<_NewNative>>('sudoku_new')
    .asFunction<_NewDart>();
final _sudokuFree = _lib
    .lookup<NativeFunction<_FreeNative>>('sudoku_free')
    .asFunction<_FreeDart>();
final _sudokuGenerate = _lib
    .lookup<NativeFunction<_GenerateNative>>('sudoku_generate')
    .asFunction<_GenerateDart>();
final _sudokuCancel = _lib
    .lookup<NativeFunction<_CancelNative>>('sudoku_cancel')
    .asFunction<_CancelDart>();
final _sudokuGetCell = _lib
    .lookup<NativeFunction<_GetCellNative>>('sudoku_get_cell')
    .asFunction<_GetCellDart>();
final _sudokuGetColorMap = _lib
    .lookup<NativeFunction<_GetColorMapNative>>('sudoku_get_color_map')
    .asFunction<_GetColorDart>();
final _sudokuSameGroupRight = _lib
    .lookup<NativeFunction<_SameGroupNative>>('sudoku_same_group_right')
    .asFunction<_SameGroupDart>();
final _sudokuSameGroupBelow = _lib
    .lookup<NativeFunction<_SameGroupNative>>('sudoku_same_group_below')
    .asFunction<_SameGroupDart>();
final _sudokuAreNeighbors = _lib
    .lookup<NativeFunction<_AreNeighborsNative>>('sudoku_are_neighbors')
    .asFunction<_NeighborsDart>();
final _sudokuSetUserAnswer = _lib
    .lookup<NativeFunction<_SetAnswerNative>>('sudoku_set_user_answer')
    .asFunction<_SetAnswerDart>();
final _sudokuToggleElimBit = _lib
    .lookup<NativeFunction<_ToggleElimNative>>('sudoku_toggle_elim_bit')
    .asFunction<_ToggleElimDart>();
final _sudokuToggleSmallMode = _lib
    .lookup<NativeFunction<_ToggleSmallNative>>('sudoku_toggle_small_mode')
    .asFunction<_ToggleSmallDart>();
final _sudokuDaAll = _lib
    .lookup<NativeFunction<_DaAllNative>>('sudoku_digit_assistant_all')
    .asFunction<_DaAllDart>();
final _sudokuGetState = _lib
    .lookup<NativeFunction<_GetStateNative>>('sudoku_get_state')
    .asFunction<_GetStateDart>();
final _sudokuDistance = _lib
    .lookup<NativeFunction<_DistanceNative>>('sudoku_distance')
    .asFunction<_DistanceDart>();
final _sudokuMaxedDigits = _lib
    .lookup<NativeFunction<_MaxedNative>>('sudoku_maxed_digits')
    .asFunction<_MaxedDart>();
final _sudokuByteSize = _lib
    .lookup<NativeFunction<_ByteSizeNative>>('sudoku_puzzle_byte_size')
    .asFunction<_ByteSizeDart>();
final _sudokuGetBytes = _lib
    .lookup<NativeFunction<_GetBytesNative>>('sudoku_get_puzzle_bytes')
    .asFunction<_GetBytesDart>();
final _sudokuSetBytes = _lib
    .lookup<NativeFunction<_SetBytesNative>>('sudoku_set_puzzle_bytes')
    .asFunction<_SetBytesDart>();
final _sudokuSetupLoaded = _lib
    .lookup<NativeFunction<_SetupLoadedNative>>('sudoku_setup_loaded')
    .asFunction<_SetupLoadedDart>();
final _sudokuRestart = _lib
    .lookup<NativeFunction<_RestartNative>>('sudoku_restart')
    .asFunction<_RestartDart>();

// Cache byte size once
final int _puzzleByteSize = _sudokuByteSize();

// ---------------------------------------------------------------------------
// Public Dart-friendly wrapper
// ---------------------------------------------------------------------------

/// Set the directory containing the group map .z files (rot_*.z, mir_*.z).
/// Call once at app startup before generating any irregular puzzles.
void setGroupMapsDir(String path) {
  final ptr = path.toNativeUtf8();
  try {
    _sudokuSetGroupMapsDir(ptr);
  } finally {
    calloc.free(ptr);
  }
}

/// Low-level wrapper around the native Puzzle handle.
/// Higher-level game logic (undo/redo, state management) lives in PuzzleEngine.
class PuzzleFFI {
  final Pointer<Void> _handle;
  bool _disposed = false;

  PuzzleFFI() : _handle = _sudokuNew();

  void dispose() {
    if (!_disposed) {
      _sudokuFree(_handle);
      _disposed = true;
    }
  }

  /// Generate a new puzzle.  Blocking — run inside a Dart isolate.
  /// Returns true on success.
  bool generate({
    SudokuMapType mapType = SudokuMapType.square,
    SudokuAdjType adjType = SudokuAdjType.normal,
    SudokuDifficulty difficulty = SudokuDifficulty.medium,
    SudokuQuality quality = SudokuQuality.compromise,
  }) {
    return _sudokuGenerate(
          _handle, mapType.value, adjType.value,
          difficulty.value, quality.value) == 1;
  }

  void cancel() => _sudokuCancel(_handle);

  CellData getCell(int offset) {
    final ptr = calloc<_SudokuCellNative>();
    try {
      _sudokuGetCell(_handle, offset, ptr);
      final c = ptr.ref;
      return CellData(
        solution:  c.solution,
        mask:      c.mask,
        elimBits:  c.elim_bits,
        userAnswer:c.user_answer,
        smallMode: c.display_small_digits != 0,
        marker:    c.display_marker,
        group:     c.group,
        row:       c.row,
        col:       c.col,
      );
    } finally {
      calloc.free(ptr);
    }
  }

  List<int> getColorMap() {
    final ptr = calloc<Int32>(9);
    try {
      _sudokuGetColorMap(_handle, ptr);
      return List.generate(9, (i) => ptr[i]);
    } finally {
      calloc.free(ptr);
    }
  }

  bool sameGroupRight(int offset) => _sudokuSameGroupRight(_handle, offset) == 1;
  bool sameGroupBelow(int offset) => _sudokuSameGroupBelow(_handle, offset) == 1;
  bool areNeighbors(int o1, int o2) => _sudokuAreNeighbors(_handle, o1, o2) == 1;

  void setUserAnswer(int offset, int digit, int oldDigit, {bool digitAssistant = false}) {
    _sudokuSetUserAnswer(_handle, offset, digit, oldDigit, digitAssistant ? 1 : 0);
  }

  void toggleElimBit(int offset, int digit) =>
      _sudokuToggleElimBit(_handle, offset, digit);

  bool toggleSmallMode(int offset) =>
      _sudokuToggleSmallMode(_handle, offset) != 0;

  void digitAssistantAll() => _sudokuDaAll(_handle);

  SudokuPuzzleState getState({List<int>? digitCountsOut}) {
    final ptr = calloc<Int32>(10);
    try {
      final raw = _sudokuGetState(_handle, ptr);
      if (digitCountsOut != null) {
        for (int i = 0; i < 10; i++) digitCountsOut[i] = ptr[i];
      }
      return SudokuPuzzleState.values[raw];
    } finally {
      calloc.free(ptr);
    }
  }

  int distance() => _sudokuDistance(_handle);

  List<bool> maxedDigits() {
    final ptr = calloc<Int32>(10);
    try {
      _sudokuMaxedDigits(_handle, ptr);
      return List.generate(10, (i) => ptr[i] != 0);
    } finally {
      calloc.free(ptr);
    }
  }

  /// Snapshot the raw PUZZLE bytes for undo.
  Uint8List snapshotBytes() {
    final ptr = calloc<Uint8>(_puzzleByteSize);
    try {
      _sudokuGetBytes(_handle, ptr);
      final result = Uint8List(_puzzleByteSize);
      for (int i = 0; i < _puzzleByteSize; i++) result[i] = ptr[i];
      return result;
    } finally {
      calloc.free(ptr);
    }
  }

  /// Restore PUZZLE bytes from an undo snapshot.
  void restoreBytes(Uint8List bytes) {
    assert(bytes.length == _puzzleByteSize);
    final ptr = calloc<Uint8>(_puzzleByteSize);
    try {
      for (int i = 0; i < _puzzleByteSize; i++) ptr[i] = bytes[i];
      _sudokuSetBytes(_handle, ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  /// After restoreBytes(), call this to set adjacency type and rebuild the
  /// are_neighbors_array needed for cell-highlight queries.
  void setupLoaded(SudokuMapType mapType, SudokuAdjType adjType) {
    _sudokuSetupLoaded(_handle, mapType.value, adjType.value);
  }

  void restart() => _sudokuRestart(_handle);
}
