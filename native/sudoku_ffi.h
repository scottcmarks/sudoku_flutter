// sudoku_ffi.h — C API over the SudokuX4 C++ engine, callable via dart:ffi
//
// Opaque handle pattern: callers see only PuzzleHandle (void*).
// All puzzle state lives inside the engine; Dart reads snapshots via
// sudoku_get_cell() and sudoku_get_puzzle_bytes() / sudoku_set_puzzle_bytes()
// (the latter two are used by the Dart undo/redo layer).

#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ---------------------------------------------------------------------------
// Enums (mirrors of puzzle_types.hh / ui_types.h)
// ---------------------------------------------------------------------------

typedef enum {
    SUDOKU_MAP_SQUARE    = 0,
    SUDOKU_MAP_IRREGULAR = 1,
} SudokuMapType;

typedef enum {
    SUDOKU_ADJ_NORMAL = 0,
    SUDOKU_ADJ_X      = 1,   // adds main diagonals
} SudokuAdjType;

typedef enum {
    SUDOKU_DIFF_QUICKIE       = 0,
    SUDOKU_DIFF_EASY          = 1,
    SUDOKU_DIFF_MEDIUM        = 2,
    SUDOKU_DIFF_HARD          = 3,
    SUDOKU_DIFF_EXPERT        = 4,
    SUDOKU_DIFF_ULTIMATE      = 5,
} SudokuDifficulty;

typedef enum {
    SUDOKU_QUALITY_ASAP      = 0,
    SUDOKU_QUALITY_COMPROMISE= 1,
    SUDOKU_QUALITY_BEST      = 2,
} SudokuQuality;

typedef enum {
    SUDOKU_STATE_UNFINISHED = 0,
    SUDOKU_STATE_CORRECT    = 1,
    SUDOKU_STATE_INCORRECT  = 2,
} SudokuPuzzleState;

typedef enum {
    SUDOKU_MARKER_PEN     = 0,
    SUDOKU_MARKER_MARKER1 = 1,
    SUDOKU_MARKER_MARKER2 = 2,
    SUDOKU_MARKER_PENCIL  = 3,
} SudokuMarker;

// ---------------------------------------------------------------------------
// Cell snapshot (read-only view of one cell's UI state)
// ---------------------------------------------------------------------------

typedef struct {
    int  solution;           // digit 1-9 (set after make_ready_for_UI)
    int  mask;               // 1 = given clue, 0 = user cell
    int  elim_bits;          // bit N set ⟹ digit N is a candidate (pencil marks)
    int  user_answer;        // digit 1-9 entered by user, 0 = empty
    int  display_small_digits; // non-zero ⟹ cell is in small-digit (pencil) mode
    int  display_marker;     // SudokuMarker (pen/pencil colour)
    int  group;              // group index 0-8
    int  row;                // 0-8
    int  col;                // 0-8
} SudokuCell;

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

// Allocate a new Puzzle object.  Must be freed with sudoku_free().
void* sudoku_new(void);

// Free a puzzle previously returned by sudoku_new().
void  sudoku_free(void* handle);

// ---------------------------------------------------------------------------
// Global initialisation — call once at app startup before any sudoku_new()
// ---------------------------------------------------------------------------

// Set the directory that contains the group map .z files (rot_*.z, mir_*.z).
// If not called, falls back to SUDOKU_GROUP_MAPS_DIR env var, then
// /usr/share/sudoku/group_maps.
void sudoku_set_group_maps_dir(const char* path);

// ---------------------------------------------------------------------------
// Generation  (blocking — call from a Dart isolate)
// ---------------------------------------------------------------------------

// Generate a complete new puzzle:
//   1. Pick/build group map for mapType
//   2. Generate solution
//   3. Remove clues to reach difficulty
//   4. Prepare for UI (convert solution bits → digits, zero user state)
// Returns 1 on success, 0 on failure or cancellation.
int sudoku_generate(void*          handle,
                    SudokuMapType  mapType,
                    SudokuAdjType  adjType,
                    SudokuDifficulty difficulty,
                    SudokuQuality  quality);

// Signal the generation loop to stop (safe to call from any thread).
void sudoku_cancel(void* handle);

// ---------------------------------------------------------------------------
// Cell access
// ---------------------------------------------------------------------------

// Fill *out with the current state of cell at linear offset (row*9 + col).
void sudoku_get_cell(void* handle, int offset, SudokuCell* out);

// Return the 4-color map: color[g] ∈ {0,1,2,3} for group g ∈ {0..8}.
// Used to shade irregular groups differently.
void sudoku_get_color_map(void* handle, int color_out[9]);

// Returns 1 if the cell to the right of `offset` is in the same group.
int sudoku_same_group_right(void* handle, int offset);

// Returns 1 if the cell below `offset` is in the same group.
int sudoku_same_group_below(void* handle, int offset);

// Returns 1 if the two cells are neighbors (share a row, col, group, or diagonal).
int sudoku_are_neighbors(void* handle, int offset1, int offset2);

// ---------------------------------------------------------------------------
// User interaction
// ---------------------------------------------------------------------------

// Set user answer (digit 1-9) or clear (digit 0).
// Also updates elim_bits if digit assistant is on.
// `old_digit`: previous user_answer (0 if none); needed for digit-assistant rollback.
void sudoku_set_user_answer(void* handle, int offset, int digit, int old_digit,
                            int digit_assistant_on);

// Toggle a pencil-mark candidate bit for `digit` (1-9) in small-digit mode.
// Pass digit=0 to clear all elim_bits.
void sudoku_toggle_elim_bit(void* handle, int offset, int digit);

// Toggle small-digit mode for cell; returns new state (0 or 1).
int sudoku_toggle_small_mode(void* handle, int offset);

// Turn on digit assistant for all cells (runs full elimination pass).
void sudoku_digit_assistant_all(void* handle);

// ---------------------------------------------------------------------------
// Puzzle state queries
// ---------------------------------------------------------------------------

// Returns one of SudokuPuzzleState.
// Also fills digit_counts[1..9] with how many of each digit are placed.
SudokuPuzzleState sudoku_get_state(void* handle, int digit_counts[10]);

// Number of cells not yet correctly filled (0 = solved).
int sudoku_distance(void* handle);

// Fill maxed[1..9]: non-zero if all 9 instances of that digit are placed.
void sudoku_maxed_digits(void* handle, int maxed[10]);

// ---------------------------------------------------------------------------
// Raw puzzle state (for Dart-side undo/redo snapshotting)
// ---------------------------------------------------------------------------

// Number of bytes in the serializable PUZZLE array (9×9 × sizeof(PUZZLE_CELL)).
int sudoku_puzzle_byte_size(void);

// Copy the current PUZZLE bytes into `buf` (caller must allocate sudoku_puzzle_byte_size() bytes).
void sudoku_get_puzzle_bytes(void* handle, uint8_t* buf);

// Restore PUZZLE bytes from `buf`.
void sudoku_set_puzzle_bytes(void* handle, const uint8_t* buf);

// After sudoku_set_puzzle_bytes, call this to set adjacency type and build
// the are_neighbors_array needed for cell-highlight queries.
// mapType / adjType must match the puzzle that was originally generated.
void sudoku_setup_loaded(void* handle, SudokuMapType mapType, SudokuAdjType adjType);

// ---------------------------------------------------------------------------
// Restart
// ---------------------------------------------------------------------------

// Reset all user answers / pencil marks to their initial state.
void sudoku_restart(void* handle);

#ifdef __cplusplus
}
#endif
