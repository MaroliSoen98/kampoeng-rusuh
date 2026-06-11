import 'package:flutter/material.dart';
import 'main.dart'; // Untuk navigasi ke GameScreen
import 'lobby_screen.dart'; // Menggunakan kembali PlayerSpriteWidget
import 'game/constants/game_constants.dart';

class OfflineLobbyScreen extends StatefulWidget {
  const OfflineLobbyScreen({super.key});

  @override
  State<OfflineLobbyScreen> createState() => _OfflineLobbyScreenState();
}

class _OfflineLobbyScreenState extends State<OfflineLobbyScreen> {
  String _playerCharacter = 'anak_sekolah';

  // Daftar karakter yang bisa Anda pakai
  final List<String> _availableCharacters = [
    'anak_sekolah',
    'pekerja_scbd',
    'ibu_daster',
    'ketua_rt',
    'kurir',
    'hansip',
  ];

  // Daftar karakter default untuk para bot
  final List<String> _botCharacters = [
    'pekerja_scbd',
    'ibu_daster',
    'ketua_rt',
  ];

  // State untuk mengaktifkan/menonaktifkan bot (Bot 1 aktif default)
  final List<bool> _isBotActive = [true, false, false];

  void _changeCharacter(int delta) {
    int currentIndex = _availableCharacters.indexOf(_playerCharacter);
    if (currentIndex == -1) currentIndex = 0;

    int newIndex = (currentIndex + delta) % _availableCharacters.length;
    if (newIndex < 0) newIndex += _availableCharacters.length;

    setState(() {
      _playerCharacter = _availableCharacters[newIndex];
    });
  }

  // Fungsi khusus untuk mengganti karakter para Bot
  void _changeBotCharacter(int botIndex, int delta) {
    int currentIndex = _availableCharacters.indexOf(_botCharacters[botIndex]);
    if (currentIndex == -1) currentIndex = 0;

    int newIndex = (currentIndex + delta) % _availableCharacters.length;
    if (newIndex < 0) newIndex += _availableCharacters.length;

    setState(() {
      _botCharacters[botIndex] = _availableCharacters[newIndex];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4A90E2), // Bright Sky Blue
              Color(0xFF7B61FF), // Fun Purple/Blue
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              children: [
                // ===== HEADER BATTLE =====
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD166),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF073B4C),
                          width: 3,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFF073B4C),
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Color(0xFF073B4C),
                          size: 24,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Column(
                      children: [
                        const Text(
                          'OFFLINE BATTLE',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFFFFD700),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            shadows: [
                              Shadow(
                                color: Color(0xFF1A237E),
                                offset: Offset(2, 2),
                              ),
                              Shadow(
                                color: Colors.black38,
                                offset: Offset(4, 4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9E6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF073B4C),
                              width: 3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xFF073B4C),
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            'CHOOSE YOUR FIGHTER',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: Color(0xFF073B4C),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 56), // Penyeimbang UI
                  ],
                ),

                const Spacer(), // Spacer mengisi ruang kosong menyesuaikan tinggi layar
                // ===== 4 PODIUM CHARACTER SELECTION =====
                _buildPodiums(),

                const Spacer(), // Spacer mengisi ruang kosong menyesuaikan tinggi layar
                // ===== START BATTLE BUTTON =====
                GestureDetector(
                  onTap: () {
                    // Filter hanya bot yang aktif yang akan di-spawn
                    List<String> activeBots = [];
                    for (int i = 0; i < 3; i++) {
                      if (_isBotActive[i]) {
                        activeBots.add(_botCharacters[i]);
                      }
                    }

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GameScreen(
                          offlineCharacter: _playerCharacter,
                          offlineBotCharacters: activeBots,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF476F),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF073B4C),
                        width: 4,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF073B4C),
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Text(
                      'START BATTLE',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPodiums() {
    final List<Color> playerColors = [
      GameConstants.p1Red,
      GameConstants.p2Blue,
      GameConstants.p3Yellow,
      GameConstants.p4Green,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6).withOpacity(0.5),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF073B4C), width: 4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(4, (index) {
          bool isMe = index == 0;
          bool isActive = isMe || _isBotActive[index - 1];

          if (!isActive) {
            return SizedBox(
              width: 180, // Ukuran lebar FIX agar konsisten dengan slot aktif
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    height: 36,
                  ), // Menyamakan tinggi badge 'CPU' agar sejajar
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isBotActive[index - 1] = true;
                      });
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 32),
                          Text(
                            'ADD BOT',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 110,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.6),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      border: Border.all(
                        color: const Color(0xFF073B4C),
                        width: 3,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'EMPTY',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.white54,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          String name = isMe ? "PLAYER 1" : "BOT $index";
          String character = isMe
              ? _playerCharacter
              : _botCharacters[index - 1];

          return SizedBox(
            width: 180, // Ukuran lebar FIX agar tidak ada layout shift
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isMe
                            ? const Color(0xFF06D6A0)
                            : const Color(0xFFEF476F),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF073B4C),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        isMe ? 'YOU' : 'CPU',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: isMe ? const Color(0xFF073B4C) : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          iconSize: 32,
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          color: const Color(0xFFFFD166),
                          onPressed: () => isMe
                              ? _changeCharacter(-1)
                              : _changeBotCharacter(index - 1, -1),
                        ),
                        Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            PlayerSpriteWidget(
                              isMe: isMe,
                              character: character,
                            ),
                            if (isMe)
                              const Positioned(
                                top: -20,
                                child: Icon(
                                  Icons.arrow_drop_down,
                                  color: Color(0xFFFFD700),
                                  size: 48,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        IconButton(
                          iconSize: 32,
                          icon: const Icon(Icons.arrow_forward_ios_rounded),
                          color: const Color(0xFFFFD166),
                          onPressed: () => isMe
                              ? _changeCharacter(1)
                              : _changeBotCharacter(index - 1, 1),
                        ),
                      ],
                    ),
                    Container(
                      width: 110,
                      height: 36,
                      decoration: BoxDecoration(
                        color: playerColors[index],
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        border: Border.all(
                          color: const Color(0xFF073B4C),
                          width: 3,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFF073B4C),
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isMe)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isBotActive[index - 1] = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF476F),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
