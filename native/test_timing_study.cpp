// test_timing_study.cpp — generation time for all puzzle types × difficulties
//
// Usage: SUDOKU_GROUP_MAPS_DIR=... ./test_timing_study
// Stderr: engine diagnostics (redirect to /dev/null for clean output)
// Stdout: timing table + puzzle grid for each successful run
//
// Each puzzle generation is limited to TIMEOUT_SECS seconds.
// If the engine doesn't finish in time, sudoku_cancel() is called and
// "*** TIMED OUT ***" is printed instead of the puzzle grid.
//
// arc4random_uniform() is replaced with a seedable rand()-based version so
// each run's seed can be recorded (and later used to reproduce the result).

#include "sudoku_ffi.h"
#include "print_puzzle.h"
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <cstdint>
#include <future>

// ---------------------------------------------------------------------------
// Seedable arc4random_uniform replacement
// ---------------------------------------------------------------------------

static void set_seed(uint32_t seed) { srand(seed); }

extern "C" uint32_t arc4random_uniform(uint32_t upper_bound) {
    if (upper_bound == 0) return 0;
    return (uint32_t)((unsigned long long)(unsigned int)rand() * upper_bound
                      / ((unsigned long long)RAND_MAX + 1));
}

// ---------------------------------------------------------------------------

static const int N_RUNS    = 5;
static const int TIMEOUT_SECS = 1200;

int main() {
    const char *diff_labels[] = {
        "Quickie", "Easy", "Medium", "Hard", "Expert", "Ultimate"
    };
    const int n_diff = 6;

    struct Type { int map; int adj; const char *name; } types[] = {
        { SUDOKU_MAP_SQUARE,    SUDOKU_ADJ_NORMAL, "Regular    " },
        { SUDOKU_MAP_SQUARE,    SUDOKU_ADJ_X,      "Regular X  " },
        { SUDOKU_MAP_IRREGULAR, SUDOKU_ADJ_NORMAL, "Irregular  " },
        { SUDOKU_MAP_IRREGULAR, SUDOKU_ADJ_X,      "Irregular X" },
    };
    const int n_types = 4;

    printf("%-10s  %-13s  %3s  %10s  %10s\n",
           "Difficulty", "Type", "Run", "Seed", "Time");
    printf("----------  -------------  ---  ----------  ----------\n");
    fflush(stdout);

    for (int d = 0; d < n_diff; d++) {
        for (int t = 0; t < n_types; t++) {
            for (int r = 0; r < N_RUNS; r++) {
                uint32_t seed = (uint32_t)(
                    std::chrono::steady_clock::now().time_since_epoch().count()
                    & 0xFFFFFFFF);
                set_seed(seed);

                void* h = sudoku_new();
                bool timed_out = false;
                int ok = 0;

                auto t0 = std::chrono::steady_clock::now();

                // Run generation on a background thread so we can time it out.
                auto fut = std::async(std::launch::async, [&]() {
                    return sudoku_generate(h,
                        (SudokuMapType)types[t].map,
                        (SudokuAdjType)types[t].adj,
                        (SudokuDifficulty)d,
                        (SudokuQuality)SUDOKU_QUALITY_COMPROMISE);
                });

                auto status = fut.wait_for(std::chrono::seconds(TIMEOUT_SECS));
                if (status == std::future_status::timeout) {
                    timed_out = true;
                    sudoku_cancel(h);   // signal engine to stop
                    fut.wait();         // wait for thread to exit cleanly
                } else {
                    ok = fut.get();
                }

                auto t1 = std::chrono::steady_clock::now();
                int ms = (int)std::chrono::duration_cast<std::chrono::milliseconds>(
                             t1 - t0).count();

                if (timed_out) {
                    printf("%-10s  %-13s  %3d  %10u  %7dms  *** TIMED OUT ***\n",
                           diff_labels[d], types[t].name, r + 1, seed, ms);
                } else if (ok) {
                    printf("%-10s  %-13s  %3d  %10u  %7dms\n",
                           diff_labels[d], types[t].name, r + 1, seed, ms);
                    print_puzzle(h, types[t].adj == SUDOKU_ADJ_X);
                } else {
                    printf("%-10s  %-13s  %3d  %10u  %7dms  FAILED\n",
                           diff_labels[d], types[t].name, r + 1, seed, ms);
                }
                fflush(stdout);

                sudoku_free(h);
                printf("\n");
                fflush(stdout);
            }
        }
        printf("\n");
        fflush(stdout);
    }

    return 0;
}
