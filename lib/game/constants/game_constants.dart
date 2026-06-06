import 'package:flutter/material.dart';

class GameConstants {
  static const double worldWidth = 1280.0;
  static const double worldHeight = 720.0;
  
  // Fisika Dasar
  static const double gravity = 1500.0;
  static const double playerSpeed = 200.0;
  static const double jumpForce = -700.0;
  static const double deathZoneY = 800.0;

  // Warna Arena
  static const Color bgDarkBrown = Color(0xFF2C1E16);
  static const Color platOutline = Color(0xFF3E2723);
  static const Color platBody = Color(0xFF5D4037);
  static const Color platHighlight = Color(0xFF8D6E63);

  // Warna Pemain
  static const Color p1Red = Color(0xFFE53935);
  static const Color p2Blue = Color(0xFF1E88E5);
  static const Color p3Yellow = Color(0xFFFDD835);
  static const Color p4Green = Color(0xFF43A047);
}
