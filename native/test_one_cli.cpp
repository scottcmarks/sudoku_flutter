// test_one_cli.cpp — generate a single puzzle with explicit seed
//
// Usage: ./test_one_cli <difficulty> <type> <seed>
//   difficulty : Quickie | Easy | Medium | Hard | Expert | Ultimate  (or 0-5)
//   type       : Regular | "Regular X" | Irregular | "Irregular X"
//   seed       : uint32 seed value (from a prior timing study output)
//
// Example:
//   ./test_one_cli Easy Regular 2347620152
//   ./test_one_cli Hard "Irregular X" 987654321

#include "sudoku_ffi.h"
#include "print_puzzle.h"
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <cstring>
#include <cctype>

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
// Argument parsing helpers
// ---------------------------------------------------------------------------

static void to_lower(char* s) {
    for (; *s; s++) *s = (char)tolower((unsigned char)*s);
}

static int parse_difficulty(const char* s) {
    char buf[32];
    snprintf(buf, sizeof(buf), "%s", s);
    to_lower(buf);
    if (strcmp(buf, "quickie") == 0 || strcmp(buf, "0") == 0) return 0;
    if (strcmp(buf, "easy")    == 0 || strcmp(buf, "1") == 0) return 1;
    if (strcmp(buf, "medium")  == 0 || strcmp(buf, "2") == 0) return 2;
    if (strcmp(buf, "hard")    == 0 || strcmp(buf, "3") == 0) return 3;
    if (strcmp(buf, "expert")  == 0 || strcmp(buf, "4") == 0) return 4;
    if (strcmp(buf, "ultimate")== 0 || strcmp(buf, "5") == 0) return 5;
    return -1;
}

// Returns map type and adj type via out-params.  Returns false on failure.
static bool parse_type(const char* s, int* map, int* adj) {
    char buf[32];
    snprintf(buf, sizeof(buf), "%s", s);
    to_lower(buf);
    // strip spaces
    char clean[32]; int ci = 0;
    for (int i = 0; buf[i]; i++)
        if (buf[i] != ' ') clean[ci++] = buf[i];
    clean[ci] = '\0';

    if (strcmp(clean, "regular")    == 0) { *map=0; *adj=0; return true; }
    if (strcmp(clean, "regularx")   == 0) { *map=0; *adj=1; return true; }
    if (strcmp(clean, "irregular")  == 0) { *map=1; *adj=0; return true; }
    if (strcmp(clean, "irregularx") == 0) { *map=1; *adj=1; return true; }
    return false;
}

static void usage(const char* prog) {
    fprintf(stderr,
        "Usage: %s <difficulty> <type> <seed>\n"
        "  difficulty : Quickie|Easy|Medium|Hard|Expert|Ultimate  (or 0-5)\n"
        "  type       : Regular | \"Regular X\" | Irregular | \"Irregular X\"\n"
        "  seed       : uint32 seed (e.g. from timing study output)\n"
        "Example: %s Easy Regular 2347620152\n",
        prog, prog);
}

// ---------------------------------------------------------------------------

int main(int argc, char* argv[]) {
    if (argc != 4) { usage(argv[0]); return 1; }

    int diff = parse_difficulty(argv[1]);
    if (diff < 0) {
        fprintf(stderr, "Unknown difficulty: %s\n", argv[1]);
        usage(argv[0]); return 1;
    }

    int map, adj;
    if (!parse_type(argv[2], &map, &adj)) {
        fprintf(stderr, "Unknown type: %s\n", argv[2]);
        usage(argv[0]); return 1;
    }

    uint32_t seed = (uint32_t)strtoul(argv[3], nullptr, 10);

    const char* diff_names[] = { "Quickie","Easy","Medium","Hard","Expert","Ultimate" };
    const char* type_names[] = { "Regular", "Regular X", "Irregular", "Irregular X" };
    int type_idx = map * 2 + adj;

    fprintf(stderr, "Generating: %s %s seed=%u\n",
            diff_names[diff], type_names[type_idx], seed);

    set_seed(seed);

    void* h = sudoku_new();
    auto t0 = std::chrono::steady_clock::now();
    int ok = sudoku_generate(h,
        (SudokuMapType)map,
        (SudokuAdjType)adj,
        (SudokuDifficulty)diff,
        (SudokuQuality)SUDOKU_QUALITY_COMPROMISE);
    auto t1 = std::chrono::steady_clock::now();
    int ms = (int)std::chrono::duration_cast<std::chrono::milliseconds>(t1-t0).count();

    if (!ok) {
        printf("%-10s  %-13s  seed=%u  %dms  FAILED\n",
               diff_names[diff], type_names[type_idx], seed, ms);
        fprintf(stderr, "Generation FAILED after %dms\n", ms);
        sudoku_free(h);
        return 1;
    }

    printf("%-10s  %-13s  seed=%u  %dms\n",
           diff_names[diff], type_names[type_idx], seed, ms);
    print_puzzle(h, adj == SUDOKU_ADJ_X);

    fprintf(stderr, "Done: distance=%d, %dms\n", sudoku_distance(h), ms);

    sudoku_free(h);
    return 0;
}
