import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flame/game.dart';
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

  const GameScreen({super.key, this.roomCode, this.playerName});

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
        initialActiveOverlays: const ['TouchControls', 'HUD'],
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
                    value: cooldown / 15.0, // Dibagi 15 detik (durasi max)
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ValueListenableBuilder<List<int>>(
            valueListenable: game.playerLivesNotifier,
            builder: (context, lives, child) {
              return ValueListenableBuilder<List<double>>(
                valueListenable: game.playerDamageNotifier,
                builder: (context, damages, child) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          4, // 4 Kolom (Mendukung hingga 8 Pemain / 2 Baris)
                      mainAxisExtent:
                          105, // Menjamin tinggi setiap slot cukup untuk isi UI-nya
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: lives.length,
                    itemBuilder: (context, index) {
                      // Mencegah error bounds jika UI render lebih cepat dari data
                      if (index >= game.playerNames.length) {
                        return const SizedBox();
                      }

                      double currentDamage = 0.0;
                      if (index < damages.length) {
                        currentDamage = damages[index];
                      }

                      return PlayerHudSlot(
                        label: game.playerNames[index],
                        color: game.playerColors[index],
                        lives: lives[index],
                        damage: currentDamage,
                      );
                    },
                  );
                },
              );
            },
          ),
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

  const PlayerHudSlot({
    super.key,
    required this.label,
    required this.color,
    required this.lives,
    required this.damage,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: lives > 0 ? 1.0 : 0.4, // Redupkan jika sudah mati
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 1. Potret Karakter (Miring / Slanted)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Transform.rotate(
              angle: -0.15, // Efek miring sedikit ke kiri
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color, // Latar warna pemain solid
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      offset: Offset(2, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person, // Placeholder potret karakter
                  color: Colors.white70,
                  size: 36,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 2. Info Kolom (Teks Persentase & Nameplate)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Persentase % dan Gambar Watermark Melingkar
                Stack(
                  alignment: Alignment.bottomLeft,
                  clipBehavior: Clip.none,
                  children: [
                    // Ikon Watermark di latar belakang
                    Positioned(
                      right: 5,
                      bottom: -8,
                      child: Icon(
                        Icons
                            .sports_martial_arts, // Bisa diganti lambang game Anda
                        size: 48,
                        color: color.withOpacity(0.35),
                      ),
                    ),
                    // Teks Persentase dengan Animasi Counter
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: damage),
                      duration: const Duration(
                        milliseconds: 400,
                      ), // Kecepatan putaran counter
                      curve: Curves
                          .easeOutCubic, // Melesat cepat di awal, melambat lembut di akhir
                      builder: (context, animatedDamage, child) {
                        // Pindahkan logika pewarnaan ke dalam builder
                        // agar warna berubah presisi selaras dengan putaran angkanya
                        Color damageColor = Colors.white;
                        if (animatedDamage >= 150) {
                          damageColor = const Color(
                            0xFFA30000,
                          ); // Merah Gelap (Kritis)
                        } else if (animatedDamage >= 90) {
                          damageColor = const Color(
                            0xFFFF0000,
                          ); // Merah Terang (Bahaya)
                        } else if (animatedDamage >= 40) {
                          damageColor = const Color(
                            0xFFFFD700,
                          ); // Kuning Emas (Menengah)
                        }

                        return Text(
                          "${animatedDamage.toStringAsFixed(1)}%", // Format desimal '0.0%'
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: damageColor,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            shadows: const [
                              // Efek outline tipis warna hitam & bayangan drop
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
                                color: Colors.black54,
                                blurRadius: 4,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // Nameplate (Abu-abu Gelap + Aksen Warna Pemain)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C), // Dark Grey
                    border: Border(
                      top: BorderSide(color: color, width: 3), // Garis aksen
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        offset: Offset(0, 2),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Teks Nama Karakter
                      Text(
                        label.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Indikator Nyawa (Lives)
                      Row(
                        children: List.generate(3, (index) {
                          return Icon(
                            index < lives
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: index < lives ? color : Colors.grey[600],
                            size: 14,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 2),
                            ],
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
