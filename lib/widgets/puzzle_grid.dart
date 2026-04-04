// puzzle_grid.dart — 9×9 grid of CellWidgets with outer border and group shading

import 'package:flutter/material.dart';
import '../puzzle/puzzle_engine.dart';
import '../theme/app_theme.dart';
import 'cell_widget.dart';

class PuzzleGrid extends StatelessWidget {
  final PuzzleEngine engine;

  const PuzzleGrid({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    final sel = engine.selectedOffset;
    final selCell = sel >= 0 ? engine.cell(sel) : null;
    final selDigit = selCell?.userAnswer ?? (selCell?.isClue == true ? selCell?.solution : null);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.groupBorder, width: 2),
        color: AppTheme.bg,
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 9,
          ),
          itemCount: 81,
          itemBuilder: (context, offset) {
            final c = engine.cell(offset);
            final isSelected  = offset == sel;
            final isNeighbor  = !isSelected && sel >= 0 && engine.areNeighbors(offset, sel);
            final isSameDigit = selDigit != null &&
                selDigit > 0 &&
                !isSelected &&
                (c?.userAnswer == selDigit || (c?.isClue == true && c?.solution == selDigit));

            return CellWidget(
              offset:     offset,
              engine:     engine,
              isSelected:  isSelected,
              isNeighbor:  isNeighbor,
              isSameDigit: isSameDigit,
              showErrors:  engine.checkAnswer,
              onTap:      () => engine.selectCell(offset),
            );
          },
        ),
      ),
    );
  }
}
