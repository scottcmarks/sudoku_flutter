# CMakeLists.txt — builds the SudokuX4 C++ engine as a shared library
# for Android, Linux, and Windows targets.
#
# iOS/macOS: the engine is compiled directly into the app binary via
# the Xcode project.  See native/XCODE_SETUP.md.

cmake_minimum_required(VERSION 3.18)
project(sudoku_engine CXX)

set(CMAKE_CXX_STANDARD 17)

# Path to the SudokuX4 platform-independent engine sources.
# Override this if the SudokuX4 repo is in a different location.
set(SUDOKU_ENGINE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../SudokuX4/PlatformIndependent"
    CACHE PATH "Path to SudokuX4/PlatformIndependent")

# Shared C++ toolbox with matrix.h, Utilities.h, rand_utils, comb_util, Filenames, zipinput
set(TOOLBOX_DIR "$ENV{HOME}/Toolbox/PlatformIndependent"
    CACHE PATH "Path to Toolbox/PlatformIndependent")

set(ENGINE_GAME_DIR     "${SUDOKU_ENGINE_DIR}/Game")
# ConsoleGroups is a standalone map-generation tool — do NOT compile its .c files.
# They define a conflicting SYMMETRY enum and are not needed at runtime.
set(TOOLBOX_FILENAMES   "${TOOLBOX_DIR}/Filenames")
set(TOOLBOX_ZIP         "${TOOLBOX_DIR}/zip/zipinput")

# Gather engine source files (.cpp and .cc)
file(GLOB ENGINE_GAME_SOURCES    "${ENGINE_GAME_DIR}/*.cpp" "${ENGINE_GAME_DIR}/*.cc")
file(GLOB TOOLBOX_SOURCES
    "${TOOLBOX_DIR}/rand_utils.c"
    "${TOOLBOX_DIR}/comb_util.c"
    "${TOOLBOX_DIR}/utility.c"
    "${TOOLBOX_FILENAMES}/Filenames.cpp"
)

# zipinput sources if irregular group loading is needed
file(GLOB TOOLBOX_ZIP_SOURCES "${TOOLBOX_ZIP}/*.cpp" "${TOOLBOX_ZIP}/*.c")

add_library(sudoku_engine SHARED
    sudoku_ffi.cpp
    ${ENGINE_GAME_SOURCES}
    ${TOOLBOX_SOURCES}
    ${TOOLBOX_ZIP_SOURCES}
)

target_include_directories(sudoku_engine PRIVATE
    ${ENGINE_GAME_DIR}
    ${TOOLBOX_DIR}
    ${TOOLBOX_DIR}/Matrix
    ${TOOLBOX_FILENAMES}
    ${TOOLBOX_ZIP}
    ${TOOLBOX_DIR}/Yield
    ${CMAKE_CURRENT_SOURCE_DIR}  # for sudoku_ffi.h
)

# Suppress warnings from the old C++ codebase
target_compile_options(sudoku_engine PRIVATE
    -Wno-deprecated-declarations
    -Wno-unused-variable
    -Wno-reorder
)

# Export the C API symbols
set_target_properties(sudoku_engine PROPERTIES
    CXX_VISIBILITY_PRESET default
    VISIBILITY_INLINES_HIDDEN OFF
)
