import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flame/game.dart';
import 'package:vector_math/vector_math_64.dart' as vmath;
import 'game/arena_game.dart';
import 'game/constants/game_constants.dart';
import 'home_screen.dart';
import 'firebase_options.dart';
import 'lobby_screen.dart';

void main() async {
  // Wajib dipanggil jika menggunakan setting platform di runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase belum dikonfigurasi: $e');
  }

  // Paksa layar ke mode Landscape
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Sembunyikan status bar (baterai, sinyal) untuk pengalaman Fullscreen
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(
    MaterialApp(debugShowCheckedModeBanner: false, home: const HomeScreen()),
  );
}

class GameScreen extends StatefulWidget {
  final String? roomCode;
  final String? playerName;
  final String offlineCharacter;
  final List<String> offlineBotCharacters;

  const GameScreen({
    super.key,
    this.roomCode,
    this.playerName,
    this.offlineCharacter = 'anak_sekolah',
    this.offlineBotCharacters = const [
      'pekerja_scbd',
      'ibu_daster',
      'ketua_rt',
    ],
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final ArenaGame _game;

  @override
  void initState() {
    super.initState();
    _game = ArenaGame(
      roomCode: widget.roomCode,
      localPlayerName: widget.playerName,
      offlineCharacter: widget.offlineCharacter,
      offlineBotCharacters: widget.offlineBotCharacters,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameConstants.bgDarkBrown,
      body: GameWidget<ArenaGame>(
        game: _game,
        loadingBuilder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.orangeAccent),
        ),
        overlayBuilderMap: _game.overlayBuilderMap,
        initialActiveOverlays: const ['TouchControls', 'HUD', 'MatchStart'],
      ),
    );
  }
}

class MatchStartOverlay extends StatelessWidget {
  final ArenaGame game;
  const MatchStartOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.5), // Latar belakang meredup sedikit
      child: Center(
        child: ValueListenableBuilder<String>(
          valueListenable: game.matchStartTextNotifier,
          builder: (context, text, child) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(
                  scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.elasticOut, // Animasi pop-in memantul
                    ),
                  ),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: Text(
                text,
                key: ValueKey<String>(
                  text,
                ), // Kunci penting agar animasi dijalankan per pergantian kata
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: text == "FIGHT!"
                      ? const Color(0xFFEF476F) // Bright Pink untuk FIGHT
                      : const Color(0xFFFFD166), // Vibrant Yellow
                  fontSize: text == "READY"
                      ? 80
                      : (text == "FIGHT!" ? 120 : 100),
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 4.0,
                  shadows: const [
                    Shadow(color: Colors.black, offset: Offset(-3, -3)),
                    Shadow(color: Colors.black, offset: Offset(3, -3)),
                    Shadow(color: Colors.black, offset: Offset(3, 3)),
                    Shadow(color: Colors.black, offset: Offset(-3, 3)),
                    Shadow(
                      color: Color(0xFF073B4C),
                      blurRadius: 0,
                      offset: Offset(8, 8),
                    ), // 3D cartoon shadow
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class TouchControlsOverlay extends StatelessWidget {
  final ArenaGame game;

  const TouchControlsOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // D-Pad / Arrow keys di kiri bawah
          Positioned(left: 40, bottom: 40, child: VirtualDPad(game: game)),

          // Action Buttons di kanan bawah
          Positioned(
            right: 40,
            bottom: 40,
            child: SizedBox(
              width: 220, // Diperbesar agar tombol kiri (Punch) tidak terpotong
              height: 220, // Diperbesar agar tombol atas (Grab) tidak terpotong
              child: Stack(
                children: [
                  // JUMP (Posisi Tengah - Paling Besar)
                  Positioned(
                    right: 40,
                    bottom: 40,
                    child: _buildActionButton(
                      text: 'JUMP',
                      icon: Icons.keyboard_double_arrow_up,
                      size: 90,
                      onTapDown: () => game.player1?.uiJump(),
                    ),
                  ),
                  // PUNCH (Posisi Kiri mengelilingi Jump)
                  Positioned(
                    right: 140,
                    bottom: 52.5,
                    child: _buildActionButton(
                      text: 'PUNCH',
                      icon: Icons.sports_martial_arts,
                      size: 65,
                      onTapDown: () => game.player1?.uiPunch(),
                    ),
                  ),
                  // GRAB (Posisi Atas mengelilingi Jump)
                  Positioned(
                    right: 52.5,
                    bottom: 140,
                    child: _buildActionButton(
                      text: 'GRAB',
                      icon: Icons.back_hand,
                      size: 65,
                      onTapDown: () => game.player1?.uiGrab(),
                      cooldownNotifier: game.p1GrabCooldownNotifier,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required IconData icon,
    double size = 80,
    VoidCallback? onTapDown,
    ValueNotifier<double>? cooldownNotifier,
  }) {
    if (cooldownNotifier != null) {
      return ValueListenableBuilder<double>(
        valueListenable: cooldownNotifier,
        builder: (context, cooldown, child) {
          bool isOnCooldown = cooldown > 0;
          return Stack(
            alignment: Alignment.center,
            children: [
              _buildRawButton(
                text,
                icon,
                size,
                isOnCooldown ? null : onTapDown,
              ),
              if (isOnCooldown) ...[
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    value: cooldown / 30.0, // Dibagi 30 detik (durasi max)
                    strokeWidth: 4,
                    color: Colors.orangeAccent,
                  ),
                ),
                Text(
                  cooldown.ceil().toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          );
        },
      );
    }
    return _buildRawButton(text, icon, size, onTapDown);
  }

  Widget _buildRawButton(
    String text,
    IconData icon,
    double size,
    VoidCallback? onTapDown,
  ) {
    return GestureDetector(
      onTapDown: (_) => onTapDown?.call(),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6), // Putih bening (opacity 60%)
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.black87, size: size * 0.35),
            const SizedBox(height: 2),
            Text(
              text,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.18, // Skala ukuran font dinamis
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// D-Pad / Joystick Virtual Kustom
class VirtualDPad extends StatefulWidget {
  final ArenaGame game;
  const VirtualDPad({super.key, required this.game});

  @override
  State<VirtualDPad> createState() => _VirtualDPadState();
}

class _VirtualDPadState extends State<VirtualDPad> {
  bool _isLeft = false;
  bool _isRight = false;
  bool _isDown = false;
  bool _isUp = false;

  void _updateState(Offset localPosition, double size) {
    double dx = localPosition.dx - size / 2;
    double dy = localPosition.dy - size / 2;

    // Threshold/deadzone agar tidak terlalu sensitif di tengah
    bool newLeft = dx < -20;
    bool newRight = dx > 20;
    bool newUp = dy < -20;
    bool newDown = dy > 20;

    if (_isLeft != newLeft) {
      _isLeft = newLeft;
      widget.game.player1?.uiMoveLeft(_isLeft);
    }
    if (_isRight != newRight) {
      _isRight = newRight;
      widget.game.player1?.uiMoveRight(_isRight);
    }
    if (_isDown != newDown) {
      _isDown = newDown;
      widget.game.player1?.uiMoveDown(_isDown);
    }
    if (_isUp != newUp) {
      _isUp = newUp;
      if (_isUp) {
        widget.game.player1?.uiJump(); // Lompat bersifat trigger (sekali tekan)
      }
    }
  }

  void _resetState() {
    if (_isLeft) {
      _isLeft = false;
      widget.game.player1?.uiMoveLeft(false);
    }
    if (_isRight) {
      _isRight = false;
      widget.game.player1?.uiMoveRight(false);
    }
    if (_isDown) {
      _isDown = false;
      widget.game.player1?.uiMoveDown(false);
    }
    _isUp = false;
  }

  @override
  Widget build(BuildContext context) {
    const double size = 200;

    return GestureDetector(
      onPanStart: (details) => _updateState(details.localPosition, size),
      onPanUpdate: (details) => _updateState(details.localPosition, size),
      onPanEnd: (details) => _resetState(),
      onPanCancel: () => _resetState(),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.transparent, // Area luas penangkap sentuhan
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Latar bentuk Tanda Tambah (+) (Cross)
            Container(
              width: size,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Container(
              width: 70,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            // Titik tengah deadzone (pivot)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
            // Panah Arah
            Positioned(
              top: 10,
              child: _buildArrow(Icons.keyboard_arrow_up, _isUp),
            ),
            Positioned(
              bottom: 10,
              child: _buildArrow(Icons.keyboard_arrow_down, _isDown),
            ),
            Positioned(
              left: 10,
              child: _buildArrow(Icons.keyboard_arrow_left, _isLeft),
            ),
            Positioned(
              right: 10,
              child: _buildArrow(Icons.keyboard_arrow_right, _isRight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrow(IconData icon, bool isActive) {
    return Icon(
      icon,
      color: isActive ? Colors.white : Colors.black87,
      size: 50,
      shadows: isActive
          ? const [Shadow(color: Colors.white, blurRadius: 10)]
          : null,
    );
  }
}

class HUDOverlay extends StatelessWidget {
  final ArenaGame game;
  const HUDOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // IgnorePointer agar HUD di atas tidak terklik dan memblokir input game
      child: IgnorePointer(
        child: Stack(
          children: [
            // ===== MATCH TIMER HUD (TOP CENTER) =====
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ValueListenableBuilder<int>(
                  valueListenable: game.matchTimerNotifier,
                  builder: (context, time, child) {
                    String mins = (time ~/ 60).toString().padLeft(2, '0');
                    String secs = (time % 60).toString().padLeft(2, '0');
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFFD166).withOpacity(0.9),
                          width: 2.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            offset: Offset(0, 4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        '$mins:$secs',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ===== PLAYER HUDS (BOTTOM CENTER - SMASH BRAWL STYLE) =====
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: 24.0,
                ), // Offset dari dasar layar
                child: ValueListenableBuilder<List<int>>(
                  valueListenable: game.playerLivesNotifier,
                  builder: (context, lives, child) {
                    return ValueListenableBuilder<List<double>>(
                      valueListenable: game.playerDamageNotifier,
                      builder: (context, damages, child) {
                        return ValueListenableBuilder<List<int>>(
                          valueListenable: game.playerRespawnNotifier,
                          builder: (context, respawns, child) {
                            List<Widget> leftHuds = [];
                            List<Widget> rightHuds = [];

                            for (int i = 0; i < lives.length; i++) {
                              if (i >= game.playerNames.length) continue;

                              double currentDamage = i < damages.length
                                  ? damages[i]
                                  : 0.0;
                              int currentRespawn = i < respawns.length
                                  ? respawns[i]
                                  : 0;

                              Widget hud = PlayerHudSlot(
                                label: game.playerNames[i],
                                color: game.playerColors[i],
                                lives: lives[i],
                                damage: currentDamage,
                                respawnTime: currentRespawn,
                                isRightSide: i >= 2, // 0,1 Kiri | 2,3 Kanan
                              );

                              if (i < 2) {
                                leftHuds.add(
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0,
                                    ),
                                    child: hud,
                                  ),
                                );
                              } else {
                                rightHuds.add(
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0,
                                    ),
                                    child: hud,
                                  ),
                                );
                              }
                            }

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                ...leftHuds,
                                if (leftHuds.isNotEmpty && rightHuds.isNotEmpty)
                                  const SizedBox(
                                    width: 48,
                                  ), // Jarak di tengah untuk memisahkan kubu
                                ...rightHuds,
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====== WIDGET REUSABLE UNTUK SETIAP SLOT PEMAIN (FIGHTING GAME STYLE) ======
class PlayerHudSlot extends StatelessWidget {
  final String label;
  final Color color;
  final int lives;
  final double damage;
  final int respawnTime;
  final bool isRightSide; // Flag untuk cermin tata letak

  const PlayerHudSlot({
    super.key,
    required this.label,
    required this.color,
    required this.lives,
    required this.damage,
    this.respawnTime = 0,
    this.isRightSide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: lives > 0 ? 1.0 : 0.4, // Redupkan jika sudah mati
      child: SizedBox(
        width: 180, // Ukuran diperkecil agar tidak memakan banyak layar
        height: 65,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ===== NAMEPLATE (Bottom Bar) =====
            Positioned(
              bottom: 0,
              left: isRightSide ? 0 : 50,
              right: isRightSide ? 50 : 0,
              child: Container(
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF111111,
                  ).withOpacity(0.9), // Latar hitam pekat
                  border: Border(
                    bottom: BorderSide(
                      color: color,
                      width: 2,
                    ), // Garis bawah warna pemain
                    top: const BorderSide(color: Color(0xFF333333), width: 1),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      offset: Offset(0, 2),
                      blurRadius: 2,
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: isRightSide
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  textDirection: isRightSide
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  children: [
                    Expanded(
                      child: Text(
                        label.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: isRightSide
                            ? TextAlign.right
                            : TextAlign.left,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (index) {
                        return Icon(
                          index < lives
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: index < lives ? color : Colors.white30,
                          size: 10,
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),

            // ===== HUGE DAMAGE PERCENTAGE =====
            Positioned(
              bottom: 16, // Duduk tepat di atas Nameplate
              left: isRightSide ? 0 : 55,
              right: isRightSide ? 55 : 0,
              child: Container(
                alignment: isRightSide
                    ? Alignment.bottomRight
                    : Alignment.bottomLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: damage),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, animatedDamage, child) {
                      Color damageColor;

                      // Transisi warna halus (Lerp) berdasarkan persentase
                      if (animatedDamage < 30) {
                        // Putih -> Kuning (0% - 30%)
                        damageColor =
                            Color.lerp(
                              Colors.white,
                              const Color(0xFFFFD700),
                              animatedDamage / 30.0,
                            ) ??
                            Colors.white;
                      } else if (animatedDamage < 70) {
                        // Kuning -> Orange (30% - 70%)
                        damageColor =
                            Color.lerp(
                              const Color(0xFFFFD700),
                              const Color(0xFFFF6D00),
                              (animatedDamage - 30.0) / 40.0,
                            ) ??
                            const Color(0xFFFFD700);
                      } else if (animatedDamage < 120) {
                        // Orange -> Merah Terang (70% - 120%)
                        damageColor =
                            Color.lerp(
                              const Color(0xFFFF6D00),
                              const Color(0xFFD32F2F),
                              (animatedDamage - 70.0) / 50.0,
                            ) ??
                            const Color(0xFFFF6D00);
                      } else if (animatedDamage < 200) {
                        // Merah Terang -> Merah Maroon Gelap (120% - 200%)
                        damageColor =
                            Color.lerp(
                              const Color(0xFFD32F2F),
                              const Color(0xFF5C0000),
                              (animatedDamage - 120.0) / 80.0,
                            ) ??
                            const Color(0xFFD32F2F);
                      } else {
                        // Mentok di Maroon Gelap untuk damage sangat ekstrem (>200%)
                        damageColor = const Color(0xFF5C0000);
                      }

                      return Text(
                        "${animatedDamage.toStringAsFixed(1)}%",
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: damageColor,
                          fontSize: 34, // HUGE
                          fontWeight: FontWeight.w900,
                          fontStyle:
                              FontStyle.italic, // Teks miring khas arcade
                          height: 1.0,
                          letterSpacing: -1.0,
                          shadows: const [
                            // Outline tebal dan bayangan
                            Shadow(
                              color: Colors.black,
                              offset: Offset(-1.5, -1.5),
                            ),
                            Shadow(
                              color: Colors.black,
                              offset: Offset(1.5, -1.5),
                            ),
                            Shadow(
                              color: Colors.black,
                              offset: Offset(1.5, 1.5),
                            ),
                            Shadow(
                              color: Colors.black,
                              offset: Offset(-1.5, 1.5),
                            ),
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 4,
                              offset: Offset(3, 3),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // ===== SLANTED PORTRAIT PANEL =====
            Positioned(
              bottom: 0,
              left: isRightSide ? null : 0,
              right: isRightSide ? 0 : null,
              child: Transform(
                // Skew murni hanya untuk bingkai wajah ini (Menjeritkan gaya Smash Bros)
                transform: vmath.Matrix4.skewX(isRightSide ? 0.2 : -0.2),
                child: Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(
                          0xFF3A3A3A,
                        ).withOpacity(0.95), // Metallic Gray
                        const Color(0xFF0A0A0A).withOpacity(0.95), // Black
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF555555),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        offset: Offset(2, 4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Inner colored accent line
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: color, width: 4),
                            left: BorderSide(
                              color: isRightSide ? Colors.transparent : color,
                              width: 3,
                            ),
                            right: BorderSide(
                              color: isRightSide ? color : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                      // Lawan arah skew agar Icon/Foto tetap lurus
                      Transform(
                        transform: vmath.Matrix4.skewX(
                          isRightSide ? -0.2 : 0.2,
                        ),
                        alignment: Alignment.center,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.person,
                              color: Colors.white70,
                              size: 36,
                            ),
                            if (respawnTime > 0 && lives > 0)
                              Container(
                                color: Colors.black.withOpacity(0.75),
                                alignment: Alignment.center,
                                child: Text(
                                  '$respawnTime',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GameOverOverlay extends StatelessWidget {
  final ArenaGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    String titleText = "GAME OVER";
    String subtitleText = "${game.winnerName} MENANG!";

    bool isOnline = game.roomCode != null && game.localPlayerName != null;

    if (isOnline) {
      if (game.winnerName == game.localPlayerName) {
        subtitleText = "KAMU MENANG! 🎉";
      } else if (game.winnerName == "TIDAK ADA YANG") {
        subtitleText = "SERI!";
      } else {
        subtitleText = "KAMU KALAH! 💀";
      }
    }

    return Container(
      color: Colors.black.withOpacity(0.5), // Meredupkan latar belakang arena
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6), // Warm Cream
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF073B4C), width: 4),
            boxShadow: const [
              BoxShadow(color: Color(0xFF073B4C), offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titleText,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Color(
                    0xFFEF476F,
                  ), // Bright Pink/Red untuk impact yang kuat
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4.0,
                  shadows: [
                    Shadow(
                      color: Color(
                        0xFF073B4C,
                      ), // Deep Navy shadow agar kontras dengan teks terang & BG Cream
                      offset: Offset(4, 4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: subtitleText.contains("MENANG")
                      ? const Color(0xFF06D6A0) // Solid Teal (Menang)
                      : const Color(0xFFEF476F), // Solid Pink (Kalah/Seri)
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(
                      0xFF073B4C,
                    ), // Outline gelap (Navy) seragam
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(
                        0xFF073B4C,
                      ), // Bayangan blok tebal (Cartoon effect)
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  subtitleText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Color(
                      0xFFFFF9E6,
                    ), // Teks terang (Cream) pada latar cerah
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    shadows: [
                      Shadow(
                        color: Color(
                          0xFF073B4C,
                        ), // Shadow gelap (Navy) mengunci kontras
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () {
                  if (isOnline) {
                    // Reset status ruangan dan player ke standby sebelum kembali ke lobby
                    game.roomRef?.update({'status': 'waiting'});
                    game.roomRef
                        ?.child('players/${game.localPlayerName}')
                        .update({'isReady': false});
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LobbyScreen(
                          roomCode: game.roomCode!,
                          playerName: game.localPlayerName!,
                        ),
                      ),
                    );
                  } else {
                    Navigator.pop(context); // Kembali ke Home (Offline mode)
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD166), // Yellow Button
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF073B4C),
                      width: 3,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFF073B4C), offset: Offset(0, 6)),
                    ],
                  ),
                  child: Text(
                    isOnline ? "BACK TO LOBBY" : "QUIT GAME",
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Color(0xFF073B4C),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
