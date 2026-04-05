# Change Log

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
