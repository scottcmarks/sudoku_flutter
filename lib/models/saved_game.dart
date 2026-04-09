// saved_game.dart — persistence model for a saved puzzle
//
// A saved game is a JSON file in the app's documents directory.
// It stores the PuzzleData bytes, metadata, and a thumbnail.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../puzzle/puzzle_types.dart';

class SavedGame {
  final String uuid;
  final DateTime created;
  final SudokuDifficulty difficulty;
  final SudokuMapType    mapType;
  final SudokuAdjType    adjType;
  final bool             userHasWon;
  final int              distance;          // 0 = solved
  final Uint8List        puzzleBytes;       // raw PUZZLE struct bytes
  final List<int>        colorMap;          // 9 entries
  // Metadata for engine reconstruction
  final int              mapTypeRaw;
  final int              adjTypeRaw;
  final int              difficultyRaw;

  SavedGame({
    required this.uuid,
    required this.created,
    required this.difficulty,
    required this.mapType,
    required this.adjType,
    required this.userHasWon,
    required this.distance,
    required this.puzzleBytes,
    required this.colorMap,
    required this.mapTypeRaw,
    required this.adjTypeRaw,
    required this.difficultyRaw,
  });

  Map<String, dynamic> toJson() => {
    'uuid':          uuid,
    'created':       created.toIso8601String(),
    'difficulty':    difficultyRaw,
    'mapType':       mapTypeRaw,
    'adjType':       adjTypeRaw,
    'userHasWon':    userHasWon,
    'distance':      distance,
    'colorMap':      colorMap,
    'puzzleBytes':   base64Encode(puzzleBytes),
  };

  static SavedGame fromJson(Map<String, dynamic> j) {
    final diffRaw = j['difficulty'] as int;
    final mapRaw  = j['mapType']    as int;
    final adjRaw  = j['adjType']    as int;
    return SavedGame(
      uuid:          j['uuid']       as String,
      created:       DateTime.parse(j['created'] as String),
      difficulty:    SudokuDifficulty.values[diffRaw.clamp(0, 5)],
      mapType:       SudokuMapType.values[mapRaw.clamp(0, 1)],
      adjType:       SudokuAdjType.values[adjRaw.clamp(0, 1)],
      userHasWon:    j['userHasWon'] as bool,
      distance:      j['distance']   as int,
      colorMap:      List<int>.from(j['colorMap'] as List),
      puzzleBytes:   base64Decode(j['puzzleBytes'] as String),
      mapTypeRaw:    mapRaw,
      adjTypeRaw:    adjRaw,
      difficultyRaw: diffRaw,
    );
  }
}

// ---------------------------------------------------------------------------
// SavedGameStore
// ---------------------------------------------------------------------------

class SavedGameStore extends ChangeNotifier {
  final List<SavedGame> games = [];

  /// Per-collection exemplar: keyed by "${mapType.value}_${adjType.value}_${difficulty.value}".
  final Map<String, String> _exemplarUuids = {};

  static String _key(SudokuMapType mt, SudokuAdjType at, SudokuDifficulty d) =>
      '${mt.value}_${at.value}_${d.value}';

  /// The "current" game for a given collection — used as the thumbnail on
  /// DifficultyScreen rows.  Falls back to the most-recently-saved game.
  SavedGame? exemplarFor(SudokuMapType mt, SudokuAdjType at, SudokuDifficulty d) {
    final uuid = _exemplarUuids[_key(mt, at, d)];
    if (uuid != null) {
      final hit = games.where((g) => g.uuid == uuid).firstOrNull;
      if (hit != null) return hit;
    }
    return games
        .where((g) => g.mapType == mt && g.adjType == at && g.difficulty == d)
        .firstOrNull;
  }

  /// The best single exemplar for a (mapType, adjType) pair — used on HomeScreen.
  /// Returns the first difficulty that has an explicitly-set exemplar, or the
  /// first saved game for that type if none is set.
  SavedGame? typeExemplarFor(SudokuMapType mt, SudokuAdjType at) {
    for (final d in SudokuDifficulty.values) {
      final uuid = _exemplarUuids[_key(mt, at, d)];
      if (uuid != null) {
        final hit = games.where((g) => g.uuid == uuid).firstOrNull;
        if (hit != null) return hit;
      }
    }
    return games.where((g) => g.mapType == mt && g.adjType == at).firstOrNull;
  }

  /// Record that [uuid] is the "current" game for its collection.  Both the
  /// grid view and the slideshow call this so they stay in sync.
  void setExemplar(SudokuMapType mt, SudokuAdjType at, SudokuDifficulty d, String uuid) {
    if (_exemplarUuids[_key(mt, at, d)] == uuid) return; // no-op
    _exemplarUuids[_key(mt, at, d)] = uuid;
    notifyListeners();
    _saveExemplars(); // fire-and-forget
  }

  Future<void> load() async {
    final dir = await _gamesDir();
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.sx4json'));
    games.clear();
    for (final f in files) {
      try {
        final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        games.add(SavedGame.fromJson(json));
      } catch (_) {
        // skip corrupt files
      }
    }
    games.sort((a, b) => b.created.compareTo(a.created));
    await _loadExemplars();
    notifyListeners();
  }

  Future<void> _loadExemplars() async {
    try {
      final dir  = await _gamesDir();
      final file = File('${dir.path}/exemplars.json');
      if (await file.exists()) {
        final j = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _exemplarUuids.clear();
        j.forEach((k, v) => _exemplarUuids[k] = v as String);
      }
    } catch (_) {}
  }

  Future<void> _saveExemplars() async {
    try {
      final dir  = await _gamesDir();
      final file = File('${dir.path}/exemplars.json');
      await file.writeAsString(jsonEncode(_exemplarUuids));
    } catch (_) {}
  }

  Future<void> save(SavedGame game) async {
    final dir  = await _gamesDir();
    final file = File('${dir.path}/${game.uuid}.sx4json');
    await file.writeAsString(jsonEncode(game.toJson()));
    final idx = games.indexWhere((g) => g.uuid == game.uuid);
    if (idx >= 0) {
      games[idx] = game;
    } else {
      games.insert(0, game);
    }
    notifyListeners();
  }

  Future<void> delete(String uuid) async {
    final dir  = await _gamesDir();
    final file = File('${dir.path}/$uuid.sx4json');
    if (await file.exists()) await file.delete();
    games.removeWhere((g) => g.uuid == uuid);
    _exemplarUuids.removeWhere((_, v) => v == uuid);
    _saveExemplars();
    notifyListeners();
  }

  Future<Directory> _gamesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir  = Directory('${base.path}/SudokuX4Games');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
