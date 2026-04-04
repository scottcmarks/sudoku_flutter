// new_game_dialog.dart — difficulty/type picker before generating

import 'package:flutter/material.dart';
import '../puzzle/puzzle_engine.dart';
import '../puzzle/puzzle_types.dart';
import '../theme/app_theme.dart';

class NewGameDialog extends StatefulWidget {
  final PuzzleEngine engine;
  const NewGameDialog({super.key, required this.engine});

  @override
  State<NewGameDialog> createState() => _NewGameDialogState();
}

class _NewGameDialogState extends State<NewGameDialog> {
  late SudokuDifficulty _difficulty;
  late SudokuMapType    _mapType;
  late SudokuAdjType    _adjType;

  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _difficulty = widget.engine.lastDifficulty;
    _mapType    = widget.engine.lastMapType;
    _adjType    = widget.engine.lastAdjType;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Game'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Difficulty
          const Text('Difficulty', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SudokuDifficulty.values.map((d) {
              return ChoiceChip(
                label: Text(d.label),
                selected: _difficulty == d,
                onSelected: (_) => setState(() => _difficulty = d),
                selectedColor: AppTheme.groupBorder,
                labelStyle: TextStyle(
                  color: _difficulty == d ? Colors.white : AppTheme.clueText,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),
          // Map type
          const Text('Groups', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<SudokuMapType>(
            segments: const [
              ButtonSegment(value: SudokuMapType.square,    label: Text('Square')),
              ButtonSegment(value: SudokuMapType.irregular, label: Text('Irregular')),
            ],
            selected: {_mapType},
            onSelectionChanged: (s) => setState(() => _mapType = s.first),
          ),

          const SizedBox(height: 12),
          // X-Sudoku toggle
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('X-Sudoku (diagonal constraints)'),
            value: _adjType == SudokuAdjType.xSudoku,
            onChanged: (v) => setState(() =>
              _adjType = (v ?? false) ? SudokuAdjType.xSudoku : SudokuAdjType.normal),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _generating ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _generating ? null : _startGame,
          child: _generating
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Generate'),
        ),
      ],
    );
  }

  Future<void> _startGame() async {
    setState(() => _generating = true);
    bool ok = false;
    try {
      ok = await widget.engine.generateNewPuzzle(
        mapType:    _mapType,
        adjType:    _adjType,
        difficulty: _difficulty,
        quality:    SudokuQuality.compromise,
      );
      debugPrint('generateNewPuzzle returned ok=$ok');
    } catch (e, st) {
      debugPrint('generateNewPuzzle threw: $e\n$st');
    }
    debugPrint('mounted=$mounted, calling pop($ok)');
    if (mounted) Navigator.of(context).pop(ok);
  }
}
