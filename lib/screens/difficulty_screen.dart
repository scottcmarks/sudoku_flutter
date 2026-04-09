// difficulty_screen.dart — list of 6 difficulties for one map type

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/puzzle_queue_store.dart';
import '../models/saved_game.dart';
import '../models/thumbnail_cache.dart';
import '../puzzle/puzzle_types.dart';
import '../theme/app_theme.dart';
import 'game_list_screen.dart';

class DifficultyScreen extends StatelessWidget {
  final SudokuMapType mapType;
  final SudokuAdjType adjType;

  const DifficultyScreen({
    super.key,
    required this.mapType,
    required this.adjType,
  });

  @override
  Widget build(BuildContext context) {
    final mapLabel = mapType == SudokuMapType.square ? 'Square' : 'Irregular';
    final adjLabel = adjType == SudokuAdjType.xSudoku ? ' X' : '';
    final title    = '$mapLabel$adjLabel Sudoku';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: Text(title)),
      body: Consumer2<SavedGameStore, PuzzleQueueStore>(
        builder: (context, savedStore, queueStore, _) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: SudokuDifficulty.values.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final diff   = SudokuDifficulty.values[i];
              final games  = savedStore.games.where((g) =>
                  g.mapType == mapType &&
                  g.adjType == adjType &&
                  g.difficulty == diff).toList();
              final saved  = games.length;
              final queued = queueStore.depth(mapType, adjType, diff);
              final latest = savedStore.exemplarFor(mapType, adjType, diff);
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: latest != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: CachedThumbnail(game: latest),
                        ),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.keypadBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.grid_4x4,
                            size: 24, color: AppTheme.gridLine),
                      ),
                title: Text(diff.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('$saved saved'),
                trailing: _QueueBadge(queued),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GameListScreen(
                      mapType:    mapType,
                      adjType:    adjType,
                      difficulty: diff,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _QueueBadge extends StatelessWidget {
  final int count;
  const _QueueBadge(this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0 ? AppTheme.clueCell : AppTheme.keypadBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count > 0 ? '$count ready' : 'generating…',
        style: TextStyle(
          fontSize: 12,
          color: count > 0 ? AppTheme.clueText : AppTheme.gridLine,
        ),
      ),
    );
  }
}
