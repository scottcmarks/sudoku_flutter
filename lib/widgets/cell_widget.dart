// cell_widget.dart — renders one 9×9 cell

import 'package:flutter/material.dart';
import '../puzzle/puzzle_types.dart';
import '../puzzle/puzzle_engine.dart';
import '../theme/app_theme.dart';

class CellWidget extends StatelessWidget {
  final int offset;
  final PuzzleEngine engine;
  final bool isSelected;
  final bool isNeighbor;
  final bool isSameDigit;
  final bool showErrors;
  final VoidCallback onTap;

  const CellWidget({
    super.key,
    required this.offset,
    required this.engine,
    required this.isSelected,
    required this.isNeighbor,
    required this.isSameDigit,
    required this.showErrors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = engine.cell(offset);
    if (c == null) return const SizedBox.shrink();

    final bg = _backgroundColor(c);
    final borderSide = BorderSide(color: AppTheme.gridLine, width: 0.5);
    // Thicker borders on group boundaries
    final rightBorder = engine.sameGroupRight(offset)
        ? borderSide
        : BorderSide(color: AppTheme.groupBorder, width: 1.5);
    final bottomBorder = engine.sameGroupBelow(offset)
        ? borderSide
        : BorderSide(color: AppTheme.groupBorder, width: 1.5);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            right:  rightBorder,
            bottom: bottomBorder,
            left:   BorderSide.none,
            top:    BorderSide.none,
          ),
        ),
        child: c.smallMode ? _SmallDigitsContent(c: c) : _LargeDigitContent(c: c, showErrors: showErrors),
      ),
    );
  }

  Color _backgroundColor(CellData c) {
    if (isSelected)  return AppTheme.selectedCell;
    if (isSameDigit) return AppTheme.sameDigitCell;
    if (isNeighbor)  return AppTheme.neighborCell;
    if (c.isClue)    return AppTheme.clueCell;
    return AppTheme.bg;
  }
}

// Large digit (main answer) display
class _LargeDigitContent extends StatelessWidget {
  final CellData c;
  final bool showErrors;
  const _LargeDigitContent({required this.c, required this.showErrors});

  @override
  Widget build(BuildContext context) {
    if (c.userAnswer == 0 && !c.isClue) return const SizedBox.shrink();

    final digit = c.isClue ? c.solution : c.userAnswer;
    final isError = showErrors && !c.isClue && c.userAnswer != 0 && c.userAnswer != c.solution;

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$digit',
          style: TextStyle(
            fontSize: 28,
            fontWeight: c.isClue ? FontWeight.w700 : FontWeight.w400,
            color: c.isClue
                ? AppTheme.clueText
                : isError
                    ? AppTheme.errorText
                    : AppTheme.userText,
          ),
        ),
      ),
    );
  }
}

// Small digit (pencil marks) display — 3×3 grid of candidate digits
class _SmallDigitsContent extends StatelessWidget {
  final CellData c;
  const _SmallDigitsContent({required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(1),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
        itemCount: 9,
        itemBuilder: (_, i) {
          final digit = i + 1;
          final isCandidate = c.hasCandidate(digit);
          return Center(
            child: isCandidate
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$digit',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.pencilText,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
