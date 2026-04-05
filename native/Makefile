# Makefile for native CLI test jig
# Usage: make -C native/   OR   cd native && make

HOME       ?= $(shell echo ~)
GAME       = $(HOME)/SudokuX4/PlatformIndependent/Game
TOOLBOX    = $(HOME)/Toolbox/PlatformIndependent

CXX        = clang++
CC         = clang
CXXFLAGS   = -std=c++17 -g -O0 -fsanitize=address \
             -I$(GAME) \
             -I$(HOME)/SudokuX4/PlatformIndependent/ConsoleGroups \
             -I$(TOOLBOX) \
             -I$(TOOLBOX)/Matrix \
             -I$(TOOLBOX)/Filenames \
             -I$(TOOLBOX)/zip/zipinput \
             -I$(TOOLBOX)/Yield \
             -I.
CFLAGS     = -g -O0 -fsanitize=address \
             -I$(TOOLBOX) \
             -I$(TOOLBOX)/Filenames

VPATH = .:$(GAME):$(TOOLBOX):$(TOOLBOX)/zip/zipinput

LDFLAGS = -lz -fsanitize=address

SHARED_OBJS = \
    sudoku_ffi.o \
    Puzzle_answer.o \
    Puzzle_bruteforce.o \
    Puzzle_clues.o \
    Puzzle_parameters.o \
    Puzzle_solver.o \
    are_neighbors_array.o \
    set_bit_array.o \
    sudoku_combinations.o \
    queue_sizes.o \
    GroupMap.o \
    FourColorMap.o \
    Filenames_cli.o \
    zipinput.o \
    insertion_sort.o \
    rand_utils.o \
    comb_util.o \
    utility.o

TARGETS = test_construct_puzzle_cli test_irregular_cli test_timing_study

.PHONY: all clean run run-irregular

all: $(TARGETS)

test_construct_puzzle_cli: test_construct_puzzle_cli.o $(SHARED_OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

test_irregular_cli: test_irregular_cli.o $(SHARED_OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

test_timing_study: test_timing_study.o $(SHARED_OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

%.o: %.cc
	$(CXX) $(CXXFLAGS) -c $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

GROUP_MAPS_DIR ?= $(HOME)/SudokuX4/PlatformIndependent/Resources/group_maps

run: test_construct_puzzle_cli
	SUDOKU_GROUP_MAPS_DIR=$(GROUP_MAPS_DIR) ./test_construct_puzzle_cli

run-irregular: test_irregular_cli
	SUDOKU_GROUP_MAPS_DIR=$(GROUP_MAPS_DIR) ./test_irregular_cli

IFLAGS = -I$(GAME) \
         -I$(HOME)/SudokuX4/PlatformIndependent/ConsoleGroups \
         -I$(TOOLBOX) -I$(TOOLBOX)/Matrix -I$(TOOLBOX)/Filenames \
         -I$(TOOLBOX)/zip/zipinput -I$(TOOLBOX)/Yield -I.

timing: test_timing_study.cpp
	$(CXX) -std=c++17 -O3 $(IFLAGS) -o test_timing_study.fast \
	    test_timing_study.cpp sudoku_ffi.cpp \
	    $(GAME)/Puzzle_answer.cpp $(GAME)/Puzzle_bruteforce.cpp \
	    $(GAME)/Puzzle_clues.cpp $(GAME)/Puzzle_parameters.cpp \
	    $(GAME)/Puzzle_solver.cpp $(GAME)/are_neighbors_array.cpp \
	    $(GAME)/set_bit_array.cpp $(GAME)/sudoku_combinations.cpp \
	    $(GAME)/queue_sizes.cpp $(GAME)/GroupMap.cc $(GAME)/FourColorMap.cc \
	    Filenames_cli.cpp \
	    $(TOOLBOX)/zip/zipinput/zipinput.cpp \
	    $(TOOLBOX)/insertion_sort.cpp \
	    $(TOOLBOX)/rand_utils.c $(TOOLBOX)/comb_util.c $(TOOLBOX)/utility.c \
	    -lz
	SUDOKU_GROUP_MAPS_DIR=$(GROUP_MAPS_DIR) ./test_timing_study.fast 2>/dev/null

clean:
	rm -f *.o $(TARGETS)
