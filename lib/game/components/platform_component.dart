import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../constants/game_constants.dart';

class PlatformComponent extends PositionComponent {
  PlatformComponent({required Vector2 position, required Vector2 size})
    : super(position: position, size: size);

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Gambar garis luar (outline)
    final outlinePaint = Paint()..color = GameConstants.platOutline;
    canvas.drawRect(size.toRect(), outlinePaint);

    // Gambar bagian utama platform
    final bodyPaint = Paint()..color = GameConstants.platBody;
    canvas.drawRect(Rect.fromLTWH(2, 2, size.x - 4, size.y - 4), bodyPaint);

    // Gambar highlight atas untuk efek retro
    final highlightPaint = Paint()..color = GameConstants.platHighlight;
    canvas.drawRect(Rect.fromLTWH(2, 2, size.x - 4, 4), highlightPaint);
  }
}
