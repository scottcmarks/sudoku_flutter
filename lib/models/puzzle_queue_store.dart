// puzzle_queue_store.dart — manages 24 pre-generated puzzle queues
//
// Architecture:
//   • 24 queues, one per (mapType × adjType × difficulty) combination
//   • Each queue persists as a JSON file in SudokuX4Games/queues/
//   • On first launch (empty queue), seeds from bundled queues-iphone.z asset
//   • 24 background isolates refill queues independently
//     (one per queue → easy types are never stalled by hard-type workers)

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../puzzle/puzzle_ffi.dart';
import '../puzzle/puzzle_types.dart';
import 'puzzle_queue_entry.dart';
import 'saved_game.dart';

// ---------------------------------------------------------------------------
// Worker isolate (runs in a separate Dart isolate, never on UI thread)
// ---------------------------------------------------------------------------

class _WorkerConfig {
  final SendPort resultPort;
  final int mapType;
  final int adjType;
  final int difficulty;
  const _WorkerConfig(this.resultPort, this.mapType, this.adjType, this.difficulty);
}

/// Entry point for each worker isolate.
void _workerMain(_WorkerConfig cfg) async {
  final receive = ReceivePort();

  // Handshake: tell the store which combination this worker handles and
  // hand back our control port in a single message.
  cfg.resultPort.send({
    'type':       'handshake',
    'sendPort':   receive.sendPort,
    'mapType':    cfg.mapType,
    'adjType':    cfg.adjType,
    'difficulty': cfg.difficulty,
  });

  final ffi = PuzzleFFI();

  await for (final msg in receive) {
    if (msg is! Map) continue;
    switch (msg['cmd'] as String?) {
      case 'stop':
        ffi.dispose();
        receive.close();
        return;
      case 'generate':
        final ok = ffi.generate(
          mapType:    SudokuMapType.values[cfg.mapType],
          adjType:    SudokuAdjType.values[cfg.adjType],
          difficulty: SudokuDifficulty.values[cfg.difficulty],
          quality:    SudokuQuality.compromise,
        );
        if (ok) {
          cfg.resultPort.send({
            'type':        'result',
            'status':      'ok',
            'puzzleBytes': ffi.snapshotBytes(),
            'colorMap':    ffi.getColorMap(),
            'mapType':     cfg.mapType,
            'adjType':     cfg.adjType,
            'difficulty':  cfg.difficulty,
          });
        } else {
          cfg.resultPort.send({
            'type':       'result',
            'status':     'failed',
            'mapType':    cfg.mapType,
            'adjType':    cfg.adjType,
            'difficulty': cfg.difficulty,
          });
        }
    }
  }
}

// ---------------------------------------------------------------------------
// Internal worker tracker (main-isolate side)
// ---------------------------------------------------------------------------

class _WorkerEntry {
  final Isolate isolate;
  SendPort? sendPort;   // set after handshake
  bool generating = false;
  _WorkerEntry(this.isolate);
}

// ---------------------------------------------------------------------------
// All 24 queue combinations
// ---------------------------------------------------------------------------

String _key(SudokuMapType m, SudokuAdjType a, SudokuDifficulty d) =>
    '${m.value}_${a.value}_${d.value}';

final _allCombos = [
  for (final m in SudokuMapType.values)
    for (final a in SudokuAdjType.values)
      for (final d in SudokuDifficulty.values)
        (m: m, a: a, d: d),
];

// ---------------------------------------------------------------------------
// PuzzleQueueStore
// ---------------------------------------------------------------------------

// Maximum puzzle-generation tasks that may run concurrently across all workers.
// Keep this ≤ logical CPU count so we don't OOM on debug builds.
const _maxConcurrent = 4;

class PuzzleQueueStore extends ChangeNotifier {
  final _queues  = <String, List<PuzzleQueueEntry>>{};
  final _workers = <String, _WorkerEntry>{};
  ReceivePort? _resultPort;
  int _activeGenerations = 0;

  // ---- Queries ----

  int depth(SudokuMapType m, SudokuAdjType a, SudokuDifficulty d) =>
      (_queues[_key(m, a, d)] ?? []).length;

  // ---- Dequeue ----

  PuzzleQueueEntry? dequeue(SudokuMapType m, SudokuAdjType a, SudokuDifficulty d) {
    final k = _key(m, a, d);
    final q = _queues[k];
    if (q == null || q.isEmpty) return null;
    final entry = q.removeAt(0);
    _persistQueue(k, q);
    notifyListeners();
    _maybeKickWorker(m, a, d);
    return entry;
  }

  // ---- Enqueue (called from worker result handler) ----

  Future<void> enqueue(PuzzleQueueEntry entry) async {
    final k = _key(entry.mapType, entry.adjType, entry.difficulty);
    final q = _queues.putIfAbsent(k, () => []);
    q.add(entry);
    await _persistQueue(k, q);
    notifyListeners();
  }

  // ---- Prioritize ----

  /// Ask the worker for a specific queue to generate immediately.
  /// Bypasses the concurrency limit so the user isn't left waiting.
  void prioritize(SudokuMapType m, SudokuAdjType a, SudokuDifficulty d) {
    final worker = _workers[_key(m, a, d)];
    if (worker != null && !worker.generating && worker.sendPort != null) {
      _activeGenerations++;
      worker.generating = true;
      worker.sendPort!.send({'cmd': 'generate'});
    }
  }

  // ---- Load (call once at startup) ----

  Future<void> load() async {
    final dir = await _queuesDir();

    // Load the bundled .z asset once and parse all game entries.
    final assetEntries = await _loadQueueAsset();
    debugPrint('PuzzleQueueStore: loaded ${assetEntries.length} entries from asset');

    int seededQueues = 0;
    int loadedQueues = 0;

    for (final c in _allCombos) {
      final k    = _key(c.m, c.a, c.d);
      final file = File('${dir.path}/queue_$k.json');

      if (await file.exists()) {
        try {
          final list = jsonDecode(await file.readAsString()) as List;
          if (list.isNotEmpty) {
            _queues[k] = list
                .map((j) => PuzzleQueueEntry.fromJson(j as Map<String, dynamic>))
                .toList();
            loadedQueues++;
            continue;
          }
        } catch (_) {
          // corrupt file — fall through to seed
        }
      }

      // Seed from asset
      seededQueues++;
      final target = sudokuDesiredQueueDepth(c.m.value, c.a.value, c.d.value);
      final seeds = assetEntries
          .where((e) =>
              e.mapType == c.m && e.adjType == c.a && e.difficulty == c.d)
          .take(target)
          .toList();
      _queues[k] = seeds;
      await _persistQueue(k, seeds);
    }

    final totalQueued = _queues.values.fold(0, (s, q) => s + q.length);
    debugPrint('PuzzleQueueStore: $loadedQueues queues from disk, '
        '$seededQueues seeded from asset, $totalQueued total entries');

    notifyListeners();
  }

  // ---- Album seeding (call on first launch when album is empty) ----

  Future<void> seedAlbum(SavedGameStore store) async {
    const albumEntriesPerQueue = 2; // desiredGameAlbumSize for all combos
    for (final c in _allCombos) {
      for (int i = 0; i < albumEntriesPerQueue; i++) {
        final entry = dequeue(c.m, c.a, c.d);
        if (entry == null) continue;
        await store.save(_entryToSavedGame(entry));
      }
    }
  }

  // ---- Workers ----

  Future<void> startWorkers() async {
    _resultPort ??= ReceivePort()..listen(_onWorkerMessage);

    for (final c in _allCombos) {
      final k = _key(c.m, c.a, c.d);
      if (_workers.containsKey(k)) continue;
      final isolate = await Isolate.spawn(
        _workerMain,
        _WorkerConfig(_resultPort!.sendPort, c.m.value, c.a.value, c.d.value),
      );
      _workers[k] = _WorkerEntry(isolate);
    }
  }

  void stopWorkers() {
    for (final w in _workers.values) {
      w.sendPort?.send({'cmd': 'stop'});
      w.isolate.kill(priority: Isolate.beforeNextEvent);
    }
    _workers.clear();
    _resultPort?.close();
    _resultPort = null;
  }

  // ---- Private: worker message handler ----

  void _onWorkerMessage(dynamic msg) {
    if (msg is! Map) return;
    final type = msg['type'] as String?;

    if (type == 'handshake') {
      final k = '${msg['mapType']}_${msg['adjType']}_${msg['difficulty']}';
      final worker = _workers[k];
      if (worker != null) {
        worker.sendPort = msg['sendPort'] as SendPort;
        // Only kick if a generation slot is available (respects _maxConcurrent).
        final m = SudokuMapType.values[msg['mapType'] as int];
        final a = SudokuAdjType.values[msg['adjType'] as int];
        final d = SudokuDifficulty.values[msg['difficulty'] as int];
        _maybeKickWorker(m, a, d);
      }
      return;
    }

    if (type == 'result') {
      final mRaw = msg['mapType'] as int;
      final aRaw = msg['adjType'] as int;
      final dRaw = msg['difficulty'] as int;
      final m = SudokuMapType.values[mRaw];
      final a = SudokuAdjType.values[aRaw];
      final d = SudokuDifficulty.values[dRaw];
      final k = _key(m, a, d);
      final worker = _workers[k];
      if (worker != null) worker.generating = false;
      _activeGenerations = (_activeGenerations - 1).clamp(0, _maxConcurrent);

      if (msg['status'] == 'ok') {
        final entry = PuzzleQueueEntry(
          puzzleBytes: msg['puzzleBytes'] as Uint8List,
          colorMap:    List<int>.from(msg['colorMap'] as List),
          mapType:     m,
          adjType:     a,
          difficulty:  d,
        );
        enqueue(entry);
      }
      // Try this worker first, then unblock any other waiting workers.
      _maybeKickWorker(m, a, d);
      _kickPendingWorkers();
    }
  }

  void _maybeKickWorker(SudokuMapType m, SudokuAdjType a, SudokuDifficulty d) {
    if (_activeGenerations >= _maxConcurrent) return;
    final k      = _key(m, a, d);
    final worker = _workers[k];
    if (worker == null || worker.sendPort == null || worker.generating) return;
    final target = sudokuDesiredQueueDepth(m.value, a.value, d.value);
    if (depth(m, a, d) < target) {
      _activeGenerations++;
      worker.generating = true;
      worker.sendPort!.send({'cmd': 'generate'});
    }
  }

  /// After a slot frees up, kick the next waiting worker (if any).
  void _kickPendingWorkers() {
    for (final c in _allCombos) {
      if (_activeGenerations >= _maxConcurrent) break;
      _maybeKickWorker(c.m, c.a, c.d);
    }
  }

  // ---- Private: persistence ----

  Future<void> _persistQueue(String k, List<PuzzleQueueEntry> entries) async {
    final dir  = await _queuesDir();
    final tmp  = File('${dir.path}/queue_$k.json.tmp');
    final dest = File('${dir.path}/queue_$k.json');
    await tmp.writeAsString(
        jsonEncode(entries.map((e) => e.toJson()).toList()));
    await tmp.rename(dest.path);
  }

  Future<List<PuzzleQueueEntry>> _loadQueueAsset() async {
    try {
      final compressed =
          (await rootBundle.load('assets/queues/queues-iphone.z'))
              .buffer
              .asUint8List();
      final inflated = Uint8List.fromList(ZLibDecoder().convert(compressed));
      return _parseQueueBytes(inflated);
    } catch (e) {
      debugPrint('PuzzleQueueStore: could not load queue asset: $e');
      return [];
    }
  }

  List<PuzzleQueueEntry> _parseQueueBytes(Uint8List inflated) {
    final handle = sudokuQueueLoad(inflated);
    if (handle == null) {
      debugPrint('PuzzleQueueStore: sudokuQueueLoad returned null');
      return [];
    }
    try {
      final count = sudokuQueueGameCount(handle);
      final entries = <PuzzleQueueEntry>[];
      for (int i = 0; i < count; i++) {
        final r = sudokuQueueGetGame(handle, i);
        if (r == null) continue;
        entries.add(PuzzleQueueEntry(
          puzzleBytes: r.puzzleBytes,
          colorMap:    r.colorMap,
          mapType:     SudokuMapType.values[r.mapType.clamp(0, 1)],
          adjType:     SudokuAdjType.values[r.adjType.clamp(0, 1)],
          difficulty:  SudokuDifficulty.values[r.difficulty.clamp(0, 5)],
        ));
      }
      return entries;
    } finally {
      sudokuQueueFree(handle);
    }
  }

  Future<Directory> _queuesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir  = Directory('${base.path}/SudokuX4Games/queues');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @override
  void dispose() {
    stopWorkers();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Helper: convert a queue entry to a SavedGame (for album seeding)
// ---------------------------------------------------------------------------

SavedGame _entryToSavedGame(PuzzleQueueEntry entry) => SavedGame(
  uuid:          const Uuid().v4(),
  created:       DateTime.now(),
  difficulty:    entry.difficulty,
  mapType:       entry.mapType,
  adjType:       entry.adjType,
  userHasWon:    false,
  distance:      81,
  puzzleBytes:   entry.puzzleBytes,
  colorMap:      entry.colorMap,
  mapTypeRaw:    entry.mapType.value,
  adjTypeRaw:    entry.adjType.value,
  difficultyRaw: entry.difficulty.value,
);
