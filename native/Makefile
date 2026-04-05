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

VPATH = .:$(GAME):$(TOOLBOX):$(TOOLBOX)/Filenames:$(TOOLBOX)/zip/zipinput

LDFLAGS = -lz -fsanitize=address

OBJS = \
    test_construct_puzzle_cli.o \
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
    Filenames.o \
    zipinput.o \
    insertion_sort.o \
    rand_utils.o \
    comb_util.o \
    utility.o

TARGET = test_construct_puzzle_cli

.PHONY: all clean run

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

%.o: %.cc
	$(CXX) $(CXXFLAGS) -c $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

run: $(TARGET)
	./$(TARGET)

clean:
	rm -f $(OBJS) $(TARGET) test_cli.o test_cli
