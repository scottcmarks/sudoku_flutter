// print_puzzle.h — Unicode box-drawing grid renderer for SudokuX4 CLI tools
//
// Include in any CLI jig to get print_puzzle(h, is_x).
// Group boundaries → double lines (═/║); intra-group → dashed (┄/┆).
// Works identically for regular and irregular puzzles.
//
// For X-sudoku, the 8 interior corner intersections on each diagonal are
// marked 'X' instead of the normal box-drawing character.

#pragma once
#include "sudoku_ffi.h"
#include <cstdio>

// ---------------------------------------------------------------------------
// Internal helpers (pp_ prefix avoids collision with other TUs)
// ---------------------------------------------------------------------------

// Weight of vertical segment at col line J spanning row i → i+1.
// Returns 2 (double/group-boundary) or 1 (dashed/same-group).  J=0..9, i=0..8.
static inline int pp_v_thick(void* h, int J, int i) {
    if (J == 0 || J == 9) return 2;                       // outer border
    return sudoku_same_group_right(h, i*9 + (J-1)) ? 1 : 2;
}

// Weight of horizontal segment at row line I spanning col j → j+1.
// Returns 2 (double) or 1 (dashed).  I=0..9, j=0..8.
static inline int pp_h_thick(void* h, int I, int j) {
    if (I == 0 || I == 9) return 2;                       // outer border
    return sudoku_same_group_below(h, (I-1)*9 + j) ? 1 : 2;
}

// Box-drawing character for a 4-arm intersection.
// Each arm: 0=absent, 1=single/dashed (intra-group), 2=double (group border).
// Cases with no double/single Unicode equivalent fall back to heavy/light chars.
static const char* pp_box_char(int u, int d, int l, int r) {
#define K(u,d,l,r) (((u)*27)+((d)*9)+((l)*3)+(r))
    switch (K(u,d,l,r)) {
    // Straight lines
    case K(1,1,0,0): return "│";   case K(2,2,0,0): return "║";
    case K(0,0,1,1): return "─";   case K(0,0,2,2): return "═";
    // Corners — single
    case K(0,1,0,1): return "┌";   case K(0,1,1,0): return "┐";
    case K(1,0,0,1): return "└";   case K(1,0,1,0): return "┘";
    // Corners — double
    case K(0,2,0,2): return "╔";   case K(0,2,2,0): return "╗";
    case K(2,0,0,2): return "╚";   case K(2,0,2,0): return "╝";
    // Corners — mixed single/double
    case K(0,1,0,2): return "╒";   case K(0,2,0,1): return "╓";
    case K(0,1,2,0): return "╕";   case K(0,2,1,0): return "╖";
    case K(1,0,0,2): return "╘";   case K(2,0,0,1): return "╙";
    case K(1,0,2,0): return "╛";   case K(2,0,1,0): return "╜";
    // T — no left arm
    case K(1,1,0,1): return "├";   case K(1,1,0,2): return "╞";
    case K(2,2,0,1): return "╟";   case K(2,2,0,2): return "╠";
    // T — no left arm, asymmetric (no double/single equivalent — heavy fallback)
    case K(2,1,0,1): return "┞";   case K(1,2,0,1): return "┟";
    case K(2,1,0,2): return "┡";   case K(1,2,0,2): return "┢";
    // T — no right arm
    case K(1,1,1,0): return "┤";   case K(1,1,2,0): return "╡";
    case K(2,2,1,0): return "╢";   case K(2,2,2,0): return "╣";
    // T — no right arm, asymmetric (heavy fallback)
    case K(2,1,1,0): return "┦";   case K(1,2,1,0): return "┧";
    case K(2,1,2,0): return "┩";   case K(1,2,2,0): return "┪";
    // T — no up arm
    case K(0,1,1,1): return "┬";   case K(0,1,2,2): return "╤";
    case K(0,2,1,1): return "╥";   case K(0,2,2,2): return "╦";
    // T — no up arm, asymmetric (heavy fallback)
    case K(0,1,2,1): return "┭";   case K(0,1,1,2): return "┮";
    case K(0,2,2,1): return "┱";   case K(0,2,1,2): return "┲";
    // T — no down arm
    case K(1,0,1,1): return "┴";   case K(1,0,2,2): return "╧";
    case K(2,0,1,1): return "╨";   case K(2,0,2,2): return "╩";
    // T — no down arm, asymmetric (heavy fallback)
    case K(1,0,2,1): return "┵";   case K(1,0,1,2): return "┶";
    case K(2,0,2,1): return "┹";   case K(2,0,1,2): return "┺";
    // Cross — symmetric (proper double/single chars)
    case K(1,1,1,1): return "┼";   case K(1,1,2,2): return "╪";
    case K(2,2,1,1): return "╫";   case K(2,2,2,2): return "╬";
    // Cross — asymmetric (no double/single equivalent — heavy fallback)
    case K(1,1,2,1): return "┽";   case K(1,1,1,2): return "┾";
    case K(2,1,1,1): return "╀";   case K(1,2,1,1): return "╁";
    case K(2,1,2,1): return "╃";   case K(2,1,1,2): return "╄";
    case K(1,2,2,1): return "╅";   case K(1,2,1,2): return "╆";
    case K(2,1,2,2): return "╇";   case K(1,2,2,2): return "╈";
    case K(2,2,2,1): return "╉";   case K(2,2,1,2): return "╊";
    default: return "?";
    }
#undef K
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

// Print the puzzle as a Unicode box-drawing grid.
// Clue cells show their digit; unsolved cells show ' '.
// is_x: mark the 8 interior corner intersections on each diagonal with 'X'.
static void print_puzzle(void* h, bool is_x) {
    SudokuCell cells[81];
    for (int i = 0; i < 81; i++)
        sudoku_get_cell(h, i, &cells[i]);

    for (int I = 0; I <= 9; I++) {
        // Border row: intersections separated by horizontal segments
        for (int J = 0; J <= 9; J++) {
            // Interior diagonal corners: main (I==J) and anti (I+J==9), I=1..8
            if (is_x && I >= 1 && I <= 8 && (I == J || I + J == 9)) {
                printf("X");
            } else {
                int u = (I > 0) ? pp_v_thick(h, J, I-1) : 0;
                int d = (I < 9) ? pp_v_thick(h, J, I)   : 0;
                int l = (J > 0) ? pp_h_thick(h, I, J-1) : 0;
                int r = (J < 9) ? pp_h_thick(h, I, J)   : 0;
                printf("%s", pp_box_char(u, d, l, r));
            }
            if (J < 9) {
                int w = pp_h_thick(h, I, J);
                printf("%s", (w == 2) ? "═══" : "┄┄┄");
            }
        }
        printf("\n");

        // Content row for puzzle row i = I
        if (I < 9) {
            for (int J = 0; J <= 9; J++) {
                printf("%s", (pp_v_thick(h, J, I) == 2) ? "║" : "┆");
                if (J < 9) {
                    const SudokuCell& c = cells[I*9 + J];
                    printf(" %c ", c.mask ? ('0' + c.solution) : ' ');
                }
            }
            printf("\n");
        }
    }
}
