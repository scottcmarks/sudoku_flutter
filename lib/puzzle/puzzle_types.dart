// puzzle_types.dart — Dart mirrors of the C engine enums + data classes

enum SudokuMapType {
  square(0),
  irregular(1);

  const SudokuMapType(this.value);
  final int value;
}

enum SudokuAdjType {
  normal(0),
  xSudoku(1);

  const SudokuAdjType(this.value);
  final int value;
}

enum SudokuDifficulty {
  quickie(0,    'Quickie'),
  easy(1,       'Easy'),
  medium(2,     'Medium'),
  hard(3,       'Hard'),
  expert(4,     'Expert'),
  ultimate(5,   'Ultimate');

  const SudokuDifficulty(this.value, this.label);
  final int value;
  final String label;
}

enum SudokuQuality {
  asap(0),
  compromise(1),
  best(2);

  const SudokuQuality(this.value);
  final int value;
}

enum SudokuPuzzleState { unfinished, correct, incorrect }

enum SudokuMarker {
  pen(0),
  marker1(1),
  marker2(2),
  pencil(3);

  const SudokuMarker(this.value);
  final int value;
}

/// Snapshot of one cell's UI state, decoded from the C struct.
class CellData {
  final int solution;        // 1-9
  final int mask;            // 1 = given clue
  final int elimBits;        // bit N set → digit N is a pencil candidate
  final int userAnswer;      // 1-9 or 0
  final bool smallMode;      // pencil-marks display mode
  final int marker;          // SudokuMarker.value
  final int group;           // 0-8
  final int row;             // 0-8
  final int col;             // 0-8

  const CellData({
    required this.solution,
    required this.mask,
    required this.elimBits,
    required this.userAnswer,
    required this.smallMode,
    required this.marker,
    required this.group,
    required this.row,
    required this.col,
  });

  bool get isClue => mask == 1;
  bool get isEmpty => userAnswer == 0 && !smallMode;

  /// Whether a given digit (1-9) is marked as candidate in small-digit mode.
  bool hasCandidate(int digit) => (elimBits & (1 << digit)) != 0;
}
