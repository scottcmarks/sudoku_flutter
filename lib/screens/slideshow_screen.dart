// slideshow_screen.dart — one-at-a-time view of saved games
//
// Each page mirrors the exact game-screen layout (top bar + grid + keypad)
// with the controls dimmed and non-interactive.  Tapping the page activates
// the game via a Hero transition on the puzzle grid — the grid stays put while
// the live controls appear around it.
//
// Navigation between pages: swipe (PageView), or left/right arrow buttons.

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
import 'game_screen.dart';
import 'new_game_dialog.dart';

class SlideshowScreen extends StatefulWidget {
  final SudokuMapType    mapType;
  final SudokuAdjType    adjType;
  final SudokuDifficulty difficulty;
  final int              initialIndex;

  const SlideshowScreen({
    super.key,
    required this.mapType,
    required this.adjType,
    required this.difficulty,
    required this.initialIndex,
  });

  @override
  State<SlideshowScreen> createState() => _SlideshowScreenState();
}

class _SlideshowScreenState extends State<SlideshowScreen> {
  late PageController _pageController;
  late List<SavedGame> _games;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _syncGames();
    WidgetsBinding.instance.addPostFrameCallback((_) => _warmAround(_currentIndex));
  }

  void _syncGames() {
    final store = context.read<SavedGameStore>();
    _games = store.games
        .where((g) =>
            g.mapType == widget.mapType &&
            g.adjType == widget.adjType &&
            g.difficulty == widget.difficulty)
        .toList();
  }

  /// Pre-warm the thumbnail cache for [index] and its neighbours.
  void _warmAround(int index) {
    final cache = context.read<ThumbnailCache>();
    cache.warm([
      for (int j = index - 1; j <= index + 1; j++)
        if (j >= 0 && j < _games.length) _games[j],
    ]);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _prevPage() {
    _pageController.previousPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _nextPage() {
    _pageController.nextPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final mapLabel = widget.mapType == SudokuMapType.square ? 'Square' : 'Irregular';
    final adjLabel = widget.adjType == SudokuAdjType.xSudoku ? ' X' : '';
    final title    = '$mapLabel$adjLabel — ${widget.difficulty.label}';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_games.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentIndex + 1} / ${_games.length}',
                  style: const TextStyle(fontSize: 14, color: AppTheme.clueText),
                ),
              ),
            ),
        ],
      ),
      body: _games.isEmpty
          ? const _EmptySlideshow()
          : Stack(
              children: [
                // Pages
                PageView.builder(
                  controller: _pageController,
                  itemCount:  _games.length,
                  onPageChanged: (i) {
                    setState(() => _currentIndex = i);
                    _warmAround(i);
                    context.read<SavedGameStore>().setExemplar(
                        widget.mapType, widget.adjType, widget.difficulty,
                        _games[i].uuid);
                  },
                  itemBuilder: (context, i) => _SlidePage(
                    game:       _games[i],
                    onActivate: () => _activateGame(context, i),
                  ),
                ),

                // Left arrow
                if (_currentIndex > 0)
                  Positioned(
                    left: 0, top: 0, bottom: 0,
                    child: Center(
                      child: _NavArrow(
                        icon:    Icons.chevron_left,
                        onTap:   _prevPage,
                      ),
                    ),
                  ),

                // Right arrow
                if (_currentIndex < _games.length - 1)
                  Positioned(
                    right: 0, top: 0, bottom: 0,
                    child: Center(
                      child: _NavArrow(
                        icon:    Icons.chevron_right,
                        onTap:   _nextPage,
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onAdd(context),
        backgroundColor: const Color(0xFF4A3728),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  // ---- Game activation ----

  Future<void> _activateGame(BuildContext context, int index) async {
    final engine    = context.read<PuzzleEngine>();
    final store     = context.read<SavedGameStore>();
    final thumbCache= context.read<ThumbnailCache>();
    final navigator = Navigator.of(context);
    final game      = _games[index];
    final heroTag   = 'slide_grid_${game.uuid}';

    final ffi = PuzzleFFI();
    ffi.restoreBytes(game.puzzleBytes);
    ffi.setupLoaded(game.mapType, game.adjType);
    engine.lastMapType    = game.mapType;
    engine.lastAdjType    = game.adjType;
    engine.lastDifficulty = game.difficulty;
    engine.loadFromFFI(ffi, colorMap: game.colorMap);

    await navigator.push(
      MaterialPageRoute(builder: (_) => GameScreen(heroTag: heroTag)),
    );

    if (!mounted) return;

    // Update the album entry in place if the game type is unchanged.
    // If the user generated a new game of a different type from the win overlay,
    // save it under a fresh UUID in its correct category instead.
    final bytes = engine.snapshotBytes();
    if (bytes != null) {
      final sameGame = engine.lastMapType  == game.mapType &&
                       engine.lastAdjType  == game.adjType &&
                       engine.lastDifficulty == game.difficulty;
      final updated = SavedGame(
        uuid:          sameGame ? game.uuid : const Uuid().v4(),
        created:       sameGame ? game.created : DateTime.now(),
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
      );
      await store.save(updated);
      if (mounted) {
        thumbCache.evict(updated.uuid);
        if (sameGame) setState(() => _games[index] = updated);
      }
    }
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
      queueStore.prioritize(widget.mapType, widget.adjType, widget.difficulty);
      while (entry == null && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        entry = queueStore.dequeue(widget.mapType, widget.adjType, widget.difficulty);
      }
      if (!mounted) return;
    }
    if (entry == null) return;

    final ffi = PuzzleFFI();
    ffi.restoreBytes(entry.puzzleBytes);
    ffi.setupLoaded(entry.mapType, entry.adjType);
    engine.lastMapType    = entry.mapType;
    engine.lastAdjType    = entry.adjType;
    engine.lastDifficulty = entry.difficulty;
    engine.loadFromFFI(ffi, colorMap: entry.colorMap);

    final newUuid      = const Uuid().v4();
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
    if (mounted) {
      _syncGames();
      setState(() {});
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
      await store.save(SavedGame(
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
    if (mounted) {
      _syncGames();
      setState(() {});
    }
  }
}

// ---------------------------------------------------------------------------
// One slide: mirrors the game-screen layout with dimmed inactive controls.
// The puzzle grid is wrapped in a Hero so it stays put when transitioning
// to/from the live GameScreen.
// ---------------------------------------------------------------------------

class _SlidePage extends StatelessWidget {
  final SavedGame    game;
  final VoidCallback onActivate;

  const _SlidePage({required this.game, required this.onActivate});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onActivate,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Hero(
            tag: 'slide_grid_${game.uuid}',
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.groupBorder, width: 2),
                color: AppTheme.bg,
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: CachedThumbnail(game: game),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Colors.white70, size: 28),
      ),
    );
  }
}

class _EmptySlideshow extends StatelessWidget {
  const _EmptySlideshow();

  @override
  Widget build(BuildContext context) {
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
}
