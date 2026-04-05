import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/saved_game.dart';
import 'puzzle/puzzle_engine.dart';
import 'puzzle/puzzle_ffi.dart';
import 'screens/album_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _initGroupMaps();
  runApp(const SudokuX4App());
}

/// Tell the C engine where to find the group map .z files.
/// Reads SUDOKU_GROUP_MAPS_DIR from the process environment.
/// For a production build, call setGroupMapsDir() with the bundle path instead.
void _initGroupMaps() {
  final dir = Platform.environment['SUDOKU_GROUP_MAPS_DIR'];
  if (dir != null && dir.isNotEmpty) {
    setGroupMapsDir(dir);
  }
  // If not set, the C engine falls back to /usr/share/sudoku/group_maps.
  // For dev: export SUDOKU_GROUP_MAPS_DIR=~/SudokuX4/PlatformIndependent/Resources/group_maps
  //          before running `flutter run -d macos`.
}

class SudokuX4App extends StatelessWidget {
  const SudokuX4App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PuzzleEngine()),
        ChangeNotifierProvider(create: (_) => SavedGameStore()),
      ],
      child: MaterialApp(
        title: 'Sudoku X4',
        theme: AppTheme.theme,
        home: const AlbumScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
