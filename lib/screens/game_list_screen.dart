// game_list_screen.dart — grid of saved games for one (mapType, adjType, difficulty)
//
// Tapping a card opens SlideshowScreen at that index.
// FAB behaviour:
//   Normal mode: dequeue a pre-generated puzzle, save it, play it immediately.
//   Manual mode: show NewGameDialog (power-user toggle in Settings).
//   Empty queue: show spinner, call prioritize(), await next enqueue.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/app_settings.dart';
import '../models/puzzle_queue_store.dart';
import '../models/saved_game.dart';
import '../models/thumbnail_cache.dart';
import '../puzzle/puzzle_engine.dart';
import '../puzzle/puzzle_ffi.dart';
import '../puzzle/puzzle_types.dart';
import '../theme/app_theme.dart';
import '../widgets/game_card.dart';
import 'game_screen.dart';
import 'new_game_dialog.dart';
import 'slideshow_screen.dart';

class GameListScreen extends StatefulWidget {
  final SudokuMapType    mapType;
  final SudokuAdjType    adjType;
  final SudokuDifficulty difficulty;

  const GameListScreen({
    super.key,
    required this.mapType,
    required this.adjType,
    required this.difficulty,
  });

  @override
  State<GameListScreen> createState() => _GameListScreenState();
}

class _GameListScreenState extends State<GameListScreen> {
  bool _waitingForQueue = false;

  @override
  Widget build(BuildContext context) {
    final mapLabel = widget.mapType == SudokuMapType.square ? 'Square' : 'Irregular';
    final adjLabel = widget.adjType == SudokuAdjType.xSudoku ? ' X' : '';
    final title    = '$mapLabel$adjLabel — ${widget.difficulty.label}';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: Text(title)),
      body: Consumer<SavedGameStore>(
        builder: (context, store, _) {
          final games = store.games
              .where((g) =>
                  g.mapType == widget.mapType &&
                  g.adjType == widget.adjType &&
                  g.difficulty == widget.difficulty)
              .toList();

          if (games.isEmpty && !_waitingForQueue) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grid_4x4, size: 72, color: AppTheme.gridLine),
                  SizedBox(height: 16),
                  Text('No games yet', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 8),
                  Text('Tap + to start one',
                      style: TextStyle(color: AppTheme.gridLine)),
                ],
              ),
            );
          }

          return Stack(
            children: [
              GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,   // square cards
                ),
                itemCount: games.length,
                itemBuilder: (context, i) => GameCard(
                  game:     games[i],
                  onTap:    () => _openSlideshow(context, games, i),
                  onDelete: () => _deleteGame(context, store, games[i].uuid),
                ),
              ),
              if (_waitingForQueue)
                const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Generating puzzle…'),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _onAdd(context),
        icon: _waitingForQueue
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add),
        label: const Text('New Game'),
        backgroundColor: const Color(0xFF4A3728),
        foregroundColor: Colors.white,
      ),
    );
  }

  // ---- Navigation ----

  Future<void> _openSlideshow(
      BuildContext context, List<SavedGame> games, int index) async {
    context.read<SavedGameStore>().setExemplar(
        widget.mapType, widget.adjType, widget.difficulty, games[index].uuid);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SlideshowScreen(
          mapType:      widget.mapType,
          adjType:      widget.adjType,
          difficulty:   widget.difficulty,
          initialIndex: index,
        ),
      ),
    );
    // Store updates propagate via ChangeNotifier; no manual refresh needed.
  }

  // ---- FAB ----

  Future<void> _onAdd(BuildContext context) async {
    final settings = context.read<AppSettings>();
    if (settings.manualGeneration) {
      await _newGameManual(context);
    } else {
      await _dequeueAndPlay(context);
    }
  }

  Future<void> _dequeueAndPlay(BuildContext context) async {
    final queueStore = context.read<PuzzleQueueStore>();
    final engine     = context.read<PuzzleEngine>();
    final store      = context.read<SavedGameStore>();
    final navigator  = Navigator.of(context);
    var entry = queueStore.dequeue(widget.mapType, widget.adjType, widget.difficulty);

    if (entry == null) {
      setState(() => _waitingForQueue = true);
      queueStore.prioritize(widget.mapType, widget.adjType, widget.difficulty);
      while (entry == null && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        entry = queueStore.dequeue(widget.mapType, widget.adjType, widget.difficulty);
      }
      if (!mounted) return;
      setState(() => _waitingForQueue = false);
    }
    if (entry == null) return;

    final ffi = PuzzleFFI();
    ffi.restoreBytes(entry.puzzleBytes);
    ffi.setupLoaded(entry.mapType, entry.adjType);
    engine.lastMapType    = entry.mapType;
    engine.lastAdjType    = entry.adjType;
    engine.lastDifficulty = entry.difficulty;
    engine.loadFromFFI(ffi, colorMap: entry.colorMap);

    // Save with a stable UUID before entering the game.
    final newUuid = const Uuid().v4();
    final initialBytes = engine.snapshotBytes();
    if (initialBytes == null) return;
    await store.save(SavedGame(
      uuid:          newUuid,
      created:       DateTime.now(),
      difficulty:    entry.difficulty,
      mapType:       entry.mapType,
      adjType:       entry.adjType,
      userHasWon:    false,
      distance:      81,
      puzzleBytes:   initialBytes,
      colorMap:      entry.colorMap,
      mapTypeRaw:    entry.mapType.value,
      adjTypeRaw:    entry.adjType.value,
      difficultyRaw: entry.difficulty.value,
    ));
    if (!mounted) return;

    await navigator.push(MaterialPageRoute(builder: (_) => const GameScreen()));
    if (!mounted) return;

    // If the user generated a new game of a different type/difficulty from the
    // win overlay, save it under a fresh UUID so it lands in the correct album
    // category rather than overwriting the original entry.
    final bytes = engine.snapshotBytes();
    if (bytes != null) {
      final sameGame = engine.lastMapType  == entry.mapType &&
                       engine.lastAdjType  == entry.adjType &&
                       engine.lastDifficulty == entry.difficulty;
      store.save(SavedGame(
        uuid:          sameGame ? newUuid : const Uuid().v4(),
        created:       DateTime.now(),
        difficulty:    engine.lastDifficulty,
        mapType:       engine.lastMapType,
        adjType:       engine.lastAdjType,
        userHasWon:    engine.userHasWon,
        distance:      engine.distance,
        puzzleBytes:   bytes,
        colorMap:      engine.colorMap,
        mapTypeRaw:    engine.lastMapType.value,
        adjTypeRaw:    engine.lastAdjType.value,
        difficultyRaw: engine.lastDifficulty.value,
      ));
    }
  }

  Future<void> _newGameManual(BuildContext context) async {
    final engine    = context.read<PuzzleEngine>();
    final store     = context.read<SavedGameStore>();
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => NewGameDialog(engine: engine),
    );
    if (!mounted || ok != true || !engine.isLoaded) return;

    await navigator.push(MaterialPageRoute(builder: (_) => const GameScreen()));
    if (!mounted) return;

    final bytes = engine.snapshotBytes();
    if (bytes != null) {
      store.save(SavedGame(
        uuid:          const Uuid().v4(),
        created:       DateTime.now(),
        difficulty:    engine.lastDifficulty,
        mapType:       engine.lastMapType,
        adjType:       engine.lastAdjType,
        userHasWon:    engine.userHasWon,
        distance:      engine.distance,
        puzzleBytes:   bytes,
        colorMap:      engine.colorMap,
        mapTypeRaw:    engine.lastMapType.value,
        adjTypeRaw:    engine.lastAdjType.value,
        difficultyRaw: engine.lastDifficulty.value,
      ));
    }
  }

  void _deleteGame(BuildContext context, SavedGameStore store, String uuid) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete game?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              store.delete(uuid);
              context.read<ThumbnailCache>().evict(uuid);
              Navigator.of(context).pop();
            },
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.errorText)),
          ),
        ],
      ),
    );
  }
}
