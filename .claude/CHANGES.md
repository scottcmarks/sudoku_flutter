# Change Log

## 2026-04-05

### Native / Irregular puzzle support

- **`native/Filenames_cli.cpp`** — New CLI implementation of `get_full_filename` / `set_group_maps_dir`. Reads `SUDOKU_GROUP_MAPS_DIR` env var. Replaces Toolbox `Filenames.cpp` in CLI builds.
- **`native/Filenames_impl.mm`** — Added no-op `set_group_maps_dir` stub for linker. NSBundle continues to handle path resolution.
- **`native/sudoku_ffi.h/cpp`** — Added `sudoku_set_group_maps_dir()` FFI entry point.
- **`native/XCODE_SETUP.md`** — Corrected: do NOT add `Filenames.cpp`; use `Filenames_impl.mm` instead.
- **`native/Makefile`** — Added `test_irregular_cli` and `test_timing_study` targets; switched to `Filenames_cli.o`; added `timing` target (builds with -O3, no ASan).

### Dart / FFI

- **`lib/puzzle/puzzle_ffi.dart`** — Bound `sudoku_set_group_maps_dir`; exposed `setGroupMapsDir()`.
- **`lib/main.dart`** — Calls `setGroupMapsDir` from `SUDOKU_GROUP_MAPS_DIR` env var at startup.

### UI / Cell rendering

- **`lib/theme/app_theme.dart`** — Group color palette changed to distinct blue/green/pink/tan (was near-identical creams).
- **`lib/widgets/cell_widget.dart`** — Group-color backgrounds for all cells; italic user digits; checkerboard pattern when in small-mode with no candidates.
- **`lib/widgets/puzzle_grid.dart`** — X diagonal overlay (`_XDiagonalPainter`) for xSudoku games; strokeWidth = gridSize/(3√2), semi-transparent warm gold.

### CLI tools

- **`native/test_irregular_cli.cpp`** — New CLI jig for irregular puzzle generation; prints group map + puzzle side by side.
- **`native/test_timing_study.cpp`** — Generation timing study: all 4 types × 6 difficulties, difficulty-outer loop, per-cell fflush for live output. Overnight run pending.

## 2026-04-04

### Native / FFI bug fixes

- **`native/sudoku_ffi.cpp`** — Fixed stack buffer overflow in `sudoku_maxed_digits`.
  `P(handle)->maxed_digits(bools + 1)` wrote index 9 to `bools[10]` (one past end of 10-element array).
  Changed to `P(handle)->maxed_digits(bools)`; engine fills `bools[1..9]`, `bools[0]` stays 0.
  This was the second native crash (SIGABRT "stack buffer overflow") when opening `GameScreen`.

- **`~/Toolbox/PlatformIndependent/rand_utils.h`** *(Toolbox repo — not committed here)*
  Fixed `rand_int_less_than`: `(int)arc4random() % n` → `(int)arc4random_uniform(n)`.
  `arc4random()` high bit can be set, making the cast negative, then `% n` negative → `comb[-1]` underflow → SIGSEGV in `construct_solution`. Not yet committed to Toolbox repo.

### Native test jig

- **`native/test_construct_puzzle_cli.cpp`** + **`native/Makefile`** — CLI jig for testing puzzle generation outside Flutter. Uses `-fsanitize=address`. Build: `make -C native/`; run: `./native/test_construct_puzzle_cli [map adj diff qual]`.
