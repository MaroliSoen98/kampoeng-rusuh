import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'main.dart'; // Perbaikan import karena sekarang posisinya selevel (sama-sama di folder lib)

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

              int readyCount = players.values
                  .where((p) => p['isReady'] == true)
                  .length;
              int totalPlayers = players.length;
              bool isMeReady = players[widget.playerName]?['isReady'] ?? false;
              bool allReady = totalPlayers > 0 && readyCount == totalPlayers;

              final hostName = data['host'] as String? ?? '';
              final isHost = hostName == widget.playerName;

              return Padding(
                padding: const EdgeInsets.all(16.0),
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
                          ],
                        ),
                        const SizedBox(width: 56), // Spacer penyeimbang
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ===== MODERN CARTOON TABLE =====
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 500),
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
                                  final String pName = players.keys.elementAt(
                                    index,
                                  );
                                  final bool pReady =
                                      players[pName]?['isReady'] ?? false;
                                  final bool isMe = pName == widget.playerName;

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
                                      borderRadius: BorderRadius.circular(16),
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
                                                  ? const Color(0xFFFFD166)
                                                  : const Color(0xFFE0E0E0),
                                              child: Icon(
                                                Icons.person,
                                                size: 16,
                                                color: const Color(0xFF073B4C),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Text(
                                              pName,
                                              style: TextStyle(
                                                fontFamily: 'monospace',
                                                color: const Color(0xFF073B4C),
                                                fontSize: 14,
                                                fontWeight: isMe
                                                    ? FontWeight.w900
                                                    : FontWeight.normal,
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
                                                      BorderRadius.circular(8),
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
                                                    fontFamily: 'monospace',
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        // Badge Status
                                        Container(
                                          padding: const EdgeInsets.symmetric(
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
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFF073B4C),
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
                                                  ? const Color(0xFF073B4C)
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
}
