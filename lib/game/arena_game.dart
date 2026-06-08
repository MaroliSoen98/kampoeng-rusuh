import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'constants/game_constants.dart';
import 'components/platform_component.dart';
import 'components/player_character.dart';
import 'components/bot_controller.dart';
import 'systems/spawn_manager.dart';
import '../main.dart'; // Tambahkan import ini untuk mengakses Overlay dari main.dart

class ArenaGame extends FlameGame with HasKeyboardHandlerComponents {
  late final SpawnManager spawnManager;
  final List<PlatformComponent> platforms = [];

  PlayerCharacter? player1;

  final ValueNotifier<List<int>> playerLivesNotifier = ValueNotifier([]);
  final ValueNotifier<List<double>> playerDamageNotifier = ValueNotifier([]);
  final ValueNotifier<List<int>> playerRespawnNotifier = ValueNotifier([]);
  double matchTimer = 180.0;
  final ValueNotifier<int> matchTimerNotifier = ValueNotifier(180);
  List<String> playerNames = [];
  List<Color> playerColors = [];

  bool isGameOver = false;
  String winnerName = "";

  final ValueNotifier<double> p1GrabCooldownNotifier = ValueNotifier(0.0);
  double shakeTimer = 0.0;
  double shakeIntensity = 0.0;
  Vector2 baseCameraPosition = Vector2.zero();

  final String? roomCode;
  final String? localPlayerName;
  final String offlineCharacter;
  final List<String> offlineBotCharacters;

  DatabaseReference? roomRef;
  double syncTimer = 0.0;

  // --- Variabel untuk Kamera Zoom Home Run ---
  double defaultZoom = 1.0;
  double zoomTimer = 0.0;
  Vector2 zoomFocusPosition = Vector2.zero();

  // --- Variabel untuk Slow Motion ---
  double _slowMoTimer = 0.0;
  final double _slowMoFactor =
      0.15; // Seberapa lambat (0.15 = 15% kecepatan normal)
  double timeScale = 1.0; // Definisi variabel timeScale untuk slow motion

  ArenaGame({
    this.roomCode,
    this.localPlayerName,
    this.offlineCharacter = 'anak_sekolah',
    this.offlineBotCharacters = const [
      'pekerja_scbd',
      'ibu_daster',
      'ketua_rt',
    ],
  }) : super(
         // Hapus FixedResolution agar tidak ada clipping/batasan hitam di layar lebar
         camera: CameraComponent(),
       );

  // Definisikan overlay di sini agar bisa diakses sebelum game di-render
  Map<String, Widget Function(BuildContext, Game)> get overlayBuilderMap => {
    'TouchControls': (context, game) {
      return TouchControlsOverlay(game: this);
    },
    'HUD': (context, game) {
      return HUDOverlay(game: this);
    },
    'GameOver': (context, game) {
      return GameOverOverlay(game: this);
    },
  };

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size.y == 0) return;

    // Sesuaikan zoom kamera agar tinggi layar selalu pas dengan tinggi arena (720)
    defaultZoom = size.y / GameConstants.worldHeight;
    if (zoomTimer <= 0) {
      camera.viewfinder.zoom = defaultZoom;
    }

    // Hitung offset agar pusat arena (1280px) berada tepat di tengah layar ultra-wide
    double visibleWidth = size.x / defaultZoom;
    double offsetX = (GameConstants.worldWidth - visibleWidth) / 2;

    baseCameraPosition = Vector2(offsetX, 0);
    if (zoomTimer <= 0 && shakeTimer <= 0)
      camera.viewfinder.position = baseCameraPosition.clone();
    camera.viewfinder.anchor = Anchor.topLeft;
  }

  @override
  Color backgroundColor() => GameConstants.bgDarkBrown;

  @override
  Future<void> onLoad() async {
    try {
      _createArena();

      spawnManager = SpawnManager(this);

      if (roomCode != null && localPlayerName != null) {
        await _initMultiplayer();
      } else {
        spawnManager.initialSpawns(); // Mode offline / Bot
      }
    } catch (e) {
      debugPrint('Error saat meload game: $e');
    }
  }

  Future<void> _initMultiplayer() async {
    roomRef = FirebaseDatabase.instance.ref('rooms/$roomCode');
    final snapshot = await roomRef!.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>?;
      if (data == null || data['players'] == null) {
        debugPrint('Data room tidak valid atau belum ada player!');
        return;
      }

      // Mencegah crash jika struktur data players terbaca sebagai List oleh Firebase
      final playersRaw = data['players'];
      final playersData = playersRaw is List
          ? playersRaw.asMap()
          : playersRaw as Map<dynamic, dynamic>;

      int index = 0;
      final colors = [
        GameConstants.p1Red,
        GameConstants.p2Blue,
        GameConstants.p3Yellow,
        GameConstants.p4Green,
      ];
      final startPositions = [
        Vector2(200, 100),
        Vector2(1000, 100),
        Vector2(200, 400),
        Vector2(1000, 400),
      ];

      playerNames.clear();
      playerColors.clear();

      // Urutkan secara alfabetis, kemudian kunci host di posisi indeks paling pertama (P1)
      final hostName = data['host'] as String? ?? '';
      final sortedKeys = playersData.keys.map((e) => e.toString()).toList()
        ..sort();
      if (sortedKeys.contains(hostName)) {
        sortedKeys.remove(hostName);
        sortedKeys.insert(0, hostName);
      }

      // Spawn semua pemain Party
      for (var key in sortedKeys) {
        String pName = key;
        bool isMe = pName == localPlayerName;

        // Ambil karakter yang dipilih
        final pData = playersData[pName] as Map<dynamic, dynamic>?;
        final pChar = pData?['character'] as String? ?? 'anak_sekolah';

        playerNames.add(pName);
        playerColors.add(colors[index % colors.length]);

        final player = PlayerCharacter(
          label: pName,
          color: colors[index % colors.length],
          position: startPositions[index % startPositions.length],
          playerIndex: index,
          isPlayer: isMe,
          isRemotePlayer: !isMe,
          characterName: pChar,
        );

        world.add(player);
        if (isMe) {
          player1 = player;
        }
        index++;
      }
      playerLivesNotifier.value = List.filled(index, 3);
      playerDamageNotifier.value = List.filled(index, 0.0);
      playerRespawnNotifier.value = List.filled(index, 0);

      int matchMinutes = data['matchTime'] as int? ?? 3;
      matchTimer = matchMinutes * 60.0;
      matchTimerNotifier.value = matchTimer.ceil();

      // Pasang Pendengar Event (Pukulan & Tangkapan) untuk Pemain Lokal (Diri Sendiri)
      roomRef!.child('players/$localPlayerName/incomingHit').onValue.listen((
        event,
      ) {
        if (event.snapshot.value != null) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          player1?.receiveHit(
            data['vx'] as num,
            data['vy'] as num,
            data['stun'] as num,
            damageAdded: data['damageAdded'] as num?,
          );
          // Hapus event agar tidak terpicu dua kali
          roomRef!.child('players/$localPlayerName/incomingHit').remove();
        }
      });

      roomRef!.child('players/$localPlayerName/incomingGrab').onValue.listen((
        event,
      ) {
        if (event.snapshot.value != null) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          player1?.receiveGrab(
            data['action'] as String,
            data['by'] as String?,
            data['vx'] as num?,
            data['vy'] as num?,
            data['stun'] as num?,
            damageAdded: data['damageAdded'] as num?,
          );
          roomRef!.child('players/$localPlayerName/incomingGrab').remove();
        }
      });

      // Dengarkan perubahan posisi dan animasi dari pemain jarak jauh (Party)
      roomRef!.child('players').onValue.listen((event) {
        if (event.snapshot.value == null) return;
        final pDataMap = event.snapshot.value as Map<dynamic, dynamic>;

        for (final p in world.children.whereType<PlayerCharacter>()) {
          if (p.isRemotePlayer) {
            final pData = pDataMap[p.label];
            if (pData != null && pData['pos'] != null) {
              p.targetNetworkPosition = Vector2(
                (pData['pos']['x'] as num).toDouble(),
                (pData['pos']['y'] as num).toDouble(),
              );
              p.velocity.x = (pData['pos']['vx'] as num).toDouble();
              p.velocity.y = (pData['pos']['vy'] as num).toDouble();
              p.isGrounded = pData['pos']['g'] == true;

              if (pData['pos']['dir'] != null) {
                final dirName = pData['pos']['dir'] as String;
                p.setFacingDirection(
                  MoveDirection.values.firstWhere(
                    (e) => e.name == dirName,
                    orElse: () => MoveDirection.right,
                  ),
                );
              }

              if (pData['pos']['anim'] != null) {
                final animName = pData['pos']['anim'] as String;
                final animState = PlayerState.values.firstWhere(
                  (e) => e.name == animName,
                  orElse: () => PlayerState.idle,
                );
                if (p.currentAnimation != animState) {
                  p.currentAnimation = animState;
                  p.animationTickers?[p.currentAnimation]?.reset();
                }
              }

              if (pData['pos']['lives'] != null) {
                int remoteLives = (pData['pos']['lives'] as num).toInt();
                int pIndex = playerNames.indexOf(p.label);
                if (pIndex != -1 &&
                    playerLivesNotifier.value.isNotEmpty &&
                    playerLivesNotifier.value[pIndex] != remoteLives) {
                  final newLives = List<int>.from(playerLivesNotifier.value);
                  newLives[pIndex] = remoteLives;
                  playerLivesNotifier.value =
                      newLives; // Otomatis meng-update HUD nyawa di layar Anda
                }
              }

              if (pData['pos']['damage'] != null) {
                double remoteDamage = (pData['pos']['damage'] as num)
                    .toDouble();
                if (p.damagePercentage != remoteDamage) {
                  // Mencegah indikator UI mundur/berkedip karena delay ping internet.
                  // Update hanya jika damage naik, atau ketika musuh terkonfirmasi mati (reset ke 0).
                  if (remoteDamage > p.damagePercentage ||
                      remoteDamage == 0.0) {
                    // FIX: Pastikan UI lawan mereset ke 0.0% saat respawn
                    p.damagePercentage = remoteDamage;
                    p.updateDamageUI();
                  }
                }
              }

              if (pData['pos']['dead'] != null) {
                bool isNowDead = pData['pos']['dead'] == true;
                if (isNowDead && !p.isDead) {
                  p.spawnRingOutEffect();
                }
                p.isDead = isNowDead;
                if (isNowDead && p.parent != null) p.removeFromParent();
              }

              if (pData['pos']['respawning'] != null) {
                bool respawning = pData['pos']['respawning'] == true;
                if (respawning && !p.isRespawning) {
                  p.spawnRingOutEffect();
                  p.respawnTimer =
                      5.0; // Trigger timer UI lokal untuk bot/lawan
                  p.isRespawning = true;
                  p.position = Vector2(-100, -100);
                  p.velocity = Vector2.zero();
                } else if (!respawning && p.isRespawning) {
                  p.isRespawning = false;
                }
              }
            }
          }
        }
      });
    }
  }

  void updateRespawnUI(int index, int seconds) {
    if (index >= 0 && index < playerRespawnNotifier.value.length) {
      final list = List<int>.from(playerRespawnNotifier.value);
      list[index] = seconds;
      playerRespawnNotifier.value = list;
    }
  }

  @override
  void update(double dt) {
    // --- Logika Slow Motion ---
    // Harus dijalankan di awal agar dt untuk semua child ter-update dengan benar
    if (_slowMoTimer > 0) {
      // dt di ArenaGame.update adalah waktu asli (unscaled), jadi timer berjalan secara real-time
      _slowMoTimer -= dt;
      if (_slowMoTimer <= 0) {
        timeScale = 1.0; // Kembalikan kecepatan normal saat timer habis
      }
    }

    super.update(
      dt * timeScale,
    ); // Terapkan slow motion ke seluruh komponen dalam game (Karakter, Fisika, Animasi)

    // Sinkronisasi posisi player local ke Firebase (20x per detik)
    // Kondisi !isDead dihapus agar saat pemain mati, status dead-nya tetap terkirim ke lawan.
    if (roomRef != null && player1 != null) {
      syncTimer -= dt;
      if (syncTimer <= 0) {
        syncTimer =
            0.03; // DIPERCEPAT: dari 20 FPS ke 33 FPS agar sangat mulus!
        int myIndex = playerNames.indexOf(localPlayerName!);
        int myLives = playerLivesNotifier.value.isNotEmpty
            ? playerLivesNotifier.value[myIndex]
            : 3;
        roomRef!.child('players/$localPlayerName/pos').set({
          'x': player1!.position.x,
          'y': player1!.position.y,
          'vx': player1!.velocity.x,
          'vy': player1!.velocity.y,
          'g': player1!.isGrounded,
          'dir': player1!.facingDirectionName,
          'anim': player1!.currentAnimation.name,
          'lives': myLives,
          'dead': player1!.isDead,
          'respawning': player1!.isRespawning,
          'damage': player1!.damagePercentage,
        });
      }
    }

    // --- EFEK KAMERA ZOOM & SHAKE ---
    Vector2 currentCamTarget = baseCameraPosition.clone();

    if (zoomTimer > 0) {
      zoomTimer -= dt;

      double maxZoom =
          defaultZoom * 1.6; // Skala Zoom-in 1.6x (Sangat dekat & dramatis!)
      double currentZoom = defaultZoom;
      double t = 0.0; // Interpolasi pentalan layar

      if (zoomTimer > 0.8) {
        t = (1.0 - zoomTimer) / 0.2; // Fase tarik (masuk) super cepat
        currentZoom = defaultZoom + (maxZoom - defaultZoom) * t;
      } else if (zoomTimer > 0.2) {
        t = 1.0; // Fase hold (menahan zoom)
        currentZoom = maxZoom;
      } else {
        t = zoomTimer / 0.2; // Fase lepas (mundur/kembali semula)
        currentZoom = defaultZoom + (maxZoom - defaultZoom) * t;
      }

      if (zoomTimer <= 0) {
        camera.viewfinder.zoom = defaultZoom;
      } else {
        camera.viewfinder.zoom = currentZoom;
        Vector2 screenCenterOffset = (size / currentZoom) / 2;
        Vector2 idealCamPos = zoomFocusPosition - screenCenterOffset;

        currentCamTarget.x =
            baseCameraPosition.x + (idealCamPos.x - baseCameraPosition.x) * t;
        currentCamTarget.y =
            baseCameraPosition.y + (idealCamPos.y - baseCameraPosition.y) * t;
      }
    } else {
      camera.viewfinder.zoom = defaultZoom;
    }

    if (shakeTimer > 0) {
      shakeTimer -= dt;
      final random = Random();
      final dx = (random.nextDouble() - 0.5) * shakeIntensity;
      final dy = (random.nextDouble() - 0.5) * shakeIntensity;
      camera.viewfinder.position = currentCamTarget + Vector2(dx, dy);
    } else {
      camera.viewfinder.position = currentCamTarget;
    }

    p1GrabCooldownNotifier.value = player1?.grabCooldownTimer ?? 0.0;

    if (!isGameOver) {
      if (playerNames.isNotEmpty && matchTimer > 0) {
        matchTimer -= dt;
        if (matchTimer <= 0) {
          matchTimer = 0;
          _triggerGameOverByTime();
        }
        int currentSec = matchTimer.ceil();
        if (matchTimerNotifier.value != currentSec) {
          matchTimerNotifier.value = currentSec;
        }
      }

      final currentLives = playerLivesNotifier.value;
      int aliveCount = currentLives.where((l) => l > 0).length;

      // Mengecek length > 1 sudah cukup untuk memastikan pemain sudah berhasil load/inisialisasi.
      // Pengecekan world.children dihapus agar kematian player terakhir tetap terdeteksi.
      if (currentLives.length > 1 && aliveCount <= 1) {
        isGameOver = true;
        int winnerIndex = currentLives.indexWhere((l) => l > 0);
        winnerName = winnerIndex != -1
            ? playerNames[winnerIndex]
            : "TIDAK ADA YANG";
        overlays.add('GameOver');
      }
    }
  }

  void shakeCamera({double intensity = 8.0, double duration = 0.2}) {
    shakeIntensity = intensity;
    shakeTimer = duration;
  }

  void triggerHomeRunZoom(Vector2 focusPos) {
    zoomFocusPosition = focusPos.clone();
    zoomTimer = 1.0; // Zoom akan berlangsung selama total 1 detik penuh
  }

  void triggerSlowMo({required double realWorldDuration}) {
    timeScale = _slowMoFactor;
    // Timer diupdate menggunakan waktu asli (unscaled), cukup set durasi sesuai real time
    _slowMoTimer = realWorldDuration;
  }

  void _triggerGameOverByTime() {
    isGameOver = true;
    final currentLives = playerLivesNotifier.value;
    final damages = playerDamageNotifier.value;
    int bestIndex = -1;
    int maxLives = -1;
    double minDamage = double.infinity;

    for (int i = 0; i < currentLives.length; i++) {
      if (currentLives[i] > maxLives) {
        maxLives = currentLives[i];
        minDamage = damages[i];
        bestIndex = i;
      } else if (currentLives[i] == maxLives) {
        if (damages[i] < minDamage) {
          minDamage = damages[i];
          bestIndex = i;
        } else if (damages[i] == minDamage) {
          bestIndex = -1; // Seri
        }
      }
    }

    winnerName = bestIndex != -1 ? playerNames[bestIndex] : "TIDAK ADA YANG";
    overlays.add('GameOver');
  }

  void retry() {
    isGameOver = false;
    overlays.remove('GameOver');
    playerLivesNotifier.value = List.filled(playerNames.length, 3);
    playerDamageNotifier.value = List.filled(playerNames.length, 0.0);
    playerRespawnNotifier.value = List.filled(playerNames.length, 0);
    matchTimer = 180.0; // Default fallback for offline
    world.children.whereType<PlayerCharacter>().forEach(
      (p) => p.removeFromParent(),
    );
    if (roomCode != null && localPlayerName != null) {
      _initMultiplayer(); // Re-sync / respawn saat online
    } else {
      spawnManager.initialSpawns();
    }
  }

  void _createArena() {
    // Platform dasar utama di bawah
    _addPlatform(Vector2(140, 600), Vector2(1000, 50));

    // Platform tengah kiri
    _addPlatform(Vector2(100, 450), Vector2(250, 30));

    // Platform tengah kanan
    _addPlatform(Vector2(930, 450), Vector2(250, 30));

    // Platform pusat
    _addPlatform(Vector2(490, 350), Vector2(300, 30));

    // Platform kiri atas
    _addPlatform(Vector2(250, 200), Vector2(200, 30));

    // Platform kanan atas
    _addPlatform(Vector2(830, 200), Vector2(200, 30));
  }

  void _addPlatform(Vector2 position, Vector2 size) {
    final platform = PlatformComponent(position: position, size: size);
    platforms.add(platform);
    world.add(platform);
  }
}
