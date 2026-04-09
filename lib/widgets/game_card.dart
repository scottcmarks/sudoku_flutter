// game_card.dart — reusable puzzle thumbnail card for album/game-list screens

import 'package:flutter/material.dart';

import '../models/saved_game.dart';
import '../models/thumbnail_cache.dart';
import '../theme/app_theme.dart';

class GameCard extends StatelessWidget {
  final SavedGame    game;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const GameCard({
    super.key,
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
                child: CachedThumbnail(game: game),
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
                        const Icon(Icons.check_circle,
                            size: 14, color: AppTheme.winGold),
                    ],
                  ),
                  Text(
                    game.distance == 0
                        ? 'Solved'
                        : '${game.distance} remaining',
                    style: TextStyle(
                      fontSize: 11,
                      color: game.distance == 0
                          ? AppTheme.winGold
                          : AppTheme.gridLine,
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
