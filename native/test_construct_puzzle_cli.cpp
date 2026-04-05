// test_cli.cpp — standalone CLI jig for debugging sudoku_generate
//
// Builds with native/Makefile.  Does NOT use Flutter or Dart.
// Usage:  ./test_cli [map_type adj_type difficulty quality]
//   map_type:   0=square 1=irregular   (default 0)
//   adj_type:   0=normal 1=x           (default 0)
//   difficulty: 0=quickie .. 5=ultimate (default 0)
//   quality:    0=asap 1=compromise 2=best (default 1)

#include "sudoku_ffi.h"
#include <cstdio>
#include <cstdlib>

int main(int argc, char* argv[]) {
    int map  = (argc > 1) ? atoi(argv[1]) : SUDOKU_MAP_SQUARE;
    int adj  = (argc > 2) ? atoi(argv[2]) : SUDOKU_ADJ_NORMAL;
    int diff = (argc > 3) ? atoi(argv[3]) : SUDOKU_DIFF_QUICKIE;
    int qual = (argc > 4) ? atoi(argv[4]) : SUDOKU_QUALITY_COMPROMISE;

    fprintf(stderr, "test_cli: map=%d adj=%d diff=%d qual=%d\n",
            map, adj, diff, qual);

    void* h = sudoku_new();
    fprintf(stderr, "test_cli: handle=%p\n", h);

    int ok = sudoku_generate(h,
        (SudokuMapType)map, (SudokuAdjType)adj,
        (SudokuDifficulty)diff, (SudokuQuality)qual);

    if (!ok) {
        fprintf(stderr, "test_cli: generation FAILED\n");
        sudoku_free(h);
        return 1;
    }

    fprintf(stderr, "test_cli: generation succeeded\n");

    // Print the grid: clue cells show digit, blanks show '.'
    SudokuCell cell;
    for (int row = 0; row < 9; row++) {
        for (int col = 0; col < 9; col++) {
            sudoku_get_cell(h, row * 9 + col, &cell);
            if (cell.mask)
                fprintf(stdout, "%d", cell.solution);
            else
                fprintf(stdout, ".");
            if (col == 2 || col == 5) fprintf(stdout, "|");
        }
        fprintf(stdout, "\n");
        if (row == 2 || row == 5) fprintf(stdout, "---+---+---\n");
    }

    int dist = sudoku_distance(h);
    fprintf(stderr, "test_cli: distance=%d (cells to fill)\n", dist);

    sudoku_free(h);
    return 0;
}
