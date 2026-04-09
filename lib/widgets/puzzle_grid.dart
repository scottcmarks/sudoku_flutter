// puzzle_grid.dart — 9×9 grid of CellWidgets with outer border and group shading

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../puzzle/puzzle_engine.dart';
import '../puzzle/puzzle_types.dart';
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
        child: Stack(
          children: [
            GridView.builder(
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
            if (engine.lastAdjType == SudokuAdjType.xSudoku)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _XDiagonalPainter()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// X diagonal overlay — drawn for xSudoku adjacency games
// ---------------------------------------------------------------------------

class _XDiagonalPainter extends CustomPainter {
  const _XDiagonalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Stroke width = cell diagonal = (W/9) * √2 so the band exactly covers
    // the 9 diagonal cells without spilling into adjacent cells.
    // clipRect trims the stroke ends at the grid boundary.
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = const Color(0x30C89040) // semi-transparent warm gold
      ..strokeWidth = size.width * math.sqrt2 / 9
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.stroke;

    // Main diagonal: top-left → bottom-right
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
    // Anti-diagonal: top-right → bottom-left
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(_XDiagonalPainter old) => false;
}
