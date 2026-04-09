// thumbnail_cache.dart — LRU cache of rasterised puzzle thumbnails
//
// ThumbnailCache renders each SavedGame to a ui.Image once and keeps up to
// _maxEntries images in memory (LRU eviction). Discarded images are recreated
// on the next access, so the cache is always safe to shrink.
//
// CachedThumbnail is the widget counterpart: it resolves the image from the
// cache (or triggers a render) and calls setState when the image is ready.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../puzzle/puzzle_ffi.dart';
import '../theme/app_theme.dart';
import 'saved_game.dart';

// ---------------------------------------------------------------------------
// Cache
// ---------------------------------------------------------------------------

class ThumbnailCache extends ChangeNotifier {
  /// Physical pixel side-length used when rasterising. High enough for all
  /// display sizes; RawImage scales to fit whatever logical size is needed.
  static const int renderSize = 512;

  static const int _maxEntries = 60;

  /// Insertion-ordered map — newest entry at the end, so eviction removes
  /// _cache.keys.first (the least-recently used entry).
  final Map<String, ui.Image> _cache = {};

  /// In-flight renders, coalesced by uuid.
  final Map<String, Future<ui.Image>> _pending = {};

  // ---- Public API ----

  /// Synchronous hit — null if not yet rendered.
  ui.Image? imageFor(String uuid) => _cache[uuid];

  /// Returns the cached image, or renders it now if not present.
  /// Multiple simultaneous callers for the same uuid share one render.
  Future<ui.Image> get(SavedGame game) {
    final hit = _cache[game.uuid];
    if (hit != null) {
      // Refresh LRU position.
      _cache
        ..remove(game.uuid)
        ..[game.uuid] = hit;
      return Future.value(hit);
    }

    if (_pending.containsKey(game.uuid)) return _pending[game.uuid]!;

    final future = _renderGame(game).then((img) {
      _pending.remove(game.uuid);
      while (_cache.length >= _maxEntries) {
        _cache.remove(_cache.keys.first);
      }
      _cache[game.uuid] = img;
      notifyListeners();
      return img;
    });
    _pending[game.uuid] = future;
    return future;
  }

  /// Pre-warm images for [games] — fire-and-forget. Call before a swipe
  /// lands so the image is already in cache when the page becomes visible.
  void warm(Iterable<SavedGame> games) {
    for (final g in games) {
      if (!_cache.containsKey(g.uuid) && !_pending.containsKey(g.uuid)) {
        get(g);
      }
    }
  }

  /// Discard one entry. Call when the corresponding SavedGame is deleted.
  void evict(String uuid) => _cache.remove(uuid);
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class CachedThumbnail extends StatefulWidget {
  final SavedGame game;
  const CachedThumbnail({super.key, required this.game});

  @override
  State<CachedThumbnail> createState() => _CachedThumbnailState();
}

class _CachedThumbnailState extends State<CachedThumbnail> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _resolveImage(widget.game);
  }

  @override
  void didUpdateWidget(CachedThumbnail old) {
    super.didUpdateWidget(old);
    // Re-resolve if the game object changed (new UUID or same UUID but cache
    // was evicted because the puzzle bytes changed after a play session).
    final cache = context.read<ThumbnailCache>();
    if (old.game.uuid != widget.game.uuid ||
        cache.imageFor(widget.game.uuid) == null) {
      _resolveImage(widget.game);
    }
  }

  void _resolveImage(SavedGame game) {
    final cache  = context.read<ThumbnailCache>();
    final cached = cache.imageFor(game.uuid);
    if (cached != null) {
      _image = cached;
      return;
    }
    _image = null;
    final uuid = game.uuid;
    cache.get(game).then((img) {
      if (mounted && widget.game.uuid == uuid) {
        setState(() => _image = img);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) return const ColoredBox(color: Color(0xFFF5F0E8));
    return RawImage(image: _image, fit: BoxFit.contain);
  }
}

// ---------------------------------------------------------------------------
// Renderer — runs on the main isolate; the Canvas work is trivial (9×9 grid)
// ---------------------------------------------------------------------------

Future<ui.Image> _renderGame(SavedGame game) async {
  const size  = ThumbnailCache.renderSize;
  final fSize = size.toDouble();

  // TODO: if rendering feels sluggish (81 FFI getCell calls × concurrent renders),
  // profile here first. Options: cache CellData snapshots in SavedGame, or move
  // rendering to a Dart isolate (requires passing bytes, not the FFI handle).
  final ffi = PuzzleFFI();
  ffi.restoreBytes(game.puzzleBytes);
  final cells = List.generate(81, (i) => ffi.getCell(i));
  ffi.dispose();

  final recorder = ui.PictureRecorder();
  final canvas   = ui.Canvas(recorder);

  final cellSize = fSize / 9;

  final thinPaint = Paint()
    ..color       = AppTheme.gridLine
    ..strokeWidth = 1.0
    ..style       = PaintingStyle.stroke;
  final thickPaint = Paint()
    ..color       = AppTheme.groupBorder
    ..strokeWidth = 3.0
    ..style       = PaintingStyle.stroke;

  // Draw cell backgrounds.
  for (int i = 0; i < 81; i++) {
    final row = i ~/ 9;
    final col = i % 9;
    final cell = cells[i];
    final bgColor = AppTheme.groupColors[game.colorMap[cell.group].clamp(0, 3)];
    canvas.drawRect(
      Rect.fromLTWH(col * cellSize, row * cellSize, cellSize, cellSize),
      Paint()..color = bgColor,
    );
  }

  // Draw internal grid lines (thin = same group, thick = different group).
  for (int i = 0; i < 81; i++) {
    final row = i ~/ 9;
    final col = i % 9;

    // Right border.
    if (col < 8) {
      final sameGroup = cells[i].group == cells[i + 1].group;
      canvas.drawLine(
        Offset((col + 1) * cellSize, row * cellSize),
        Offset((col + 1) * cellSize, (row + 1) * cellSize),
        sameGroup ? thinPaint : thickPaint,
      );
    }
    // Bottom border.
    if (row < 8) {
      final sameGroup = cells[i].group == cells[i + 9].group;
      canvas.drawLine(
        Offset(col * cellSize, (row + 1) * cellSize),
        Offset((col + 1) * cellSize, (row + 1) * cellSize),
        sameGroup ? thinPaint : thickPaint,
      );
    }
  }

  // Draw digit text for clues and user answers.
  final fontSize = cellSize * 0.55;
  for (int i = 0; i < 81; i++) {
    final row  = i ~/ 9;
    final col  = i % 9;
    final cell = cells[i];

    final int digit;
    final ui.Color textColor;
    final ui.FontStyle fontStyle;

    if (cell.mask != 0) {
      digit     = cell.solution;
      textColor = AppTheme.clueText;
      fontStyle = ui.FontStyle.normal;
    } else if (cell.userAnswer > 0) {
      digit     = cell.userAnswer;
      textColor = AppTheme.userText;
      fontStyle = ui.FontStyle.italic;
    } else {
      continue;
    }

    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign:    TextAlign.center,
      fontStyle:    fontStyle,
      fontWeight:   cell.mask != 0 ? FontWeight.bold : FontWeight.normal,
      fontSize:     fontSize,
    ))
      ..pushStyle(ui.TextStyle(color: textColor))
      ..addText(digit.toString());
    final para = pb.build()
      ..layout(ui.ParagraphConstraints(width: cellSize));

    final dx = col * cellSize;
    final dy = row * cellSize + (cellSize - para.height) / 2;
    canvas.drawParagraph(para, Offset(dx, dy));
  }

  // Outer border.
  canvas.drawRect(Rect.fromLTWH(0, 0, fSize, fSize), thickPaint);

  return recorder.endRecording().toImage(size, size);
}
