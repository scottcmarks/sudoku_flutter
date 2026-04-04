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
    notifyListeners();
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
    notifyListeners();
  }

  Future<Directory> _gamesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir  = Directory('${base.path}/SudokuX4Games');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
