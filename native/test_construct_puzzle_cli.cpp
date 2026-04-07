// test_construct_puzzle_cli.cpp — standalone CLI jig for debugging sudoku_generate
//
// Builds with native/Makefile.  Does NOT use Flutter or Dart.
// Usage:  ./test_construct_puzzle_cli [map_type adj_type difficulty quality]
//   map_type:   0=square 1=irregular   (default 0)
//   adj_type:   0=normal 1=x           (default 0)
//   difficulty: 0=quickie .. 5=ultimate (default 0)
//   quality:    0=asap 1=compromise 2=best (default 1)

#include "sudoku_ffi.h"
#include "print_puzzle.h"
#include <cstdio>
#include <cstdlib>

int main(int argc, char* argv[]) {
    int map  = (argc > 1) ? atoi(argv[1]) : SUDOKU_MAP_SQUARE;
    int adj  = (argc > 2) ? atoi(argv[2]) : SUDOKU_ADJ_NORMAL;
    int diff = (argc > 3) ? atoi(argv[3]) : SUDOKU_DIFF_QUICKIE;
    int qual = (argc > 4) ? atoi(argv[4]) : SUDOKU_QUALITY_COMPROMISE;

    fprintf(stderr, "test_construct_puzzle_cli: map=%d adj=%d diff=%d qual=%d\n",
            map, adj, diff, qual);

    void* h = sudoku_new();
    int ok = sudoku_generate(h,
        (SudokuMapType)map, (SudokuAdjType)adj,
        (SudokuDifficulty)diff, (SudokuQuality)qual);

    if (!ok) {
        fprintf(stderr, "test_construct_puzzle_cli: generation FAILED\n");
        sudoku_free(h);
        return 1;
    }

    fprintf(stderr, "test_construct_puzzle_cli: generation succeeded, distance=%d\n",
            sudoku_distance(h));

    print_puzzle(h, adj == SUDOKU_ADJ_X);

    sudoku_free(h);
    return 0;
}
