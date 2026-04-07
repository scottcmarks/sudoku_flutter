# Puzzle Generation Architecture

## Overview

Generating one puzzle involves five nested loops/recursions, two of which are
recursive backtracking algorithms. This document describes each level and
explains why generation time varies so dramatically across puzzle types and
random seeds.

---

## The Five Levels

### Level 1 — Solution generation: `construct_solution()` *(Puzzle_answer.cpp)*

Fills the 9×9 grid with a valid complete solution (all 81 cells, no clues yet).

**Setup** (done once per attempt):
- `order_groups_by_restriction()` — sorts groups by how many rows/cols they
  overlap, so the most-constrained group is filled first
- `initialize_ordered_ptrs()` / `sort_ordered_ptrs()` — sorts all 81 cells by
  constraint count (most neighbors first)
- `initialize_first_group()` — randomly shuffles digits 1–9 into the first group
- `initialize_rest_of_array()` — sets candidate bitsets for all remaining cells

**Recursive fill** — `recursively_fill_cells()`:
- Processes cells in constraint order (highest degree first)
- At each cell: picks a random candidate digit via `set_value()`, propagates
  the elimination forward to all remaining cells
- If any future cell loses all candidates: backtracks, tries the next candidate
- Recurses up to **72 levels deep** (81 cells − 9 already placed)
- For irregular group maps some arrangements of the first group yield zero valid
  completions, forcing a full unwind and retry at Level 1

If `construct_solution()` fails (rare), `sudoku_generate()` retries from
scratch with a new seed.

---

### Level 2 — Clue selection outer loop: `make_puzzle()` *(Puzzle_clues.cpp)*

Runs up to **`ntries` iterations** (100 for BEST_PUZZLE quality, the value
always used for irregular puzzles). Each iteration:

1. Calls `make_solvable_puzzle()` (Level 3)
2. Calls `remove_clues_returning_rating()` (Level 4)
3. Checks whether the result meets the difficulty requirements
4. Keeps the best-rated result; for Quickie/Easy exits immediately on first
   success (`break_on_target_nclues = true`)

There is also a wall-clock timeout: 1190 seconds total across all iterations.

---

### Level 3 — Make solvable puzzle: `make_solvable_puzzle()` *(Puzzle_clues.cpp)*

Starts with ~40 randomly selected clues (from the complete solution grid) and
calls the human-technique solver. If any cells remain unsolved, adds one or two
more clues and solves again — **repeating until fully solved** by the target
technique (e.g., ELIMINATION for Quickie).

This ensures the starting point for clue removal is a valid puzzle at at least
the target difficulty.

---

### Level 4 — Clue removal: `remove_clues_returning_rating()` *(Puzzle_clues.cpp)*

Iterates through the ~40 initial clues in random order, attempting to remove
each one:

- Remove the clue
- Call `solve()` with the target technique (Level 5)
- If the puzzle is still uniquely solvable: keep it removed; record best state
- If not: restore the clue

Stops when the target clue count is reached or no more clues can be removed.
Has a per-iteration timeout of 600 seconds.

---

### Level 5 — Human-technique solver: `solve()` *(Puzzle_solver.cpp)*

Applies human solving techniques in increasing order of difficulty. The
`METHOD_TYPE` enum in `Puzzle_parameters.h` defines the ordering; each
difficulty level caps which techniques the solver is allowed to use.

#### Solving techniques (easiest → hardest)

**ELIMINATION** — the two most basic techniques:
- *Naked single*: a cell has only one remaining candidate → place it.
- *Hidden single*: within a row, column, or group, a digit can go in
  only one cell → place it there.

**BY_DIGIT** — *pointing pairs / triples*: all candidates for a digit
within a group lie in one row or column, so that digit can be eliminated
from the rest of that row/column outside the group.

**RESTRICTION** — *box-line reduction* (the reverse): all candidates for
a digit within a row or column lie in one group, so that digit can be
eliminated from the rest of the group.

**DOUBLE_RESTRICTION** — two simultaneous restriction interactions
working together.

**X_WING** — if a digit appears in exactly the same two columns in two
different rows (or two rows in two columns), it can be eliminated from
the rest of those two columns (or rows). Forms a rectangle of four cells.

**X_CHAIN** — a chain of cells linked by a single digit with alternating
strong (exactly two candidates in a unit) and weak (more than two)
links. If both ends of the chain "see" a cell, that cell can't hold the
digit.

**XY_CHAIN** — a chain of *bivalue* cells (exactly two candidates each)
where consecutive links share one candidate digit. Cells that see both
ends of the chain and share the chain's "pincer" digit can have that
digit eliminated.

**XY_XYZ_WING** — covers two related wing patterns:
- *XY-Wing*: three cells (pivot + two pincers) with three digits
  arranged so every cell visible to both pincers loses one digit.
- *XYZ-Wing*: similar but the pivot also contains the elimination digit;
  slightly stronger.

**ALMOST_LOCKED_SETS (ALS)** — a set of *N* cells containing exactly
*N+1* candidate digits. When two ALS share a "restricted common" digit
(forced out of one set), other shared digits between the sets can be
eliminated from cells that see both sets.

**ROW_COL_ELIMINATION** — generalized *single-digit fish* (Swordfish ×3,
Jellyfish ×4, …): if a digit's candidates in *N* rows occupy exactly *N*
columns, eliminate that digit from those columns everywhere else, and
vice versa.

**FRANKEN_FISH** — a fish pattern where one or more of the "base" sets
is a group (box) rather than a row or column, allowing cross-structure
eliminations that pure row/col fish cannot find.

**FINS / DOUBLE_FIN** — a *finned fish*: a standard fish pattern with
one or two extra candidate cells ("fins") in a base set. Cells that see
both a fin and all the fish's cover-set cells in that row/column can
still be eliminated.

**CHAINS / BRUTE_FORCE** — used only at Ultimate difficulty:
- *Chains*: longer alternating-inference chains (Forcing Chains, AICs)
  where multiple deduction paths converge on the same elimination.
- *Brute Force*: trial-and-error recursion used as a last resort and
  for uniqueness verification (see below).

---

For uniqueness checking during clue removal, `solve_by_brute_force()` is
called when human techniques can't finish — which uses `brute_force()`:

**`brute_force()`** is a recursive DFS that:
- Tries every candidate digit for each non-clue cell in grid order
- Counts complete solutions; stops at 2 (non-unique)
- Up to **81 levels deep**
- Has a 20-second timeout

---

## Group Map Selection *(GroupMap.cc)*

For irregular puzzles, the group map (which cells form each group) is chosen
before Level 1 and strongly influences all subsequent levels.

There are **15 `.z` files** (mir01–mir10, rot_2grp01, rot_3grp01–04), each
containing thousands of pre-generated group maps. Selection is two-level:

1. A weighted random draw chooses one of the 15 files (mirror files are
   weighted 4× vs rotational files)
2. A second random draw picks a specific map within that file

Both draws consume the seeded `rand()`, so the group map is determined by the
seed. Some group map shapes are inherently harder for certain difficulties
(see below).

Tracing output (to stderr):
```
GroupMap: file=mir03 mapNumber=4721/10000
```

---

## Why Quickie Irregular Has Extreme Variance

Quickie requires a puzzle solvable by **ELIMINATION only** (naked/hidden
singles — no harder techniques). The target clue count is 31–35.

For **regular** grids, the fixed 3×3 box structure reliably creates many
elimination chains at low clue counts. Nearly every solution grid yields a
qualifying Quickie puzzle in the first few Level-2 iterations.

For **irregular** grids, group shapes vary enormously:
- "Rich" group maps have many rows/cols that share large fractions of a group,
  creating abundant elimination opportunities → Quickie puzzles found quickly
- "Lean" group maps have diffuse groups with few shared row/col segments →
  very few 31–35 clue subsets that are both uniquely solvable AND solvable by
  elimination alone

When the seed selects a "lean" group map, nearly all 100 Level-2 iterations
fail `at_least_one_technique_for_difficulty()` and the engine exhausts the
full budget.

**Observed examples:**
- Seed 3129685568 (Quickie Irregular): ~93,000ms — likely exhausted most of
  100 iterations (~930ms each)
- Seed 1792034834 (Quickie Irregular): ~555ms — hit a qualifying map on
  iteration 1 or 2

A factor of ~170× in iteration count explains a ~170× time difference; the
remaining factor comes from the group map itself requiring more backtracking in
Level 1.

**Implication:** Irregular puzzles (especially Quickie) must be pre-generated
in background queues. The 24 queues (4 types × 6 difficulties) absorb this
variance so users always get instant puzzle delivery.

---

## Tracing

The CLI tools print tracing to stderr:

```
GroupMap: file=mir03 mapNumber=4721/10000       ← which group map was chosen
make_puzzle: itries=97/100 rating=42 nclues=33  ← how many iterations ran
```

Run `test_one_cli` or `test_timing_study.fast` without redirecting stderr to
see this output. To separate timing table (stdout) from traces (stderr):

```bash
SUDOKU_GROUP_MAPS_DIR=... ./test_timing_study.fast > timing.txt 2> trace.txt
```

Or to interleave them in order:
```bash
SUDOKU_GROUP_MAPS_DIR=... ./test_timing_study.fast 2>&1 | tee timing_full.txt
```
