import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'main.dart'; // Perbaikan import karena sekarang posisinya selevel (sama-sama di folder lib)
import 'game/constants/game_constants.dart';
import 'package:flame/flame.dart';
import 'package:flame/sprite.dart';
import 'package:flame/widgets.dart';
import 'package:flame/components.dart';

class LobbyScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;

  const LobbyScreen({
    super.key,
    required this.roomCode,
    required this.playerName,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late final StreamSubscription<DatabaseEvent> _roomSubscription;
  bool _isExiting =
      false; // Penanda untuk mencegah notifikasi saat keluar manual

  @override
  void initState() {
    super.initState();
    // Dengarkan perubahan status room di sini, HANYA untuk navigasi.
    _roomSubscription = FirebaseDatabase.instance
        .ref('rooms/${widget.roomCode}')
        .onValue
        .listen((event) {
          if (!mounted || event.snapshot.value == null) return;
          final data = (event.snapshot.value as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
          final status = data['status'] as String? ?? 'waiting';
          if (status == 'playing') {
            _roomSubscription
                .cancel(); // Hentikan langganan agar tidak navigasi 2x
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => GameScreen(
                  roomCode: widget.roomCode,
                  playerName: widget.playerName,
                ),
              ),
            );
          }
        });
  }

  @override
  void dispose() {
    _roomSubscription
        .cancel(); // Selalu batalkan subscription saat screen ditutup
    super.dispose();
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
          child: StreamBuilder<DatabaseEvent>(
            // StreamBuilder ini sekarang HANYA untuk update UI lobi
            stream: FirebaseDatabase.instance
                .ref('rooms/${widget.roomCode}')
                .onValue,
            builder: (context, snapshot) {
              // Tunggu data pertama kali dimuat dari Firebase
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                // Jika kita sedang dalam proses keluar manual, jangan tampilkan notif.
                // Cukup tampilkan loading singkat selagi proses pop berjalan.
                if (_isExiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Jika room tiba-tiba tidak ada (misal: dihapus host),
                // kembali ke menu utama.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Room has been closed.')),
                    );
                  }
                });
                // Tampilkan loading sementara proses pop terjadi
                return const Center(child: CircularProgressIndicator());
              }

              final Map<dynamic, dynamic> rawData =
                  snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
              final Map<String, dynamic> data = rawData.cast<String, dynamic>();

              final players = data['players'] != null
                  ? (data['players'] as Map<dynamic, dynamic>)
                        .cast<String, dynamic>()
                  : <String, dynamic>{};

              final hostName = data['host'] as String? ?? '';
              final isHost = hostName == widget.playerName;

              final sortedPlayerNames = players.keys.toList().cast<String>()
                ..sort();
              // Pastikan host selalu berada di urutan paling kiri (Player 1)
              if (sortedPlayerNames.contains(hostName)) {
                sortedPlayerNames.remove(hostName);
                sortedPlayerNames.insert(0, hostName);
              }

              int readyCount = players.values
                  .where((p) => p['isReady'] == true)
                  .length;
              int totalPlayers = players.length;
              bool isMeReady = players[widget.playerName]?['isReady'] ?? false;
              bool allReady = totalPlayers > 0 && readyCount == totalPlayers;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ), // Padding vertikal diperkecil
                child: Column(
                  children: [
                    // ===== HEADER LOBBY =====
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
                            onPressed: () async {
                              // Tandai bahwa kita sedang dalam proses keluar manual
                              setState(() {
                                _isExiting = true;
                              });

                              // Hapus data pemain dari room saat keluar
                              final roomRef = FirebaseDatabase.instance.ref(
                                'rooms/${widget.roomCode}',
                              );
                              if (isHost) {
                                // Host keluar, hapus seluruh room
                                await roomRef.remove();
                              } else {
                                // Pemain biasa keluar, hapus data diri sendiri
                                await roomRef
                                    .child('players/${widget.playerName}')
                                    .remove();
                              }
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                        ),
                        Column(
                          children: [
                            const Text(
                              'LOBBY ROOM',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: Color(0xFFFFD700), // Gold/Yellow
                                fontSize:
                                    24, // Diperkecil dari 28 agar tidak makan tempat
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
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
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 2, // Diperkecil
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF9E6), // Warm Cream
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
                              child: Text(
                                'CODE: ${widget.roomCode}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  color: Color(0xFF073B4C),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
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
                                  ),
                                  child: Text(
                                    'READY: $readyCount/$totalPlayers',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      color: Color(0xFF073B4C),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // ===== MATCH TIME SELECTOR =====
                                GestureDetector(
                                  onTap: isHost
                                      ? () {
                                          int matchTime =
                                              data['matchTime'] as int? ?? 3;
                                          int nextTime = matchTime == 3
                                              ? 5
                                              : (matchTime == 5 ? 8 : 3);
                                          FirebaseDatabase.instance
                                              .ref('rooms/${widget.roomCode}')
                                              .update({'matchTime': nextTime});
                                        }
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isHost
                                          ? const Color(0xFFFFD166)
                                          : const Color(0xFFFFF9E6),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFF073B4C),
                                        width: 3,
                                      ),
                                      boxShadow: isHost
                                          ? const [
                                              BoxShadow(
                                                color: Color(0xFF073B4C),
                                                offset: Offset(0, 3),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.timer,
                                          color: Color(0xFF073B4C),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'TIME: ${data['matchTime'] as int? ?? 3} MINS',
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            color: Color(0xFF073B4C),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        if (isHost) ...[
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.loop,
                                            color: Color(0xFF073B4C),
                                            size: 18,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: 56), // Spacer penyeimbang
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ===== MAIN CONTENT: PODIUM & TABLE =====
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Area Kiri: Podium
                          Expanded(
                            flex: 2, // Menggunakan rasio 2 (66.6%)
                            child: _buildPodiums(
                              sortedPlayerNames,
                              players,
                              widget.playerName,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Area Kanan: Tabel
                          Expanded(
                            flex: 1, // Menggunakan rasio 1 (33.3%)
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF9E6), // Warm Cream
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFF073B4C),
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0xFF073B4C),
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Table Header
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFFD166), // Yellow
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Color(0xFF073B4C),
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'PLAYER',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            color: Color(0xFF073B4C),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        Text(
                                          'STATUS',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            color: Color(0xFF073B4C),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Table Body (List Pemain)
                                  Expanded(
                                    child: ListView.separated(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      itemCount: players.length,
                                      separatorBuilder: (context, index) =>
                                          const Divider(
                                            color: Color(0xFF073B4C),
                                            thickness: 1,
                                            height: 4,
                                          ),
                                      itemBuilder: (context, index) {
                                        final String pName = players.keys
                                            .elementAt(index);
                                        final bool pReady =
                                            players[pName]?['isReady'] ?? false;
                                        final bool isMe =
                                            pName == widget.playerName;

                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isMe
                                                ? const Color(
                                                    0xFF4A90E2,
                                                  ).withOpacity(0.15)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 12,
                                                    backgroundColor: isMe
                                                        ? const Color(
                                                            0xFFFFD166,
                                                          )
                                                        : const Color(
                                                            0xFFE0E0E0,
                                                          ),
                                                    child: Icon(
                                                      Icons.person,
                                                      size: 16,
                                                      color: const Color(
                                                        0xFF073B4C,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  // Expanded agar nama panjang terpotong '...' dan tidak merusak layout
                                                  Expanded(
                                                    child: Text(
                                                      pName,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontFamily: 'monospace',
                                                        color: const Color(
                                                          0xFF073B4C,
                                                        ),
                                                        fontSize: 14,
                                                        fontWeight: isMe
                                                            ? FontWeight.w900
                                                            : FontWeight.normal,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isMe) ...[
                                                    const SizedBox(width: 12),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFF4A90E2,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        border: Border.all(
                                                          color: const Color(
                                                            0xFF073B4C,
                                                          ),
                                                          width: 2,
                                                        ),
                                                      ),
                                                      child: const Text(
                                                        'YOU',
                                                        style: TextStyle(
                                                          fontFamily:
                                                              'monospace',
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              // Badge Status
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: pReady
                                                      ? const Color(
                                                          0xFF06D6A0,
                                                        ) // Teal
                                                      : const Color(
                                                          0xFFEF476F,
                                                        ), // Pink
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFF073B4C,
                                                    ),
                                                    width: 2,
                                                  ),
                                                  boxShadow: const [
                                                    BoxShadow(
                                                      color: Color(0xFF073B4C),
                                                      offset: Offset(0, 3),
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  pReady ? 'READY' : 'WAITING',
                                                  style: TextStyle(
                                                    fontFamily: 'monospace',
                                                    color: pReady
                                                        ? const Color(
                                                            0xFF073B4C,
                                                          )
                                                        : Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 1.0,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ===== ACTION BUTTONS =====
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCartoonButton(
                          text: isMeReady ? 'CANCEL READY' : 'READY',
                          color: isMeReady
                              ? const Color(0xFFFFD166) // Yellow
                              : const Color(0xFF06D6A0), // Teal
                          textColor: const Color(0xFF073B4C),
                          onPressed: () {
                            FirebaseDatabase.instance
                                .ref(
                                  'rooms/${widget.roomCode}/players/${widget.playerName}',
                                )
                                .update({'isReady': !isMeReady});
                          },
                        ),
                        const SizedBox(width: 20),
                        if (isHost)
                          _buildCartoonButton(
                            text: 'START GAME',
                            color: const Color(0xFFEF476F), // Pink
                            textColor: Colors.white,
                            disabled: !allReady,
                            onPressed: () {
                              FirebaseDatabase.instance
                                  .ref('rooms/${widget.roomCode}')
                                  .update({'status': 'playing'});
                            },
                          )
                        else
                          _buildCartoonButton(
                            text: 'WAITING HOST',
                            color: const Color(0xFFEF476F),
                            textColor: Colors.white,
                            disabled: true,
                            onPressed: null,
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCartoonButton({
    required String text,
    required Color color,
    required Color textColor,
    required VoidCallback? onPressed,
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onPressed,
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 8,
          ), // Padding vertikal diturunkan
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF073B4C), width: 3),
            boxShadow: disabled
                ? []
                : const [
                    BoxShadow(color: Color(0xFF073B4C), offset: Offset(0, 6)),
                  ],
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'monospace',
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // Fungsi untuk memutar pilihan karakter (Kiri / Kanan)
  void _changeCharacter(int delta, String currentCharacter) {
    final List<String> availableCharacters = [
      'anak_sekolah',
      'pekerja_scbd',
      'ibu_daster',
      'ketua_rt',
    ];

    int currentIndex = availableCharacters.indexOf(currentCharacter);
    if (currentIndex == -1) currentIndex = 0;

    int newIndex = (currentIndex + delta) % availableCharacters.length;
    if (newIndex < 0) newIndex += availableCharacters.length;

    String newChar = availableCharacters[newIndex];
    FirebaseDatabase.instance
        .ref('rooms/${widget.roomCode}/players/${widget.playerName}')
        .update({'character': newChar});
  }

  Widget _buildPodiums(
    List<String> sortedNames,
    Map<String, dynamic> players,
    String myName,
  ) {
    final List<Color> playerColors = [
      GameConstants.p1Red,
      GameConstants.p2Blue,
      GameConstants.p3Yellow,
      GameConstants.p4Green,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6).withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF073B4C), width: 3),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomCenter,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (index) {
            Widget podiumContent;
            if (index < sortedNames.length) {
              final pName = sortedNames[index];
              final pReady = players[pName]?['isReady'] ?? false;
              final pChar = players[pName]?['character'] ?? 'anak_sekolah';
              final isMe = pName == myName;
              final color = playerColors[index % playerColors.length];

              podiumContent = _buildSinglePodium(
                name: pName,
                isReady: pReady,
                isMe: isMe,
                color: color,
                character: pChar,
              );
            } else {
              podiumContent = _buildEmptyPodium();
            }

            // Gunakan fixed width yang sama persis (176px) untuk keempat slot.
            // Ini menjamin jarak gap (celah) tetap rapi dan seimbang seperti di offline lobby.
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: SizedBox(width: 176, child: podiumContent),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSinglePodium({
    required String name,
    required bool isReady,
    required bool isMe,
    required Color color,
    required String character,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ready status bubble
        if (isReady)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF06D6A0), // Teal
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF073B4C), width: 2),
            ),
            child: const Text(
              'READY',
              style: TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFF073B4C),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          )
        else
          const SizedBox(height: 22),

        // Character Mockup & Selection Arrows
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Kiri Arrow
            if (isMe)
              Opacity(
                opacity: isReady ? 0.0 : 1.0, // Disembunyikan jika sudah Ready
                child: IconButton(
                  iconSize: 28,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  color: const Color(0xFFFFD166),
                  onPressed: isReady
                      ? null
                      : () => _changeCharacter(-1, character),
                ),
              )
            else
              const SizedBox(width: 48), // Spacer kosong jika bukan player kita
            // Animated Sprite Stack
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                PlayerSpriteWidget(isMe: isMe, character: character),
                if (isMe)
                  const Positioned(
                    top: -15,
                    child: Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFFFFD700),
                      size: 40,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                    ),
                  ),
              ],
            ),

            // Kanan Arrow
            if (isMe)
              Opacity(
                opacity: isReady ? 0.0 : 1.0, // Disembunyikan jika sudah Ready
                child: IconButton(
                  iconSize: 28,
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                  color: const Color(0xFFFFD166),
                  onPressed: isReady
                      ? null
                      : () => _changeCharacter(1, character),
                ),
              )
            else
              const SizedBox(width: 48), // Spacer kosong jika bukan player kita
          ],
        ),

        // Podium Base
        Container(
          width: 76,
          height: 28,
          decoration: BoxDecoration(
            color: color, // Pindahkan warna tim ke podium ini
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: const Color(0xFF073B4C), width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0xFF073B4C), offset: Offset(0, 4)),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: Colors.white,
              fontSize: 12,
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
    );
  }

  Widget _buildEmptyPodium() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 22),
        const SizedBox(
          height: 80,
        ), // Samakan tinggi dengan ruang karakter & panah
        // Podium Base
        Container(
          width: 76,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C).withOpacity(0.5), // Dark grey podium
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(
              color: const Color(0xFF073B4C).withOpacity(0.5),
              width: 3,
            ),
          ),
          alignment: Alignment.center,
          child: const Text(
            'EMPTY',
            style: TextStyle(
              fontFamily: 'monospace',
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// ====== WIDGET KHUSUS UNTUK ANIMASI SPRITE ======
class PlayerSpriteWidget extends StatefulWidget {
  final bool isMe;
  final String character;

  const PlayerSpriteWidget({
    super.key,
    required this.isMe,
    required this.character,
  });

  @override
  State<PlayerSpriteWidget> createState() => _PlayerSpriteWidgetState();
}

class _PlayerSpriteWidgetState extends State<PlayerSpriteWidget> {
  SpriteAnimation? _idleAnimation;
  SpriteAnimationTicker? _idleAnimationTicker;

  @override
  void initState() {
    super.initState();
    _loadAnimation();
  }

  @override
  void didUpdateWidget(PlayerSpriteWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Deteksi jika variabel character berubah, maka reload ulang animasi!
    if (oldWidget.character != widget.character) {
      _loadAnimation();
    }
  }

  Future<void> _loadAnimation() async {
    setState(() {
      _idleAnimation = null;
      _idleAnimationTicker = null;
    });

    try {
      // Load gambar sesuai dengan parameter character
      final image = await Flame.images.load(
        'characters/${widget.character}.png',
      );
      final spriteSheet = SpriteSheet(
        image: image,
        srcSize: Vector2(64, 64), // Ukuran per frame di gambar
      );

      // Ambil baris ke-0 (Idle Animation)
      final anim = spriteSheet.createAnimation(
        row: 0,
        stepTime: 0.16,
        from: 0,
        to: 6,
      );

      if (mounted) {
        setState(() {
          _idleAnimation = anim;
          _idleAnimationTicker = anim.createTicker();
        });
      }
    } catch (e) {
      debugPrint("Gagal meload sprite ${widget.character}: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Selagi gambar dan animasi belum termuat, tampilkan loading kecil
    if (_idleAnimation == null || _idleAnimationTicker == null) {
      return const SizedBox(
        width: 80,
        height: 80,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.orangeAccent,
            ),
          ),
        ),
      );
    }

    // Tampilkan sprite original tanpa timpaan filter warna
    return SizedBox(
      width: 80,
      height: 80,
      child: SpriteAnimationWidget(
        animation: _idleAnimation!,
        animationTicker: _idleAnimationTicker!,
        playing: true,
        anchor: Anchor.center,
      ),
    );
  }
}
