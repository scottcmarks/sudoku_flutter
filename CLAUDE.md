# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # Install dependencies
flutter analyze          # Lint
flutter test             # Run tests
flutter run -d macos     # Run on macOS desktop
flutter run              # Run on connected iOS device
flutter test test/widget_test.dart  # Run a single test file
```

## Architecture

This is a **Sudoku X4** puzzle game (multiple map types: square, irregular; difficulties: Quickie → Ultimate). The puzzle-solving engine is written in C++ and called via dart:ffi.

### State management

Two `ChangeNotifierProvider`s at the root:

- **`PuzzleEngine`** (`lib/puzzle/puzzle_engine.dart`) — all in-game state: cell selection, digit entry, undo/redo (snapshot-based in Dart), markers. Delegates to the C++ engine via `PuzzleFFI`.
- **`SavedGameStore`** (`lib/models/saved_game.dart`) — the album (saved games gallery). Persists `.sx4json` files to `~/Documents/SudokuX4Games/`.

### FFI bridge

`lib/puzzle/puzzle_ffi.dart` loads the C++ engine:
- **iOS/macOS**: `DynamicLibrary.process()` — engine compiled directly into the app binary
- **Android/Linux**: `libsudoku_engine.so`
- **Windows**: `sudoku_engine.dll`

The native sources live in `native/` and depend on two sibling repos:
- `~/SudokuX4/PlatformIndependent/Game/` — puzzle solver
- `~/Toolbox/PlatformIndependent/` — utilities (rand, zip, filenames)

### iOS/macOS build

The C++ sources must be manually added to Xcode's **Compile Sources** build phase — see `native/XCODE_SETUP.md` for the exact file list, header search paths, and C++17 setting. Flutter's normal build does not compile native/ automatically on Apple platforms.

Key pitfall: do **not** add any ConsoleGroups `.c` files — they define a conflicting `SYMMETRY` enum.

### Screen flow

`AlbumScreen` (home) → tap saved game or FAB → `NewGameDialog` (configure) or `GameScreen` (play). `GameScreen` composes `PuzzleGrid` + `KeypadWidget` + `ToolbarWidget`.

### Data types

`lib/puzzle/puzzle_types.dart` defines Dart enums that mirror the C engine's integer values (`SudokuMapType`, `SudokuDifficulty`, `SudokuAdjType`, `SudokuQuality`, `SudokuMarker`, `CellData`). Keep these in sync with the C++ side when changing.
