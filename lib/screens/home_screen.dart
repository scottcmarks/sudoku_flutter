// home_screen.dart — root screen: stripe list of puzzle types
//
// Tapping a stripe opens DifficultyScreen for that (mapType, adjType).
// The gear icon opens SettingsScreen.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/puzzle_queue_store.dart';
import '../models/saved_game.dart';
import '../models/thumbnail_cache.dart';
import '../puzzle/puzzle_types.dart';
import '../theme/app_theme.dart';
import 'difficulty_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final savedStore = context.read<SavedGameStore>();
      final queueStore = context.read<PuzzleQueueStore>();
      await savedStore.load();
      await queueStore.load();
      await queueStore.startWorkers();
      if (savedStore.games.isEmpty && mounted) {
        await queueStore.seedAlbum(savedStore);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Sudoku X4'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Consumer2<SavedGameStore, PuzzleQueueStore>(
        builder: (context, savedStore, queueStore, _) {
          const types = [
            (mapType: SudokuMapType.square,    adjType: SudokuAdjType.normal,   label: 'Square'),
            (mapType: SudokuMapType.square,    adjType: SudokuAdjType.xSudoku,  label: 'Square X'),
            (mapType: SudokuMapType.irregular, adjType: SudokuAdjType.normal,   label: 'Irregular'),
            (mapType: SudokuMapType.irregular, adjType: SudokuAdjType.xSudoku,  label: 'Irregular X'),
          ];
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: types.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final t = types[i];
              final savedCount = savedStore.games
                  .where((g) => g.mapType == t.mapType && g.adjType == t.adjType)
                  .length;
              final queueCount = SudokuDifficulty.values.fold<int>(
                0,
                (sum, d) => sum + queueStore.depth(t.mapType, t.adjType, d),
              );
              final latestGame = savedStore.typeExemplarFor(t.mapType, t.adjType);
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: _Thumbnail(game: latestGame),
                title: Text(
                  t.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppTheme.clueText),
                ),
                subtitle: Text(
                  '$savedCount game${savedCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (queueCount > 0)
                      Text(
                        '$queueCount ready',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.clueText),
                      ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: AppTheme.gridLine),
                  ],
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DifficultyScreen(
                      mapType: t.mapType,
                      adjType: t.adjType,
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

// ---------------------------------------------------------------------------
// Thumbnail: 56×56 puzzle preview, or placeholder if no game yet
// ---------------------------------------------------------------------------

class _Thumbnail extends StatelessWidget {
  final SavedGame? game;
  const _Thumbnail({required this.game});

  @override
  Widget build(BuildContext context) {
    if (game == null) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.keypadBg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.grid_4x4, size: 28, color: AppTheme.gridLine),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 56,
        height: 56,
        child: CachedThumbnail(game: game!),
      ),
    );
  }
}
