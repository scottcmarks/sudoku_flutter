import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/saved_game.dart';
import 'puzzle/puzzle_engine.dart';
import 'screens/album_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SudokuX4App());
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
