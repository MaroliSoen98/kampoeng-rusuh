import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../constants/game_constants.dart';
import '../arena_game.dart';

enum PlatformType {
  mainGround,
  warungRoof,
  balcony,
  centerPlatform,
  extraPlatform,
}

class PlatformComponent extends PositionComponent with HasGameRef<ArenaGame> {
  final bool isJumpThrough;
  final int depth;
  final PlatformType type;

  PlatformComponent({
    required Vector2 position,
    required Vector2 size,
    this.isJumpThrough = false,
    this.depth = 0,
    this.type = PlatformType.mainGround,
  }) : super(position: position, size: size);

  @override
  void render(Canvas canvas) {
    // Jika mode debug dimatikan, jangan render bentuk visual platformnya
    if (!gameRef.showStageColliders) return;

    super.render(canvas);

    Color bodyColor;
    Color outlineColor = Colors.black87.withOpacity(0.5);

    switch (type) {
      case PlatformType.mainGround:
        bodyColor = const Color(0xFF424242).withOpacity(0.5); // Dark gray
        break;
      case PlatformType.warungRoof:
        bodyColor = const Color(0xFF8B4513).withOpacity(0.5); // Reddish brown
        break;
      case PlatformType.balcony:
        bodyColor = const Color(0xFF6D4C41).withOpacity(0.5); // Muted brown
        break;
      case PlatformType.centerPlatform:
        bodyColor = const Color(0xFF8D6E63).withOpacity(0.5); // Wooden brown
        break;
      case PlatformType.extraPlatform:
        bodyColor = const Color(
          0xFF00C853,
        ).withOpacity(0.5); // Hijau terang agar mudah dilacak
        break;
    }

    // Gambar platform body (Debug placeholder)
    canvas.drawRect(size.toRect(), Paint()..color = bodyColor);

    // Gambar border outline agar platform terlihat terpisah dengan background
    canvas.drawRect(
      size.toRect(),
      Paint()
        ..color = outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}
