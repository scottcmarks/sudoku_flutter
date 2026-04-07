# Change Log

## 2026-04-07

### CLI tools — test_one_cli, FAILED timing, bug fixes, documentation

- **`native/test_one_cli.cpp`** — New single-puzzle CLI: `./test_one_cli <difficulty> <type> <seed>`.
  Same seedable RNG shadow as timing study. Prints elapsed time + grid on success;
  prints `seed=X Yms FAILED` to stdout (plus stderr message) on failure.
  Run with `MallocNanoZone=0 SUDOKU_GROUP_MAPS_DIR=... ./test_one_cli Easy Regular 2347620152`.

- **`native/test_timing_study.cpp`** — FAILED lines now include elapsed time (`%7dms  FAILED`).
  Previously timing was omitted, making it impossible to know how long a failed generation ran.

- **`native/sudoku_ffi.cpp`** — Bug fix: `if (result == 0)` → `if (result <= 0)`.
  `make_puzzle()` never returns 0; it returns -3 (all iterations produced rating=0, puzzle has too
  many clues) or -4 (cancelled with insufficient result) on failure. The `== 0` check let both
  failure codes slip through to `make_ready_for_UI()`, potentially queuing an over-clued puzzle
  that looks like the requested difficulty but is actually easier.

- **`native/Makefile`** — Added `test_one_cli` target; added `-MMD -MP` for header dependency
  tracking (`.d` files); added `print_puzzle.h` as explicit dep of `timing` target; removed
  `2>/dev/null` from timing run line so tracing appears.

- **`PUZZLE_GENERATION.md`** — New documentation file at project root. Describes all five nested
  generation levels (construct_solution recursive fill → make_puzzle 100-iteration loop →
  make_solvable_puzzle while-loop → remove_clues iteration → solve/brute_force recursive DFS),
  group map selection, Quickie Irregular variance explanation, and all solving techniques
  (ELIMINATION through BRUTE_FORCE) with plain-English descriptions.

- **`~/SudokuX4/PlatformIndependent/Game/GroupMap.cc`** *(Game repo)* — Added stderr tracing:
  `GroupMap: file=mir03 mapNumber=4721/10000`.

- **`~/SudokuX4/PlatformIndependent/Game/Puzzle_clues.cpp`** *(Game repo)* — Added stderr tracing:
  `make_puzzle: itries=97/100 rating=42 nclues=33`.

## 2026-04-06

### CLI tools — grid renderer, seedable RNG, timeout

- **`native/print_puzzle.h`** — New shared header-only Unicode box-drawing renderer.
  `print_puzzle(void* h, bool is_x)` draws group boundaries as heavy lines and
  intra-group borders as light lines; works for both regular and irregular puzzles.
  For X-sudoku, marks the 8 interior diagonal corner intersections with `'X'`.
  Full `pp_box_char()` lookup handles all mixed heavy/light Unicode box-drawing combinations.

- **`native/test_construct_puzzle_cli.cpp`** — Replaced ad-hoc grid loop with `print_puzzle()`.

- **`native/test_irregular_cli.cpp`** — Replaced side-by-side group/digit text output with `print_puzzle()`.

- **`native/test_timing_study.cpp`** — Three improvements:
  1. **Seedable RNG**: `arc4random_uniform()` shadowed with `rand()`-based wrapper;
     each run seeded from `steady_clock::now() & 0xFFFFFFFF` (nanosecond resolution);
     seed recorded in output for potential reproduction.
  2. **Per-puzzle timeout**: 1200 seconds via `std::async` + `sudoku_cancel()`;
     timed-out entries print `*** TIMED OUT ***` instead of a grid.
  3. **Grid output**: each successful generation prints the puzzle grid below its timing line.

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
