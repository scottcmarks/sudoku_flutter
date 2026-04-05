// sudoku_ffi.cpp — implements the C API declared in sudoku_ffi.h
//
// Build notes:
//   • Include this file together with the SudokuX4 PlatformIndependent sources.
//   • Set the include path to point at SudokuX4/PlatformIndependent/Game/
//     and SudokuX4/PlatformIndependent/ConsoleGroups/.
//   • Compile as C++17 (or C++14 minimum).

#include "sudoku_ffi.h"

// ---- SudokuX4 engine headers ----
// Adjust SUDOKU_ENGINE_PATH at build time, or set include paths via CMake/Xcode.
#include "Puzzle.h"
#include "GroupMap.h"
#include "Filenames.h"

#include <cstring>
#include <cassert>

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

static inline Puzzle* P(void* h) { return static_cast<Puzzle*>(h); }

// Map our public enum → engine enum
static MAP_TYPE to_map_type(SudokuMapType t) {
    return (t == SUDOKU_MAP_IRREGULAR) ? IRREGULAR_GROUPS : SQUARE_GROUPS;
}
static ADJACENCY_TYPE to_adj_type(SudokuAdjType t) {
    return (t == SUDOKU_ADJ_X) ? X_SUDOKU : SUDOKU;
}
static UI_DIFFICULTY to_difficulty(SudokuDifficulty d) {
    // enum values happen to match 1:1
    return static_cast<UI_DIFFICULTY>(d);
}
static UI_QUALITY to_quality(SudokuQuality q) {
    return static_cast<UI_QUALITY>(q);
}

// ---------------------------------------------------------------------------
// Global initialisation
// ---------------------------------------------------------------------------

void sudoku_set_group_maps_dir(const char* path) {
    set_group_maps_dir(path);
}

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

void* sudoku_new(void) {
    Puzzle* p = new Puzzle();
    p->cancelPuzzle   = false;
    p->cancelSolution = false;
    p->cancelAfter5Min = false;
    p->yieldTicked    = false;
    return p;
}

void sudoku_free(void* handle) {
    delete P(handle);
}

// ---------------------------------------------------------------------------
// Generation
// ---------------------------------------------------------------------------

int sudoku_generate(void*          handle,
                    SudokuMapType  mapType,
                    SudokuAdjType  adjType,
                    SudokuDifficulty difficulty,
                    SudokuQuality  quality)
{
    Puzzle* p = P(handle);
    p->cancelPuzzle   = false;
    p->cancelSolution = false;

    // 1. Build group map (random for irregular, standard for square)
    MAP_TYPE mt = to_map_type(mapType);
    ADJACENCY_TYPE at = to_adj_type(adjType);

    fprintf(stderr, "sudoku_generate: building GroupMap mt=%d\n", (int)mt);
    GroupMap gm(mt);
    fprintf(stderr, "sudoku_generate: set_types\n");
    p->set_types(mt, at);
    p->set_difficulty(to_difficulty(difficulty));

    fprintf(stderr, "sudoku_generate: setup\n");
    p->setup(gm.iMap);
    p->set_color_map(gm.iColorMap);
    p->define_are_neighbors_array();
    p->setup_ptrs_first_in_dims();

    // Diagnostic: verify are_neighbors works
    {
        const PUZZLE_CELL& c00 = p->cell(0);  // puzzle[0][0]
        const PUZZLE_CELL& c01 = p->cell(1);  // puzzle[0][1] — same row, same group
        const PUZZLE_CELL& c09 = p->cell(9);  // puzzle[1][0] — same group
        const PUZZLE_CELL& c03 = p->cell(3);  // puzzle[0][3] — same row only
        const PUZZLE_CELL& c27 = p->cell(27); // puzzle[3][0] — same col only
        fprintf(stderr, "c00: row=%d col=%d grp=%d offset=%d\n",
                c00.indices[ROW], c00.indices[COL], c00.indices[GRP], c00.offset());
        fprintf(stderr, "c01: row=%d col=%d grp=%d offset=%d\n",
                c01.indices[ROW], c01.indices[COL], c01.indices[GRP], c01.offset());
        fprintf(stderr, "are_neighbors_array=%p\n", (void*)p->are_neighbors_array);
        fprintf(stderr, "neighbors(00,01)=%d (same row+grp, expect 1)\n", p->are_neighbors(&c00, &c01));
        fprintf(stderr, "neighbors(00,09)=%d (same grp, expect 1)\n",     p->are_neighbors(&c00, &c09));
        fprintf(stderr, "neighbors(00,03)=%d (same row, expect 1)\n",     p->are_neighbors(&c00, &c03));
        fprintf(stderr, "neighbors(00,27)=%d (same col, expect 1)\n",     p->are_neighbors(&c00, &c27));
        fprintf(stderr, "neighbors(01,27)=%d (no relation, expect 0)\n",  p->are_neighbors(&c01, &c27));
    }

    fprintf(stderr, "sudoku_generate: construct_solution\n");
    if (!p->construct_solution()) { fprintf(stderr, "construct_solution failed\n"); return 0; }
    if (p->cancelPuzzle || p->cancelSolution) return 0;

    fprintf(stderr, "sudoku_generate: construct_puzzle\n");
    int result = p->construct_puzzle(to_quality(quality), mt);
    if (result == 0) { fprintf(stderr, "construct_puzzle failed\n"); return 0; }
    if (p->cancelPuzzle) return 0;

    fprintf(stderr, "sudoku_generate: make_ready_for_UI\n");
    p->make_ready_for_UI();
    fprintf(stderr, "sudoku_generate: done\n");
    return 1;
}

void sudoku_cancel(void* handle) {
    Puzzle* p = P(handle);
    p->cancelPuzzle   = true;
    p->cancelSolution = true;
}

// ---------------------------------------------------------------------------
// Cell access
// ---------------------------------------------------------------------------

void sudoku_get_cell(void* handle, int offset, SudokuCell* out) {
    Puzzle* p = P(handle);
    const PUZZLE_CELL& c = p->cell(offset);
    out->solution           = c.solution;        // digit 1-9 after make_ready_for_UI
    out->mask               = c.mask;
    out->elim_bits          = (int)c.elim_bits;
    out->user_answer        = (int)c.user_answer; // integer 1-9 or 0
    out->display_small_digits = c.display_small_digits ? 1 : 0;
    out->display_marker     = c.display_marker;
    out->group              = c.indices[GRP];
    out->row                = c.indices[ROW];
    out->col                = c.indices[COL];
}

void sudoku_get_color_map(void* handle, int color_out[9]) {
    Puzzle* p = P(handle);
    memcpy(color_out, p->iColorMap, 9 * sizeof(int));
}

int sudoku_same_group_right(void* handle, int offset) {
    Puzzle* p = P(handle);
    if (offset % 9 == 8) return 0;
    const PUZZLE_CELL& c  = p->cell(offset);
    const PUZZLE_CELL& cr = p->cell(offset + 1);
    return (c.indices[GRP] == cr.indices[GRP]) ? 1 : 0;
}

int sudoku_same_group_below(void* handle, int offset) {
    Puzzle* p = P(handle);
    if (offset >= 9 * 8) return 0;
    const PUZZLE_CELL& c  = p->cell(offset);
    const PUZZLE_CELL& cb = p->cell(offset + 9);
    return (c.indices[GRP] == cb.indices[GRP]) ? 1 : 0;
}

int sudoku_are_neighbors(void* handle, int offset1, int offset2) {
    Puzzle* p = P(handle);
    const PUZZLE_CELL* c1 = &p->cell(offset1);
    const PUZZLE_CELL* c2 = &p->cell(offset2);
    return p->are_neighbors(c1, c2) ? 1 : 0;
}

// ---------------------------------------------------------------------------
// User interaction
// ---------------------------------------------------------------------------

void sudoku_set_user_answer(void* handle, int offset, int digit, int old_digit,
                            int digit_assistant_on)
{
    Puzzle* p = P(handle);
    PUZZLE_CELL& c = p->cell(offset);

    c.user_answer = digit;

    if (digit_assistant_on) {
        // Roll back old digit's elimination contribution, then apply new one
        if (old_digit) {
            p->reverse_elimination_for_cell_and_digit(&c, BIT(old_digit));
        }
        if (digit) {
            c.elim_bits = BIT(digit);
            p->simplify_by_elimination_using_cell(&c);
        }
    }
}

void sudoku_toggle_elim_bit(void* handle, int offset, int digit) {
    Puzzle* p = P(handle);
    PUZZLE_CELL& c = p->cell(offset);
    if (digit)
        c.elim_bits ^= BIT(digit);
    else
        c.elim_bits = 0;
}

int sudoku_toggle_small_mode(void* handle, int offset) {
    Puzzle* p = P(handle);
    PUZZLE_CELL& c = p->cell(offset);
    c.display_small_digits = !c.display_small_digits;
    return c.display_small_digits ? 1 : 0;
}

void sudoku_digit_assistant_all(void* handle) {
    Puzzle* p = P(handle);

    // Step 1: set all unsolved cells to small mode with all bits on
    for (int offset = 0; offset < 9 * 9; offset++) {
        PUZZLE_CELL& c = p->cell(offset);
        if (c.display_small_digits || ((!c.mask) && (c.user_answer == 0))) {
            c.display_small_digits = true;
            c.elim_bits = ALL_ELIM_BITS_ON;
            c.user_answer = 0;
        }
    }

    // Step 2: propagate elimination from clues and answered cells
    for (int offset = 0; offset < 9 * 9; offset++) {
        PUZZLE_CELL& c = p->cell(offset);
        if (c.mask) {
            c.elim_bits = BIT(c.solution);
            p->simplify_by_elimination_using_cell(&c);
        } else if (c.user_answer != 0) {
            c.elim_bits = BIT(c.user_answer);
            p->simplify_by_elimination_using_cell(&c);
        } else {
            c.display_small_digits = true;
        }
    }
}

// ---------------------------------------------------------------------------
// Puzzle state queries
// ---------------------------------------------------------------------------

SudokuPuzzleState sudoku_get_state(void* handle, int digit_counts[10]) {
    Puzzle* p = P(handle);
    PUZZLE_STATE ps = p->puzzle_state(digit_counts);
    switch (ps) {
        case CORRECT_SOLUTION:  return SUDOKU_STATE_CORRECT;
        case INCORRECT_SOLUTION: return SUDOKU_STATE_INCORRECT;
        default:                return SUDOKU_STATE_UNFINISHED;
    }
}

int sudoku_distance(void* handle) {
    return P(handle)->distance_to_solution();
}

void sudoku_maxed_digits(void* handle, int maxed[10]) {
    bool bools[10] = {};
    P(handle)->maxed_digits(bools);     // engine writes indices 1..9
    for (int i = 0; i <= 9; i++)
        maxed[i] = bools[i] ? 1 : 0;
}

// ---------------------------------------------------------------------------
// Raw puzzle state (Dart-side undo/redo)
// ---------------------------------------------------------------------------

int sudoku_puzzle_byte_size(void) {
    return (int)sizeof(PUZZLE);
}

void sudoku_get_puzzle_bytes(void* handle, uint8_t* buf) {
    Puzzle* p = P(handle);
    memcpy(buf, p->puzzle, sizeof(PUZZLE));
}

void sudoku_set_puzzle_bytes(void* handle, const uint8_t* buf) {
    Puzzle* p = P(handle);
    memcpy(p->puzzle, buf, sizeof(PUZZLE));
}

// ---------------------------------------------------------------------------
// Restart
// ---------------------------------------------------------------------------

void sudoku_restart(void* handle) {
    P(handle)->start_or_restart_UI();
}
