// game_screen.dart — the main playing screen

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../puzzle/puzzle_engine.dart';
import '../puzzle/puzzle_types.dart';
import '../theme/app_theme.dart';
import '../widgets/puzzle_grid.dart';
import 'new_game_dialog.dart';

class GameScreen extends StatelessWidget {
  /// When navigating from a slideshow, pass the hero tag so the grid
  /// animates seamlessly from/to its position in the slide.
  final String? heroTag;
  const GameScreen({super.key, this.heroTag});

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
                  ? _GameBody(engine: engine, heroTag: heroTag)
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
  final String?      heroTag;
  const _GameBody({required this.engine, this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: Column(
            children: [
              // Top bar: pen toggle | progress | new-game button
              _TopBar(
                engine:    engine,
                onNewGame: () => _showNewGameDialog(context, engine),
              ),

              // Puzzle grid — takes remaining space
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: heroTag != null
                          ? Hero(tag: heroTag!, child: PuzzleGrid(engine: engine))
                          : PuzzleGrid(engine: engine),
                    ),
                  ),
                ),
              ),

              // Digit + action keypad — constrained to grid width
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: _Keypad(
                    engine:    engine,
                    onNewGame: () => _showNewGameDialog(context, engine),
                  ),
                ),
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

// ---------------------------------------------------------------------------
// Top bar: [Pen toggle]  [────── progress ──────]  [New]
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  final PuzzleEngine engine;
  final VoidCallback onNewGame;
  const _TopBar({required this.engine, required this.onNewGame});

  @override
  Widget build(BuildContext context) {
    final sel         = engine.selectedOffset;
    final inSmallMode = sel >= 0 ? (engine.cell(sel)?.smallMode ?? false) : false;
    final dist        = engine.distance;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          // Pen / Pencil toggle
          GestureDetector(
            onTap: () {
              if (sel >= 0) engine.toggleSmallMode(sel);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: inSmallMode ? AppTheme.pencilText : AppTheme.keypadBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.gridLine),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    inSmallMode ? Icons.edit : Icons.create,
                    size: 14,
                    color: inSmallMode ? Colors.white : AppTheme.clueText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    inSmallMode ? 'Pencil' : 'Pen',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: inSmallMode ? Colors.white : AppTheme.clueText,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: dist == 0 ? 1.0 : 1.0 - dist / 81.0,
                  backgroundColor: AppTheme.keypadBg,
                  color: dist == 0 ? AppTheme.winGold : AppTheme.userText,
                ),
                const SizedBox(height: 2),
                Text(
                  dist == 0 ? 'Solved!' : '$dist left',
                  style: const TextStyle(fontSize: 11, color: AppTheme.clueText),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // New game button
          GestureDetector(
            onTap: engine.generating ? null : onNewGame,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.keypadBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.gridLine),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh,
                    size: 14,
                    color: engine.generating ? AppTheme.gridLine : AppTheme.clueText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'New',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: engine.generating ? AppTheme.gridLine : AppTheme.clueText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Digit + action keypad
// ---------------------------------------------------------------------------

class _Keypad extends StatelessWidget {
  final PuzzleEngine engine;
  final VoidCallback onNewGame;
  const _Keypad({required this.engine, required this.onNewGame});

  @override
  Widget build(BuildContext context) {
    final maxed       = engine.maxedDigits;
    final sel         = engine.selectedOffset;
    final inSmallMode = sel >= 0 ? (engine.cell(sel)?.smallMode ?? false) : false;

    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 6, bottom: 8, top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Single row of 9 digit chiclets
          SizedBox(
            height: 44,
            child: Row(
              children: [
                for (int d = 1; d <= 9; d++) ...[
                  if (d > 1) const SizedBox(width: 3),
                  Expanded(
                    child: _DigitKey(
                      digit:     d,
                      maxed:     maxed[d],
                      smallMode: inSmallMode,
                      onTap:     () => _onDigit(d, inSmallMode),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Action row: undo | redo | assist | check | erase
          SizedBox(
            height: 40,
            child: Row(
              children: [
                _ActionKey(
                  icon:    Icons.undo,
                  enabled: engine.hasUndo,
                  onTap:   engine.undo,
                ),
                const SizedBox(width: 4),
                _ActionKey(
                  icon:    Icons.redo,
                  enabled: engine.hasRedo,
                  onTap:   engine.redo,
                ),
                const SizedBox(width: 4),
                _ActionKey(
                  icon:   Icons.auto_fix_high,
                  active: engine.digitAssistant,
                  onTap:  engine.toggleDigitAssistant,
                ),
                const SizedBox(width: 4),
                _ActionKey(
                  icon:   Icons.check_circle_outline,
                  active: engine.checkAnswer,
                  onTap:  engine.toggleCheckAnswer,
                ),
                const SizedBox(width: 4),
                _ActionKey(
                  icon:  Icons.backspace_outlined,
                  onTap: () => _onErase(inSmallMode),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onDigit(int digit, bool smallMode) {
    final sel = engine.selectedOffset;
    if (sel < 0) return;
    final c = engine.cell(sel);
    if (c == null || c.isClue) return;
    if (smallMode) {
      engine.toggleElimBit(sel, digit);
    } else {
      engine.setUserAnswer(sel, c.userAnswer == digit ? 0 : digit);
    }
  }

  void _onErase(bool smallMode) {
    final sel = engine.selectedOffset;
    if (sel < 0) return;
    final c = engine.cell(sel);
    if (c == null || c.isClue) return;
    if (smallMode) {
      engine.toggleElimBit(sel, 0);
    } else {
      engine.clearUserAnswer(sel);
    }
  }
}

class _DigitKey extends StatelessWidget {
  final int digit;
  final bool maxed;
  final bool smallMode;
  final VoidCallback onTap;

  const _DigitKey({
    required this.digit,
    required this.maxed,
    required this.smallMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: maxed ? AppTheme.gridLine.withValues(alpha: 0.3) : AppTheme.keypadBg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: maxed ? null : onTap,
        child: Center(
          child: Text(
            '$digit',
            style: TextStyle(
              fontSize: smallMode ? 13 : 18,
              fontWeight: FontWeight.w600,
              color: maxed
                  ? AppTheme.gridLine
                  : smallMode
                      ? AppTheme.pencilText
                      : AppTheme.clueText,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionKey extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final bool active;
  final VoidCallback onTap;

  const _ActionKey({
    required this.icon,
    this.enabled = true,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppTheme.winGold
        : enabled
            ? AppTheme.clueText
            : AppTheme.gridLine;
    return Expanded(
      child: Material(
        color: AppTheme.keypadBg,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: enabled ? onTap : null,
          child: Center(child: Icon(icon, color: color, size: 22)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting widgets
// ---------------------------------------------------------------------------

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
