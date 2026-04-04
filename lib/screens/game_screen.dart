// game_screen.dart — the main playing screen

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../puzzle/puzzle_engine.dart';
import '../puzzle/puzzle_types.dart';
import '../theme/app_theme.dart';
import '../widgets/keypad_widget.dart';
import '../widgets/puzzle_grid.dart';
import '../widgets/toolbar_widget.dart';
import 'new_game_dialog.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PuzzleEngine>(
      builder: (context, engine, _) {
        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: AppBar(
            title: Text(_titleFor(engine)),
            actions: [
              IconButton(
                icon: const Icon(Icons.list),
                tooltip: 'Album',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          body: engine.generating
              ? const _GeneratingOverlay()
              : engine.isLoaded
                  ? _GameBody(engine: engine)
                  : const _NoGame(),
        );
      },
    );
  }

  String _titleFor(PuzzleEngine engine) {
    if (engine.generating) return 'Generating…';
    if (!engine.isLoaded)  return 'Sudoku X4';
    final adj = engine.lastAdjType == SudokuAdjType.xSudoku ? ' X' : '';
    final map = engine.lastMapType == SudokuMapType.irregular ? ' Irregular' : '';
    return '${engine.lastDifficulty.label}$adj$map';
  }
}

class _GameBody extends StatelessWidget {
  final PuzzleEngine engine;
  const _GameBody({required this.engine});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: Column(
            children: [
              // Distance indicator
              _ProgressBar(engine: engine),

              // Puzzle grid — takes most of the space
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 480),
                      child: PuzzleGrid(engine: engine),
                    ),
                  ),
                ),
              ),

              // Toolbar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ToolbarWidget(
                  engine:    engine,
                  onNewGame: () => _showNewGameDialog(context, engine),
                ),
              ),

              // Keypad
              Padding(
                padding: const EdgeInsets.only(bottom: 16, top: 8),
                child: KeypadWidget(engine: engine),
              ),
            ],
          ),
        ),

        // Win overlay
        if (engine.userHasWon)
          _WinOverlay(onNewGame: () => _showNewGameDialog(context, engine)),
      ],
    );
  }

  void _showNewGameDialog(BuildContext context, PuzzleEngine engine) {
    showDialog(
      context: context,
      builder: (_) => NewGameDialog(engine: engine),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final PuzzleEngine engine;
  const _ProgressBar({required this.engine});

  @override
  Widget build(BuildContext context) {
    final dist = engine.distance;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(
            dist == 0 ? 'Solved!' : '$dist left',
            style: const TextStyle(fontSize: 13, color: AppTheme.clueText),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: dist == 0 ? 1.0 : 1.0 - dist / 81.0,
              backgroundColor: AppTheme.keypadBg,
              color: dist == 0 ? AppTheme.winGold : AppTheme.userText,
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneratingOverlay extends StatelessWidget {
  const _GeneratingOverlay();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Generating puzzle…', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

class _NoGame extends StatelessWidget {
  const _NoGame();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.grid_4x4, size: 64, color: AppTheme.gridLine),
          const SizedBox(height: 16),
          const Text('No puzzle loaded', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => NewGameDialog(
                engine: context.read<PuzzleEngine>(),
              ),
            ),
            child: const Text('New Game'),
          ),
        ],
      ),
    );
  }
}

class _WinOverlay extends StatelessWidget {
  final VoidCallback onNewGame;
  const _WinOverlay({required this.onNewGame});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(32),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events, size: 64, color: AppTheme.winGold),
                  const SizedBox(height: 16),
                  const Text('Solved!',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: onNewGame,
                    child: const Text('New Game'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
