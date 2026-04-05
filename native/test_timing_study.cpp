// test_timing_study.cpp — generation time for all puzzle types × difficulties
//
// Usage: SUDOKU_GROUP_MAPS_DIR=... ./test_timing_study
// Stderr: engine diagnostics (redirect to /dev/null for clean output)
// Stdout: timing table

#include "sudoku_ffi.h"
#include <chrono>
#include <cstdio>

int main() {
    const char *diff_labels[] = { "Quickie", "Easy", "Medium", "Hard", "Expert", "Ultimate" };
    const int n_diff = 6;

    struct Type { int map; int adj; const char *name; } types[] = {
        { SUDOKU_MAP_SQUARE,    SUDOKU_ADJ_NORMAL, "Regular    " },
        { SUDOKU_MAP_SQUARE,    SUDOKU_ADJ_X,      "Regular X  " },
        { SUDOKU_MAP_IRREGULAR, SUDOKU_ADJ_NORMAL, "Irregular  " },
        { SUDOKU_MAP_IRREGULAR, SUDOKU_ADJ_X,      "Irregular X" },
    };
    const int n_types = 4;

    // Header
    printf("%-10s  %-13s  %10s\n", "Difficulty", "Type", "Time");
    printf("----------  -------------  ----------\n");
    fflush(stdout);

    for (int d = 0; d < n_diff; d++) {
        for (int t = 0; t < n_types; t++) {
            void *h = sudoku_new();
            auto t0 = std::chrono::steady_clock::now();
            int ok = sudoku_generate(h,
                (SudokuMapType)types[t].map,
                (SudokuAdjType)types[t].adj,
                (SudokuDifficulty)d,
                (SudokuQuality)SUDOKU_QUALITY_COMPROMISE);
            auto t1 = std::chrono::steady_clock::now();
            sudoku_free(h);
            int ms = (int)std::chrono::duration_cast<std::chrono::milliseconds>(t1 - t0).count();
            if (ok) printf("%-10s  %-13s  %7dms\n", diff_labels[d], types[t].name, ms);
            else    printf("%-10s  %-13s  FAILED\n",  diff_labels[d], types[t].name);
            fflush(stdout);
        }
        printf("\n");
        fflush(stdout);
    }

    return 0;
}
