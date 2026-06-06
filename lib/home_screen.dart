import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:kampoeng_rusuh/lobby_screen.dart';
import 'package:kampoeng_rusuh/main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _roomCodeController = TextEditingController();

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        5,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  void _createRoom(BuildContext context, String playerName) async {
    final String roomCode = _generateRoomCode();

    try {
      // Buat node room baru di Realtime Database
      final DatabaseReference roomRef = FirebaseDatabase.instance.ref(
        'rooms/$roomCode',
      );
      await roomRef.set({
        'status': 'waiting',
        'host': playerName,
        'players': {
          playerName: {'isReady': false},
        },
      });

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                LobbyScreen(roomCode: roomCode, playerName: playerName),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating room: $e');
    }
  }

  void _joinRoom(
    BuildContext context,
    String playerName,
    String roomCode,
  ) async {
    try {
      final DatabaseReference roomRef = FirebaseDatabase.instance.ref(
        'rooms/$roomCode',
      );
      final DataSnapshot snapshot = await roomRef.get();
      if (snapshot.exists) {
        await roomRef.child('players/$playerName').set({'isReady': false});

        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  LobbyScreen(roomCode: roomCode, playerName: playerName),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Room not found!')));
        }
      }
    } catch (e) {
      debugPrint('Error joining room: $e');
    }
  }

  void _showCreateRoomDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF9E6), // Warm Cream
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24), // Cartoonish rounded
            side: const BorderSide(
              color: Color(0xFF073B4C),
              width: 3,
            ), // Dark Navy
          ),
          title: const Text(
            'CREATE ROOM',
            style: TextStyle(
              color: Color(0xFF073B4C), // Dark Navy
              fontWeight: FontWeight.w900,
            ),
          ),
          content: TextField(
            controller: nameController,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'PLAYER NAME',
              hintStyle: const TextStyle(
                color: Colors.black38,
                letterSpacing: 2.0,
                fontSize: 16,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                  color: Color(0xFF073B4C),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                  color: Color(0xFF118AB2),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD166), // Vibrant Yellow
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF073B4C), width: 2),
                ),
              ),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(dialogContext);
                  _createRoom(context, name);
                }
              },
              child: const Text(
                'CREATE',
                style: TextStyle(
                  color: Color(0xFF073B4C),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showJoinNameDialog(BuildContext context, String roomCode) {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF9E6), // Warm Cream
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24), // Cartoonish rounded
            side: const BorderSide(
              color: Color(0xFF073B4C),
              width: 3,
            ), // Dark Navy
          ),
          title: Text(
            'JOIN ROOM $roomCode',
            style: const TextStyle(
              color: Color(0xFF073B4C), // Dark Navy
              fontWeight: FontWeight.w900,
            ),
          ),
          content: TextField(
            controller: nameController,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'PLAYER NAME',
              hintStyle: const TextStyle(
                color: Colors.black38,
                letterSpacing: 2.0,
                fontSize: 16,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                  color: Color(0xFF073B4C),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                  color: Color(0xFF118AB2),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06D6A0), // Bright Teal
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF073B4C), width: 2),
                ),
              ),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(dialogContext);
                  _joinRoom(context, name, roomCode);
                }
              },
              child: const Text(
                'JOIN',
                style: TextStyle(
                  color: Color(0xFF073B4C),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
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
          child: Center(
            // SingleChildScrollView mencegah layar overflow pada mode landscape (HP kecil)
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. Pixel Art Title Logo
                  const Icon(
                    Icons.flare_outlined, // Fun, explosive icon
                    color: Color(0xFFFFD700), // Gold/Yellow
                    size: 60,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'KAMPOENG\nRUSUH',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'monospace', // Retro feel
                      color: Color(0xFFFFD700), // Gold/Yellow
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: 4.0,
                      shadows: [
                        Shadow(color: Color(0xFF1A237E), offset: Offset(3, 3)),
                        Shadow(color: Colors.black38, offset: Offset(6, 6)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // 2. Center Stacked Buttons
                  _buildPixelButton(
                    text: 'CREATE ROOM',
                    color: const Color(0xFFFFD166), // Vibrant Yellow
                    textColor: const Color(0xFF073B4C), // Dark Navy Text
                    width: 350,
                    onTap: () => _showCreateRoomDialog(context),
                  ),
                  const SizedBox(height: 16),
                  _buildJoinRoomInput(context),
                  const SizedBox(height: 24),
                  _buildPixelButton(
                    text: 'OFFLINE MODE',
                    color: const Color(0xFFEF476F), // Coral Pink
                    textColor: Colors.white,
                    width: 250,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GameScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinRoomInput(BuildContext context) {
    return Container(
      width: 350,
      height: 55,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA), // Off-white
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF073B4C), width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0xFF073B4C), offset: Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17), // Inside the border
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextField(
                controller: _roomCodeController,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
                textCapitalization: TextCapitalization.characters,
                textAlignVertical: TextAlignVertical.center,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  // Padding bawah diperbesar lagi untuk mendorong teks lebih ke atas
                  contentPadding: EdgeInsets.only(bottom: 16),
                  hintText: 'ROOM CODE',
                  hintStyle: TextStyle(
                    color: Colors.black38,
                    letterSpacing: 1.0,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                final roomCode = _roomCodeController.text.trim().toUpperCase();
                if (roomCode.isNotEmpty) {
                  _showJoinNameDialog(context, roomCode);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ENTER ROOM CODE FIRST!')),
                  );
                }
              },
              child: Container(
                width: 100,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF06D6A0), // Bright Teal
                  border: Border(
                    left: BorderSide(color: Color(0xFF073B4C), width: 3),
                  ),
                ),
                child: const Text(
                  'JOIN',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFF073B4C), // Dark Navy
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Reusable widget untuk membangkitkan style tombol yang cartoonish dan rounded
  Widget _buildPixelButton({
    required String text,
    required Color color,
    required Color textColor,
    required double width,
    double height = 55,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF073B4C),
            width: 3,
          ), // Dark Navy
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF073B4C),
              offset: Offset(0, 6), // 3D cartoon drop shadow
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'monospace',
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }
}
