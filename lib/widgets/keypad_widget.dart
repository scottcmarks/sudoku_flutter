// keypad_widget.dart — digit entry (1-9 + erase) with small-mode toggle

import 'package:flutter/material.dart';
import '../puzzle/puzzle_engine.dart';
import '../theme/app_theme.dart';

class KeypadWidget extends StatelessWidget {
  final PuzzleEngine engine;

  const KeypadWidget({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    final maxed = engine.maxedDigits;
    final inSmallMode = _selectedCellInSmallMode();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mode toggle: pencil / pen
        _ModeToggle(engine: engine),
        const SizedBox(height: 8),
        // 3-row keypad
        for (int row = 0; row < 3; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int col = 0; col < 3; col++) ...[
                  if (col > 0) const SizedBox(width: 6),
                  _DigitKey(
                    digit:      row * 3 + col + 1,
                    maxed:      maxed[row * 3 + col + 1],
                    smallMode:  inSmallMode,
                    onTap:      () => _onDigit(row * 3 + col + 1, inSmallMode),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 6),
        // Erase button
        _EraseKey(onTap: () => _onErase(inSmallMode)),
      ],
    );
  }

  bool _selectedCellInSmallMode() {
    final sel = engine.selectedOffset;
    if (sel < 0) return false;
    return engine.cell(sel)?.smallMode ?? false;
  }

  void _onDigit(int digit, bool smallMode) {
    final sel = engine.selectedOffset;
    if (sel < 0) return;
    final c = engine.cell(sel);
    if (c == null || c.isClue) return;

    if (smallMode) {
      engine.toggleElimBit(sel, digit);
    } else {
      // Toggle: tapping the same digit clears it
      final newDigit = (c.userAnswer == digit) ? 0 : digit;
      engine.setUserAnswer(sel, newDigit);
    }
  }

  void _onErase(bool smallMode) {
    final sel = engine.selectedOffset;
    if (sel < 0) return;
    final c = engine.cell(sel);
    if (c == null || c.isClue) return;

    if (smallMode) {
      engine.toggleElimBit(sel, 0); // clear all bits
    } else {
      engine.clearUserAnswer(sel);
    }
  }
}

class _ModeToggle extends StatelessWidget {
  final PuzzleEngine engine;
  const _ModeToggle({required this.engine});

  @override
  Widget build(BuildContext context) {
    final inSmallMode = _selectedSmallMode();
    return GestureDetector(
      onTap: () {
        final sel = engine.selectedOffset;
        if (sel >= 0) engine.toggleSmallMode(sel);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: inSmallMode ? AppTheme.pencilText : AppTheme.keypadBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.gridLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              inSmallMode ? Icons.edit : Icons.create,
              size: 16,
              color: inSmallMode ? Colors.white : AppTheme.clueText,
            ),
            const SizedBox(width: 6),
            Text(
              inSmallMode ? 'Pencil' : 'Pen',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: inSmallMode ? Colors.white : AppTheme.clueText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _selectedSmallMode() {
    final sel = engine.selectedOffset;
    if (sel < 0) return false;
    return engine.cell(sel)?.smallMode ?? false;
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
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: maxed ? null : onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Center(
            child: Text(
              '$digit',
              style: TextStyle(
                fontSize: smallMode ? 18 : 24,
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
      ),
    );
  }
}

class _EraseKey extends StatelessWidget {
  final VoidCallback onTap;
  const _EraseKey({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.keypadBg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: const SizedBox(
          width: 80,
          height: 44,
          child: Center(
            child: Icon(Icons.backspace_outlined, color: AppTheme.clueText, size: 22),
          ),
        ),
      ),
    );
  }
}
