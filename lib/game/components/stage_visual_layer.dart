import 'package:flame/components.dart';

class StageVisualLayer extends SpriteComponent {
  StageVisualLayer({
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
    int priority = 0,
  }) : super(
         sprite: sprite,
         position: position,
         size: size,
         priority: priority,
       );
}
