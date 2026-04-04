// album_screen.dart — MHAlbum equivalent: grid of saved games with thumbnails
//
// Each card shows a miniature puzzle grid (CustomPainter) + metadata.
// Tapping a card loads that game into the PuzzleEngine and opens GameScreen.
// The FAB starts a new game.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/saved_game.dart';
import '../puzzle/puzzle_engine.dart';
import '../puzzle/puzzle_ffi.dart';
import '../puzzle/puzzle_types.dart';
import '../theme/app_theme.dart';
import 'game_screen.dart';
import 'new_game_dialog.dart';

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SavedGameStore>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Sudoku X4')),
      body: Consumer<SavedGameStore>(
        builder: (context, store, _) {
          if (store.games.isEmpty) {
            return const _EmptyAlbum();
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              crossAxisSpacing:   12,
              mainAxisSpacing:    12,
              childAspectRatio:   0.75,
            ),
            itemCount: store.games.length,
            itemBuilder: (context, i) => _GameCard(
              game:     store.games[i],
              onTap:    () => _openGame(context, store.games[i]),
              onDelete: () => _deleteGame(context, store, store.games[i].uuid),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newGame(context),
        icon:  const Icon(Icons.add),
        label: const Text('New Game'),
        backgroundColor: const Color(0xFF4A3728),
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _newGame(BuildContext context) async {
    final engine = context.read<PuzzleEngine>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => NewGameDialog(engine: engine),
    );
    if (!mounted) return;
    if (ok == true && engine.isLoaded) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GameScreen()),
      );
      if (!mounted) return;
      _saveCurrentGame(context, engine);
    }
  }

  Future<void> _openGame(BuildContext context, SavedGame game) async {
    final engine = context.read<PuzzleEngine>();
    final ffi = PuzzleFFI();
    ffi.restoreBytes(game.puzzleBytes);
    engine.lastMapType    = game.mapType;
    engine.lastAdjType    = game.adjType;
    engine.lastDifficulty = game.difficulty;
    engine.loadFromFFI(ffi, colorMap: game.colorMap);

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
    if (!mounted) return;
    _saveCurrentGame(context, engine);
  }

  void _saveCurrentGame(BuildContext context, PuzzleEngine engine) {
    if (!engine.isLoaded) return;
    final store = context.read<SavedGameStore>();
    final bytes = engine.snapshotBytes();
    if (bytes == null) return;
    final game = SavedGame(
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
    );
    store.save(game);
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
              Navigator.of(context).pop();
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorText)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Game card — thumbnail + metadata
// ---------------------------------------------------------------------------

class _GameCard extends StatelessWidget {
  final SavedGame    game;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _GameCard({
    required this.game,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail
            Expanded(
              child: Container(
                color: AppTheme.bg,
                child: CustomPaint(
                  painter: _PuzzleThumbnailPainter(game: game),
                ),
              ),
            ),
            // Metadata strip
            Container(
              color: AppTheme.keypadBg,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        game.difficulty.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.clueText,
                        ),
                      ),
                      const Spacer(),
                      if (game.userHasWon)
                        const Icon(Icons.check_circle, size: 14, color: AppTheme.winGold),
                    ],
                  ),
                  Text(
                    game.distance == 0
                        ? 'Solved'
                        : '${game.distance} remaining',
                    style: TextStyle(
                      fontSize: 11,
                      color: game.distance == 0 ? AppTheme.winGold : AppTheme.gridLine,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thumbnail painter — renders the puzzle grid miniaturized
// ---------------------------------------------------------------------------

class _PuzzleThumbnailPainter extends CustomPainter {
  final SavedGame game;
  _PuzzleThumbnailPainter({required this.game});

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 9;
    final bytes = game.puzzleBytes;

    // We can't call FFI in a painter without the handle, so we draw a
    // simplified representation from the raw bytes.
    // PUZZLE_CELL layout offset for mask and user_answer:
    //   [0..4]: indices[5]    = 5 ints = 20 bytes
    //   [5..9]: offsets[5]    = 5 ints = 20 bytes
    //   [10]:   solution BITS = 4 bytes  → offset 40
    //   [11]:   mask int      = 4 bytes  → offset 44
    //   [12]:   elim_bits     = 4 bytes  → offset 48
    //   [13]:   user_answer   = 4 bytes  → offset 52
    //   ...
    final cellBytes = bytes.lengthInBytes ~/ 81;

    final cluePaint  = Paint()..color = AppTheme.clueCell;
    final userPaint  = Paint()..color = AppTheme.neighborCell;
    final emptyPaint = Paint()..color = AppTheme.bg;
    final linePaint  = Paint()
      ..color = AppTheme.gridLine
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    final groupPaint = Paint()
      ..color = AppTheme.groupBorder
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        final offset = row * 9 + col;
        final base   = offset * cellBytes;
        if (base + 56 > bytes.length) continue;

        // Read mask (4 bytes little-endian at offset 44 into cell)
        final maskOffset = base + 44;
        final mask = maskOffset + 3 < bytes.length
            ? bytes[maskOffset] |
              (bytes[maskOffset + 1] << 8) |
              (bytes[maskOffset + 2] << 16) |
              (bytes[maskOffset + 3] << 24)
            : 0;

        // Read user_answer at offset 52
        final uaOffset = base + 52;
        final ua = uaOffset + 3 < bytes.length
            ? bytes[uaOffset] |
              (bytes[uaOffset + 1] << 8) |
              (bytes[uaOffset + 2] << 16) |
              (bytes[uaOffset + 3] << 24)
            : 0;

        final rect = Rect.fromLTWH(
          col * cellSize, row * cellSize, cellSize, cellSize);

        canvas.drawRect(
          rect,
          mask != 0 ? cluePaint : ua != 0 ? userPaint : emptyPaint,
        );
        canvas.drawRect(rect, linePaint);

        // Draw group borders at 3×3 boundaries for square puzzles
        if (game.mapType == SudokuMapType.square) {
          if (col % 3 == 2 && col < 8) {
            canvas.drawLine(
              Offset((col + 1) * cellSize, row * cellSize),
              Offset((col + 1) * cellSize, (row + 1) * cellSize),
              groupPaint,
            );
          }
          if (row % 3 == 2 && row < 8) {
            canvas.drawLine(
              Offset(col * cellSize, (row + 1) * cellSize),
              Offset((col + 1) * cellSize, (row + 1) * cellSize),
              groupPaint,
            );
          }
        }
      }
    }

    // Outer border
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      groupPaint,
    );
  }

  @override
  bool shouldRepaint(_PuzzleThumbnailPainter old) => old.game.uuid != game.uuid;
}

class _EmptyAlbum extends StatelessWidget {
  const _EmptyAlbum();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.grid_4x4, size: 72, color: AppTheme.gridLine),
          const SizedBox(height: 16),
          const Text('No saved games', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Tap + New Game to start', style: TextStyle(color: AppTheme.gridLine)),
        ],
      ),
    );
  }
}
