// puzzle_queue_entry.dart — one ready-to-play puzzle in a queue slot
//
// Mirrors PuzzleData from the C++ engine:
//   puzzleBytes  = sizeof(PUZZLE) = 9×9 × sizeof(PUZZLE_CELL) bytes
//   colorMap     = iColorMap[9]
//   mapType/adjType/difficulty = generation parameters

import 'dart:convert';
import 'dart:typed_data';

import '../puzzle/puzzle_types.dart';

class PuzzleQueueEntry {
  final Uint8List      puzzleBytes;
  final List<int>      colorMap;
  final SudokuMapType  mapType;
  final SudokuAdjType  adjType;
  final SudokuDifficulty difficulty;

  const PuzzleQueueEntry({
    required this.puzzleBytes,
    required this.colorMap,
    required this.mapType,
    required this.adjType,
    required this.difficulty,
  });

  Map<String, dynamic> toJson() => {
    'puzzleBytes': base64Encode(puzzleBytes),
    'colorMap':    colorMap,
    'mapType':     mapType.value,
    'adjType':     adjType.value,
    'difficulty':  difficulty.value,
  };

  static PuzzleQueueEntry fromJson(Map<String, dynamic> j) {
    final mapRaw  = j['mapType']    as int;
    final adjRaw  = j['adjType']    as int;
    final diffRaw = j['difficulty'] as int;
    return PuzzleQueueEntry(
      puzzleBytes: base64Decode(j['puzzleBytes'] as String),
      colorMap:    List<int>.from(j['colorMap'] as List),
      mapType:     SudokuMapType.values[mapRaw.clamp(0, 1)],
      adjType:     SudokuAdjType.values[adjRaw.clamp(0, 1)],
      difficulty:  SudokuDifficulty.values[diffRaw.clamp(0, 5)],
    );
  }
}
