// app_settings.dart — lightweight user preferences
//
// Persisted to <appDocuments>/SudokuX4Games/settings.json.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AppSettings extends ChangeNotifier {
  bool manualGeneration = false;

  Future<void> load() async {
    try {
      final file = await _settingsFile();
      if (await file.exists()) {
        final j = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        manualGeneration = (j['manualGeneration'] as bool?) ?? false;
        notifyListeners();
      }
    } catch (_) {
      // ignore — use defaults
    }
  }

  Future<void> save() async {
    final file = await _settingsFile();
    await file.writeAsString(jsonEncode({'manualGeneration': manualGeneration}));
  }

  void setManualGeneration(bool value) {
    manualGeneration = value;
    notifyListeners();
    save();
  }

  Future<File> _settingsFile() async {
    final base = await getApplicationDocumentsDirectory();
    final dir  = Directory('${base.path}/SudokuX4Games');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/settings.json');
  }
}
