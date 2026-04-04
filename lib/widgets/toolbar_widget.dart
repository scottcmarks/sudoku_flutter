// toolbar_widget.dart — undo/redo, digit assistant, check-answer toggle

import 'package:flutter/material.dart';
import '../puzzle/puzzle_engine.dart';
import '../theme/app_theme.dart';

class ToolbarWidget extends StatelessWidget {
  final PuzzleEngine engine;
  final VoidCallback onNewGame;

  const ToolbarWidget({
    super.key,
    required this.engine,
    required this.onNewGame,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ToolBtn(
          icon:    Icons.undo,
          label:   'Undo',
          enabled: engine.hasUndo,
          onTap:   engine.undo,
        ),
        _ToolBtn(
          icon:    Icons.redo,
          label:   'Redo',
          enabled: engine.hasRedo,
          onTap:   engine.redo,
        ),
        _ToolBtn(
          icon:    Icons.auto_fix_high,
          label:   'Assist',
          enabled: true,
          active:  engine.digitAssistant,
          onTap:   engine.toggleDigitAssistant,
        ),
        _ToolBtn(
          icon:    Icons.check_circle_outline,
          label:   'Check',
          enabled: true,
          active:  engine.checkAnswer,
          onTap:   engine.toggleCheckAnswer,
        ),
        _ToolBtn(
          icon:    Icons.refresh,
          label:   'New',
          enabled: !engine.generating,
          onTap:   onNewGame,
        ),
      ],
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool active;
  final VoidCallback onTap;

  const _ToolBtn({
    required this.icon,
    required this.label,
    required this.enabled,
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

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
