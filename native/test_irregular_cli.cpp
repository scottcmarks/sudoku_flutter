// test_irregular_cli.cpp — CLI jig for debugging irregular sudoku generation
//
// Builds with native/Makefile.  Does NOT use Flutter or Dart.
// Usage:  ./test_irregular_cli [adj_type difficulty quality]
//   adj_type:   0=normal 1=x           (default 0)
//   difficulty: 0=quickie .. 5=ultimate (default 0)
//   quality:    0=asap 1=compromise 2=best (default 1)

#include "sudoku_ffi.h"
#include "print_puzzle.h"
#include <cstdio>
#include <cstdlib>

int main(int argc, char* argv[]) {
    int adj  = (argc > 1) ? atoi(argv[1]) : SUDOKU_ADJ_NORMAL;
    int diff = (argc > 2) ? atoi(argv[2]) : SUDOKU_DIFF_QUICKIE;
    int qual = (argc > 3) ? atoi(argv[3]) : SUDOKU_QUALITY_COMPROMISE;

    fprintf(stderr, "test_irregular_cli: map=IRREGULAR adj=%d diff=%d qual=%d\n",
            adj, diff, qual);

    void* h = sudoku_new();
    int ok = sudoku_generate(h,
        (SudokuMapType)SUDOKU_MAP_IRREGULAR, (SudokuAdjType)adj,
        (SudokuDifficulty)diff, (SudokuQuality)qual);

    if (!ok) {
        fprintf(stderr, "test_irregular_cli: generation FAILED\n");
        sudoku_free(h);
        return 1;
    }

    fprintf(stderr, "test_irregular_cli: generation succeeded, distance=%d\n",
            sudoku_distance(h));

    print_puzzle(h, adj == SUDOKU_ADJ_X);

    sudoku_free(h);
    return 0;
}
