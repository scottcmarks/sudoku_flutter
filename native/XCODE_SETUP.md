# Xcode Setup for iOS / macOS

The C++ engine compiles directly into the app binary on iOS and macOS.
Dart FFI loads it via `DynamicLibrary.process()` (no separate `.dylib` needed).

## One-time Xcode configuration

### 1. Add source files to the Runner target

In Xcode, select the **Runner** project → **Runner** target → **Build Phases** →
**Compile Sources**.  Click **+** and add:

**From `~/sudoku_flutter/native/`:**
- `sudoku_ffi.cpp`

**From `~/SudokuX4/PlatformIndependent/Game/`:**
- `Puzzle_answer.cpp`
- `Puzzle_bruteforce.cpp`
- `Puzzle_clues.cpp`
- `Puzzle_parameters.cpp`
- `Puzzle_solver.cpp`
- `are_neighbors_array.cpp`
- `set_bit_array.cpp`
- `sudoku_combinations.cpp`
- `queue_sizes.cpp`
- `GroupMap.cc`
- `FourColorMap.cc`
- ~~`queue_data.cc`~~ — **omit**: this is the old NSOperationQueue batch serializer, not used by the Flutter path

**ConsoleGroups — do NOT add any `.c` files.**
ConsoleGroups is a standalone offline tool that *generated* the compressed irregular
group map files (`.z`); those files are the runtime data.  Its `types.h`/`irreg_types.h`
define a conflicting `SYMMETRY` enum that would clash with `puzzle_types.hh`.
The `.c` files are not needed at runtime — GroupMap.cc reads the pre-generated `.z` files.

### 2. Add additional source files

Also compile these files (from `~/Toolbox/PlatformIndependent/`):
- `rand_utils.c`
- `comb_util.c`
- `utility.c`
- `Filenames/Filenames.cpp`
- `zip/zipinput/*.cpp` (for irregular group map loading)

### 3. Add header search paths

In **Build Settings** → **Header Search Paths**, add (non-recursive):

```
$(HOME)/SudokuX4/PlatformIndependent/Game
$(HOME)/SudokuX4/PlatformIndependent/ConsoleGroups
$(HOME)/Toolbox/PlatformIndependent
$(HOME)/Toolbox/PlatformIndependent/Matrix
$(HOME)/Toolbox/PlatformIndependent/Filenames
$(HOME)/Toolbox/PlatformIndependent/zip/zipinput
$(HOME)/Toolbox/PlatformIndependent/Yield
$(SRCROOT)/../native
```

### 4. Set C++ standard

In **Build Settings** → **C++ Language Dialect**: `C++17`

### 5. Suppress legacy warnings (optional)

In **Build Settings** → **Other C++ Flags**:
```
-Wno-deprecated-declarations -Wno-reorder
```

### 6. Build and run

```bash
flutter run -d macos   # macOS desktop
flutter run            # connected iOS device
```

## Troubleshooting

- **Symbol not found: _sudoku_new** — a source file wasn't added to Compile Sources
- **Header not found** — check Header Search Paths above
- **Linker errors about C++ symbols** — make sure `.cpp` files compile as C++ (Xcode
  should detect this from extension, but check type in File Inspector if needed)
