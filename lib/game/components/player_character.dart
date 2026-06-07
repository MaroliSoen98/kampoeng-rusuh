import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/game_constants.dart';
import 'bot_controller.dart';
import '../arena_game.dart';

enum PlayerState { idle, run, jump, fall, punch, carry }

class PlayerCharacter extends PositionComponent
    with HasGameRef<ArenaGame>, KeyboardHandler {
  final String label;
  final Color color;
  final bool isPlayer;
  final bool isRemotePlayer;
  final int playerIndex;
  final String characterName;

  BotController? _botController;

  Vector2 velocity = Vector2.zero();
  bool isGrounded = false;
  bool isRespawning = false;
  bool isDead = false;
  double respawnTimer = 0.0;
  int _lastRespawnSeconds = 0;
  double damagePercentage = 0.0;

  MoveDirection _currentDirection = MoveDirection.idle;
  MoveDirection _facingDirection = MoveDirection.right;
  bool _wantsToJump = false;
  bool _wantsToGrab = false;
  bool _wantsToPunch = false;
  bool _isDownPressed = false;
  double _ignorePlatformTimer = 0.0;
  int _jumpCount = 0;
  double _rageFlashTimer = 0.0;

  Map<PlayerState, SpriteAnimationTicker>? animationTickers;
  PlayerState currentAnimation = PlayerState.idle;

  PlayerCharacter? grabbedCharacter;
  double grabTimer = 0.0;
  bool isGrabbed = false;
  double stunTimer = 0.0;
  double hitstopTimer = 0.0;
  double punchTimer = 0.0;
  double grabCooldownTimer = 0.0;

  int comboCount = 0;
  double comboResetTimer = 0.0;
  String? grabbedByLabel;
  Vector2? targetNetworkPosition;

  late TextPainter _textPainter;

  SpriteSheet? _punchSheet; // Simpan Sheet-nya saja, bukan animasinya!
  SpriteSheet? _dashSheet; // Sheet untuk partikel Dash

  // Variabel untuk mekanik Dash
  double _leftTapTimer = 0.0;
  double _rightTapTimer = 0.0;
  double dashTimer = 0.0;
  double dashCooldownTimer = 0.0;

  // Variabel untuk Sistem Partikel Asap
  final List<SmokeParticle> _smokeParticles = [];
  double _smokeSpawnTimer = 0.0;
  Vector2? _lastPosForSmoke;

  PlayerCharacter({
    required this.label,
    required this.color,
    required Vector2 position,
    required this.playerIndex,
    this.isPlayer = false,
    this.isRemotePlayer = false,
    this.characterName = 'anak_sekolah', // Set ke default karakter
  }) : super(position: position, size: Vector2(20, 56)) {
    if (!isPlayer && !isRemotePlayer) {
      _botController = BotController();
    }
  }

  // Kontrol via UI sentuh
  void uiMoveLeft(bool isDown) {
    if (isDown) {
      if (_leftTapTimer > 0 && dashCooldownTimer <= 0) {
        _startDash(MoveDirection.left);
      } else {
        _leftTapTimer = 0.25; // Waktu maksimal untuk tap kedua
      }
      _currentDirection = MoveDirection.left;
      _facingDirection = MoveDirection.left;
    } else if (_currentDirection == MoveDirection.left) {
      _currentDirection = MoveDirection.idle;
    }
  }

  void uiMoveRight(bool isDown) {
    if (isDown) {
      if (_rightTapTimer > 0 && dashCooldownTimer <= 0) {
        _startDash(MoveDirection.right);
      } else {
        _rightTapTimer = 0.25; // Waktu maksimal untuk tap kedua
      }
      _currentDirection = MoveDirection.right;
      _facingDirection = MoveDirection.right;
    } else if (_currentDirection == MoveDirection.right) {
      _currentDirection = MoveDirection.idle;
    }
  }

  void uiMoveDown(bool isDown) {
    _isDownPressed = isDown;
  }

  void uiJump() {
    _wantsToJump = true;
  }

  void uiGrab() {
    _wantsToGrab = true;
  }

  void uiPunch() {
    _wantsToPunch = true;
  }

  // Mekanik Rage (Bonus Knockback berdasarkan persentase damage milik karakter ini)
  double get rageMultiplier {
    if (damagePercentage < 35.0) return 1.0;
    if (damagePercentage >= 150.0) return 1.1; // Maksimum bonus 1.1x pada 150%
    return 1.0 + ((damagePercentage - 35.0) / 115.0) * 0.1;
  }

  String get facingDirectionName => _facingDirection.name;

  void setFacingDirection(MoveDirection dir) {
    _facingDirection = dir;
  }

  void updateDamageUI() {
    if (playerIndex >= 0) {
      final currentDamages = List<double>.from(
        gameRef.playerDamageNotifier.value,
      );
      // Auto-expand list jika index belum ada (mencegah bug HUD diam di 0.0%)
      while (currentDamages.length <= playerIndex) {
        currentDamages.add(0.0);
      }
      currentDamages[playerIndex] = damagePercentage;
      gameRef.playerDamageNotifier.value = currentDamages;
    }
  }

  // Fungsi Menerima Pukulan Eksternal (Online)
  void receiveHit(num vx, num vy, num stun, {num? damageAdded}) {
    if (isDead || isRespawning) return;
    if (damageAdded != null) {
      damagePercentage += damageAdded.toDouble();
      updateDamageUI();
    }
    velocity.x = vx.toDouble();
    velocity.y = vy.toDouble();
    stunTimer = stun.toDouble();
    hitstopTimer =
        0.08; // Efek hitstop saat menerima pukulan (online sinkronisasi)
    gameRef.shakeCamera();
  }

  // Fungsi Menerima Tangkapan Eksternal (Online)
  void receiveGrab(
    String action,
    String? byLabel,
    num? vx,
    num? vy,
    num? stun, {
    num? damageAdded,
  }) {
    if (isDead || isRespawning) return;
    if (action == 'grabbed') {
      isGrabbed = true;
      grabbedByLabel = byLabel;
    } else if (action == 'thrown' || action == 'released') {
      isGrabbed = false;
      grabbedByLabel = null;
      if (damageAdded != null) {
        damagePercentage += damageAdded.toDouble();
        updateDamageUI();
      }
      if (vx != null && vy != null) {
        velocity = Vector2(vx.toDouble(), vy.toDouble());
      }
      if (stun != null) stunTimer = stun.toDouble();
    }
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (!isPlayer) return super.onKeyEvent(event, keysPressed);

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyN) {
        _wantsToGrab = true;
      }
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.keyW ||
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _wantsToJump = true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyM) {
        _wantsToPunch = true;
      }
      // Deteksi tombol arah ditekan untuk mekanisme Dash (Double Tap)
      if (event.logicalKey == LogicalKeyboardKey.keyA ||
          event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (_leftTapTimer > 0 && dashCooldownTimer <= 0) {
          _startDash(MoveDirection.left);
        } else {
          _leftTapTimer = 0.25;
        }
      }
      if (event.logicalKey == LogicalKeyboardKey.keyD ||
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (_rightTapTimer > 0 && dashCooldownTimer <= 0) {
          _startDash(MoveDirection.right);
        } else {
          _rightTapTimer = 0.25;
        }
      }
    }

    if (keysPressed.contains(LogicalKeyboardKey.keyA) ||
        keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
      _currentDirection = MoveDirection.left;
      _facingDirection = MoveDirection.left;
    } else if (keysPressed.contains(LogicalKeyboardKey.keyD) ||
        keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
      _currentDirection = MoveDirection.right;
      _facingDirection = MoveDirection.right;
    } else {
      _currentDirection = MoveDirection.idle;
    }

    // Deteksi tombol arah Bawah / S
    _isDownPressed =
        keysPressed.contains(LogicalKeyboardKey.keyS) ||
        keysPressed.contains(LogicalKeyboardKey.arrowDown);

    return super.onKeyEvent(event, keysPressed);
  }

  @override
  Future<void> onLoad() async {
    // Siapkan teks label nama pemain (P1, P2, dll.)
    _textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    _textPainter.layout();

    try {
      final spriteSheetImage = await gameRef.images.load(
        'characters/$characterName.png',
      );
      final spriteSheet = SpriteSheet(
        image: spriteSheetImage,
        srcSize: Vector2(64, 64),
      );

      SpriteAnimation createAnim({
        required int row,
        required double stepTime,
        bool loop = true,
      }) {
        return spriteSheet.createAnimation(
          row: row,
          from: 0,
          to: 6,
          stepTime: stepTime,
          loop: loop,
        );
      }

      animationTickers = {
        PlayerState.idle: createAnim(row: 0, stepTime: 0.16).createTicker(),
        PlayerState.run: createAnim(row: 1, stepTime: 0.08).createTicker(),
        PlayerState.jump: createAnim(
          row: 2,
          stepTime: 0.10,
          loop: false,
        ).createTicker(),
        PlayerState.fall: createAnim(row: 3, stepTime: 0.10).createTicker(),
        PlayerState.punch: createAnim(
          row: 4,
          stepTime: 0.06,
          loop: false,
        ).createTicker(),
        PlayerState.carry: createAnim(row: 5, stepTime: 0.12).createTicker(),
      };
    } catch (e) {
      print('Gagal meload spritesheet: $e');
    }

    // Load Spritesheet Animasi Pukulan (Hit Spark)
    try {
      final punchImage = await gameRef.images.load('effects/smoke_punch.png');
      // Asumsi ukuran per-frame adalah 64x64, sesuaikan jika sprite-mu ukurannya berbeda
      _punchSheet = SpriteSheet(image: punchImage, srcSize: Vector2(64, 64));
    } catch (e) {
      print('Gagal meload sprite efek pukulan: $e');
    }

    // Load Spritesheet Efek Dash
    try {
      final dashImage = await gameRef.images.load('effects/smoke_dash.png');
      _dashSheet = SpriteSheet(image: dashImage, srcSize: Vector2(64, 64));
    } catch (e) {
      print('Gagal meload sprite efek dash: $e');
    }
  }

  // Eksekutor Dash
  void _startDash(MoveDirection dir) {
    dashTimer = 0.2; // Durasi karakter meluncur
    dashCooldownTimer = 1.0; // Waktu tunggu sebelum bisa dash lagi
    _facingDirection = dir;
    _currentDirection = dir;

    if (_dashSheet != null) {
      final anim = _dashSheet!.createAnimation(
        row: 0,
        stepTime: 0.04,
        from: 0,
        to: 8, // Membaca 8 frame penuh sesuai spritesheet smoke_dash yang baru
        loop: false,
      );
      final dashEffect = SpriteAnimationComponent(
        animation: anim,
        position: Vector2(
          position.x + size.x / 2,
          position.y + size.y - 5,
        ), // Dekat tapak kaki
        size: Vector2(80, 80),
        anchor: Anchor.bottomCenter,
        removeOnFinish: true,
        priority: 15, // Pastikan efeknya tidak tertutup level
      );

      // Karena gambar default ditujukan untuk lari ke kanan, kita hanya flip gambarnya saat lari ke kiri
      if (dir == MoveDirection.left) dashEffect.flipHorizontally();

      gameRef.world.add(dashEffect);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Kurangi Timer Input dan Dash
    if (_leftTapTimer > 0) _leftTapTimer -= dt;
    if (_rightTapTimer > 0) _rightTapTimer -= dt;
    if (dashCooldownTimer > 0) dashCooldownTimer -= dt;
    if (dashTimer > 0) dashTimer -= dt;

    // ===== UPDATE SMOKE PARTICLES =====
    if (_lastPosForSmoke == null) _lastPosForSmoke = position.clone();
    double moveDx = position.x - _lastPosForSmoke!.x;
    double moveDy = position.y - _lastPosForSmoke!.y;
    _lastPosForSmoke = position.clone();

    if (damagePercentage >= 90.0 && !isDead && !isRespawning) {
      _smokeSpawnTimer -= dt;
      if (_smokeSpawnTimer <= 0) {
        _smokeSpawnTimer = 0.05; // Spawn super cepat agar terlihat ngebul!
        double life = 0.5 + Random().nextDouble() * 0.4; // Umur asap
        _smokeParticles.add(
          SmokeParticle(
            size.x / 2 + (Random().nextDouble() * 16 - 8), // Titik tengah dada
            size.y / 2 + (Random().nextDouble() * 16 - 8),
            (Random().nextDouble() - 0.5) * 30, // Kecepatan sebar sumbu X
            -40 - Random().nextDouble() * 40, // Terbang mengambang ke atas Y
            life,
            life,
            6 + Random().nextDouble() * 6, // Ukuran radius base partikel
          ),
        );
      }
    }

    for (int i = _smokeParticles.length - 1; i >= 0; i--) {
      final p = _smokeParticles[i];
      p.x +=
          (p.vx * dt) -
          moveDx; // MELAWAN ARAH KARAKTER AGAR TERTINGGAL DI UDARA!
      p.y += (p.vy * dt) - moveDy;
      p.life -= dt;
      if (p.life <= 0) _smokeParticles.removeAt(i);
    }
    // ==================================

    _rageFlashTimer += dt; // Timer untuk animasi kedipan Rage

    if (isDead) return;

    if (hitstopTimer > 0) {
      hitstopTimer -= dt;
      return; // Freeze seluruh karakter (animasi, gerakan fisika, dan status) saat Hitstop aktif
    }

    if (comboResetTimer > 0) {
      comboResetTimer -= dt;
      if (comboResetTimer <= 0) {
        comboCount = 0;
      }
    }

    if (animationTickers != null) {
      if (!isRemotePlayer) {
        _updateAnimationState(); // Remote player di-update otomatis dari sinkronisasi database
      }
      animationTickers![currentAnimation]?.update(dt);
    }

    if (punchTimer > 0) {
      punchTimer -= dt;
    }

    if (grabCooldownTimer > 0) {
      grabCooldownTimer -= dt;
    }

    // Kurangi timer penembus platform jika sedang aktif
    if (_ignorePlatformTimer > 0) {
      _ignorePlatformTimer -= dt;
    }

    if (isGrabbed) {
      // Jika sedang digendong (baik offline maupun online), ikuti yang menangkap!
      if (grabbedByLabel != null) {
        final grabber = gameRef.world.children
            .whereType<PlayerCharacter>()
            .firstWhere((p) => p.label == grabbedByLabel, orElse: () => this);
        if (grabber != this) {
          position = grabber.position + Vector2(0, -size.y);
          velocity = Vector2.zero();
        }
      }
      return;
    }

    if (isRespawning) {
      // Kunci posisi dan kecepatan terus-menerus untuk mencegah bug flicker dead-reckoning
      position = Vector2(-100, -100);
      velocity = Vector2.zero();

      if (grabbedCharacter != null) {
        grabbedCharacter!.isGrabbed = false;
        grabbedCharacter = null;
      }

      respawnTimer -= dt;
      if (respawnTimer < 0) respawnTimer = 0;

      int currentSeconds = respawnTimer.ceil();
      if (currentSeconds != _lastRespawnSeconds) {
        _lastRespawnSeconds = currentSeconds;
        gameRef.updateRespawnUI(playerIndex, currentSeconds);
      }

      if (!isRemotePlayer && respawnTimer <= 0) {
        isRespawning = false;
        gameRef.spawnManager.respawnPlayer(this);
      }
      return;
    }

    _handleGrabLogic(dt);
    _handlePunchLogic();

    if (stunTimer > 0) {
      stunTimer -= dt;
    } else {
      if (!isPlayer && !isRemotePlayer) {
        _botController!.update(dt, this);
        _currentDirection = _botController!.currentDirection;
        if (_currentDirection != MoveDirection.idle) {
          _facingDirection = _currentDirection;
        }
        _wantsToJump = _botController!.wantsToJump;
        _wantsToPunch = _botController!.wantsToPunch;
        _wantsToGrab = _botController!.wantsToGrab;
        _isDownPressed = _botController!.wantsToDropDown;
      }
      if (!isRemotePlayer) {
        _handleMovement();
      }
    }

    if (!isRemotePlayer) {
      _applyPhysics(dt);
      _handleBoundaries();
      _checkDeath();
    } else {
      // DEAD RECKONING & INTERPOLATION: Muluskan gerakan lawan (Anti-Patah-Patah)
      position.add(velocity * dt); // Prediksi gerakan secara lokal
      if (targetNetworkPosition != null) {
        if (position.distanceTo(targetNetworkPosition!) > 150) {
          position.setFrom(
            targetNetworkPosition!,
          ); // Snap instan jika jarak terlalu jauh (teleport/respawn)
        } else {
          position.lerp(
            targetNetworkPosition!,
            15.0 * dt,
          ); // Lerp (penghalus) pergerakan normal
        }
      }
    }

    if (isPlayer) {
      _wantsToJump = false;
      _wantsToGrab = false;
      _wantsToPunch = false;
    }
  }

  void _updateAnimationState() {
    PlayerState nextAnimation = currentAnimation;

    if (punchTimer > 0 || stunTimer > 0) {
      nextAnimation = PlayerState.punch;
    } else if (!isGrounded) {
      if (velocity.y < 0) {
        nextAnimation = PlayerState.jump;
      } else {
        nextAnimation = PlayerState.fall;
      }
    } else if (velocity.x != 0) {
      nextAnimation = PlayerState.run;
    } else {
      nextAnimation = PlayerState.idle;
    }
    if (grabbedCharacter != null) {
      nextAnimation = PlayerState.carry;
    }

    if (nextAnimation != currentAnimation) {
      currentAnimation = nextAnimation;
      animationTickers?[currentAnimation]?.reset();
    }
  }

  void _handleGrabLogic(double dt) {
    if (grabbedCharacter != null) {
      // Posisikan musuh yang ditangkap di atas kepala
      grabbedCharacter!.position =
          position + Vector2(0, -grabbedCharacter!.size.y);
      grabbedCharacter!.velocity = Vector2.zero();

      grabTimer += dt;

      if (_wantsToGrab) {
        // Tambah damage untuk bantingan dengan variasi desimal
        double damageToAdd =
            12.0 +
            (Random().nextDouble() * 3.5); // Acak sekitar 12.0% hingga 15.5%
        grabbedCharacter!.damagePercentage += damageToAdd;
        grabbedCharacter!.updateDamageUI();

        double knockbackMultiplier =
            (1.0 + (grabbedCharacter!.damagePercentage / 50.0)) *
            rageMultiplier;
        double baseThrowVx = 450.0;
        double baseThrowVy = 200.0;

        // Lempar musuh ke depan
        double throwVx = _facingDirection == MoveDirection.right
            ? (baseThrowVx * knockbackMultiplier)
            : -(baseThrowVx * knockbackMultiplier);
        double throwVy = -(baseThrowVy * knockbackMultiplier);

        if (grabbedCharacter!.isRemotePlayer) {
          gameRef.roomRef
              ?.child('players/${grabbedCharacter!.label}/incomingGrab')
              .set({
                'action': 'thrown',
                'damageAdded': damageToAdd,
                'vx': throwVx,
                'vy': throwVy,
                'stun': 1.0,
                'ts': DateTime.now().millisecondsSinceEpoch,
              });
        }
        grabbedCharacter!.isGrabbed = false;
        grabbedCharacter!.stunTimer =
            1.0; // Stun musuh 1 detik setelah dilempar
        grabbedCharacter!.velocity = Vector2(throwVx, throwVy);
        grabbedCharacter = null;
        grabCooldownTimer = 15.0; // Mulai cooldown 15 detik setelah melempar

        gameRef.shakeCamera(
          intensity: 12.0 * knockbackMultiplier,
          duration: 0.25,
        );
      } else if (grabTimer >= 3.0) {
        // Lepaskan otomatis jika sudah 3 detik
        if (grabbedCharacter!.isRemotePlayer) {
          gameRef.roomRef
              ?.child('players/${grabbedCharacter!.label}/incomingGrab')
              .set({
                'action': 'released',
                'ts': DateTime.now().millisecondsSinceEpoch,
              });
        }
        grabbedCharacter!.isGrabbed = false;
        grabbedCharacter = null;
        grabCooldownTimer = 15.0; // Mulai cooldown 15 detik setelah terlepas
      }
    } else {
      // Hanya bisa grab jika cooldown sudah habis (<= 0)
      if (_wantsToGrab && grabCooldownTimer <= 0) {
        // Buat Hitbox Grab (Tangkapan) yang terarah ke depan
        final double grabWidth = 45.0; // Jarak jangkauan tangan (diperlebar)
        final double grabHeight = 40.0;
        final double grabY =
            position.y + (size.y - grabHeight) / 2; // Di tengah badan
        final double grabX = _facingDirection == MoveDirection.right
            ? position.x +
                  size
                      .x // Di depan badan (kanan)
            : position.x - grabWidth; // Di depan badan (kiri)
        final grabRect = Rect.fromLTWH(grabX, grabY, grabWidth, grabHeight);

        for (final other
            in gameRef.world.children.whereType<PlayerCharacter>()) {
          if (other != this &&
              !other.isGrabbed &&
              !other.isRespawning &&
              !other.isDead) {
            double myCenterX = position.x + size.x / 2;
            double otherCenterX = other.position.x + other.size.x / 2;
            bool isFacingTarget = _facingDirection == MoveDirection.right
                ? otherCenterX >
                      myCenterX -
                          15 // Beri kelonggaran 15px di belakang jika saling bertumpuk
                : otherCenterX < myCenterX + 15;

            if (isFacingTarget && grabRect.overlaps(other.toRect())) {
              if (other.isRemotePlayer) {
                gameRef.roomRef
                    ?.child('players/${other.label}/incomingGrab')
                    .set({
                      'action': 'grabbed',
                      'by': label,
                      'ts': DateTime.now().millisecondsSinceEpoch,
                    });
              }
              grabbedCharacter = other;
              other.isGrabbed = true;
              grabTimer = 0.0;
              break;
            }
          }
        }
      }
    }
  }

  void _handlePunchLogic() {
    // Pukulan hanya bisa dilakukan jika tidak sedang menggendong musuh dan cooldown selesai
    if (_wantsToPunch && grabbedCharacter == null && punchTimer <= 0) {
      punchTimer = 0.42; // Durasi animasi pukulan (7 frame * 0.06 detik)

      bool hitSomeone = false;

      // Buat Hitbox Pukulan (Tonjokan) yang terarah ke depan
      final double punchWidth = 55.0; // Jarak rentangan tonjokan (diperlebar)
      final double punchHeight = 40.0;
      final double punchY =
          position.y + (size.y - punchHeight) / 2; // Di tengah badan
      final double punchX = _facingDirection == MoveDirection.right
          ? position.x +
                size
                    .x // Di depan badan (kanan)
          : position.x - punchWidth; // Di depan badan (kiri)
      final punchRect = Rect.fromLTWH(punchX, punchY, punchWidth, punchHeight);

      for (final other in gameRef.world.children.whereType<PlayerCharacter>()) {
        if (other != this &&
            !other.isRespawning &&
            !other.isGrabbed &&
            !other.isDead) {
          double myCenterX = position.x + size.x / 2;
          double otherCenterX = other.position.x + other.size.x / 2;
          bool isFacingTarget = _facingDirection == MoveDirection.right
              ? otherCenterX >
                    myCenterX -
                        15 // Beri kelonggaran 15px jika saling bertumpuk
              : otherCenterX < myCenterX + 15;

          // Cek tabrakan hitbox tinju dengan badan musuh DAN dipastikan berhadapan
          if (isFacingTarget && punchRect.overlaps(other.toRect())) {
            hitSomeone = true;
            int currentHit = comboCount + 1;
            double damageToAdd;
            double baseVx;
            double baseVy;
            double stunTime;
            double hitstopTime;
            double shakeInt;
            double
            appliedMultiplier; // Tambahkan variabel pengontrol multiplier

            if (currentHit < 3) {
              // PUKULAN JAB 1 & 2: RAHASIA SMASH BROS (Set Knockback)
              // Jarak mundur selalu konsisten, tidak peduli % damage musuh, agar combo selalu nyambung!
              damageToAdd = 2.0 + (Random().nextDouble() * 1.5);
              baseVx = 35.0; // Pushback pendek dan konstan
              baseVy = 0.0; // Tetap berpijak di tanah
              stunTime = 0.5; // Stun pas agar kita bisa lanjut pukul
              hitstopTime = 0.05;
              shakeInt = 1.0;
              appliedMultiplier =
                  1.0; // <- RAHASIA: Tidak dikalikan damage % musuh!
            } else {
              // FINISHER JAB 3: SMASH ATTACK (Scaling Knockback)
              // Musuh terlempar melayang ke udara sesuai % damage mereka!
              damageToAdd = 7.0 + (Random().nextDouble() * 3.0);
              baseVx = 160.0; // Momentum horizontal lemparan
              baseVy = 130.0; // Momentum vertikal (Di-launching ke udara)
              stunTime = 0.8;
              hitstopTime = 0.18; // Freeze frame JEDARR yang lebih lama!
              shakeInt = 10.0; // Getaran layar lebih epik
              // <- RAHASIA: Baru di hit ke-3 multiplier damage berlaku!
              appliedMultiplier =
                  (1.0 + ((other.damagePercentage + damageToAdd) / 50.0)) *
                  rageMultiplier;
            }

            // Tambah persentase damage dengan variasi desimal
            other.damagePercentage += damageToAdd;
            other.updateDamageUI();

            double knockbackVx = _facingDirection == MoveDirection.right
                ? (baseVx * appliedMultiplier)
                : -(baseVx * appliedMultiplier);
            double knockbackVy = -(baseVy * appliedMultiplier);

            if (other.isRemotePlayer) {
              gameRef.roomRef?.child('players/${other.label}/incomingHit').set({
                'damageAdded': damageToAdd,
                'vx': knockbackVx,
                'vy': knockbackVy,
                'stun': stunTime,
                'ts': DateTime.now().millisecondsSinceEpoch,
              });
            }

            // Terapkan (prediksi) efek langsung ke badan musuh tanpa delay
            other.velocity.x = knockbackVx;
            other.velocity.y = knockbackVy;
            other.stunTimer = stunTime;

            // Terapkan Hitstop
            hitstopTimer = hitstopTime;
            other.hitstopTimer = hitstopTime;

            // Berikan efek Camera Shake!
            gameRef.shakeCamera(
              intensity: shakeInt * appliedMultiplier,
              duration: 0.25,
            );

            // Munculkan efek animasi pukulan jika berhasil diload
            if (_punchSheet != null) {
              final anim = _punchSheet!.createAnimation(
                row: 0,
                stepTime: 0.04,
                from: 0,
                to: 11, // Membaca 11 frame (satu baris penuh) dari sprite smoke_punch
                loop: false,
              );
              final hitEffect = SpriteAnimationComponent(
                animation: anim,
                position: Vector2(
                  otherCenterX,
                  other.position.y + other.size.y / 3,
                ), // Di dada musuh
                size: Vector2(
                  100,
                  100,
                ), // Diperbesar agar efek impaknya terasa!
                anchor: Anchor.center,
                removeOnFinish:
                    true, // Flame akan menghapusnya otomatis setelah animasi selesai!
                priority:
                    15, // Pastikan muncul di PALING DEPAN menutupi badan karakter
              );
              gameRef.world.add(hitEffect);
            }
          }
        }
      }

      if (hitSomeone) {
        comboCount++;
        comboResetTimer =
            1.2; // Pemain punya waktu 1.2 detik untuk menekan punch selanjutnya
        if (comboCount >= 3) {
          comboCount = 0; // Reset kembali ke 0 setelah pukulan ke-3 mendarat!
        }
      }
    }
  }

  void _handleMovement() {
    // Karakter meluncur dengan kecepatan super tinggi saat dash aktif!
    if (dashTimer > 0) {
      velocity.x = _facingDirection == MoveDirection.left
          ? -GameConstants.playerSpeed * 2.5
          : GameConstants.playerSpeed * 2.5;
      return; // Kembalikan nilai agar kecepatan dash tidak ditimpa lari biasa
    }

    // Pengereman otomatis: Karakter akan diam/berhenti meluncur
    // jika sedang memukul di atas tanah, agar pukulannya terasa solid!
    if (punchTimer > 0 && isGrounded) {
      velocity.x = 0;
      return;
    }

    if (_currentDirection == MoveDirection.left) {
      velocity.x = -GameConstants.playerSpeed;
    } else if (_currentDirection == MoveDirection.right) {
      velocity.x = GameConstants.playerSpeed;
    } else {
      velocity.x = 0;
    }
  }

  void _applyPhysics(double dt) {
    // Terapkan gravitasi
    velocity.y += GameConstants.gravity * dt;

    // Periksa apakah ingin melompat
    if (_wantsToJump) {
      if (isGrounded && _isDownPressed) {
        // Turun dari platform melayang (drop down)
        _ignorePlatformTimer = 0.3; // Beri waktu 0.3 detik menembus platform
        isGrounded = false;
        _jumpCount = 1; // Masih bisa lompat 1x di udara (double jump)
      } else if (isGrounded || _jumpCount < 2) {
        // Maksimal 2 kali lompatan
        velocity.y = GameConstants.jumpForce;
        isGrounded = false;
        _jumpCount++;
      }
    }

    // Simpan posisi Y sebelumnya untuk logika jatuh di platform
    Vector2 previousPos = position.clone();

    // 1. Bergerak secara Horizontal dan Cek Tabrakan Sumbu X
    position.x += velocity.x * dt;
    _checkCollisionsX();

    // 2. Bergerak secara Vertikal dan Cek Tabrakan Sumbu Y
    position.y += velocity.y * dt;
    _checkCollisionsY(previousPos);
  }

  void _checkCollisionsX() {
    for (final platform in gameRef.platforms) {
      if (toRect().overlaps(platform.toRect())) {
        if (velocity.x > 0) {
          position.x = platform.position.x - size.x;
        } else if (velocity.x < 0) {
          position.x = platform.position.x + platform.size.x;
        }
        if (!isPlayer) {
          _botController?.reverseDirection(); // Bot berbalik saat mentok
        }
        velocity.x = 0;
      }
    }
  }

  void _checkCollisionsY(Vector2 previousPos) {
    isGrounded = false;
    for (final platform in gameRef.platforms) {
      // Cek apakah ini platform utama/dasar (berada di posisi Y paling bawah)
      bool isGroundPlatform = platform.position.y >= 600;

      // Jika pemain sedang mode drop-down dan ini bukan platform dasar, abaikan tabrakan
      if (!isGroundPlatform && _ignorePlatformTimer > 0) {
        continue;
      }

      if (toRect().overlaps(platform.toRect())) {
        // Cek jika kita mendarat dari atas
        if (velocity.y > 0 &&
            previousPos.y + size.y <= platform.position.y + 15) {
          position.y = platform.position.y - size.y;
          velocity.y = 0;
          isGrounded = true;
          _jumpCount = 0; // Reset lompatan saat mendarat di platform
        } else if (velocity.y < 0) {
          // Kepala menabrak bagian bawah platform
          position.y = platform.position.y + platform.size.y;
          velocity.y = 0;
        }
      }
    }
  }

  void _handleBoundaries() {
    // Invisible wall (tembok pembatas kiri dan kanan) dihapus!
    // Karakter sekarang bebas terlempar atau jatuh ke luar batas horizontal layar.
    // Mereka akan terhitung mati ketika posisi Y mereka melewati deathZoneY.
  }

  void _checkDeath() {
    if (isDead) return;

    // Jatuh ke jurang bawah batas dunia
    if (position.y > GameConstants.deathZoneY) {
      if (grabbedCharacter != null) {
        grabbedCharacter!.isGrabbed = false;
        grabbedCharacter = null;
      }

      final currentLives = List<int>.from(gameRef.playerLivesNotifier.value);
      currentLives[playerIndex]--;
      gameRef.playerLivesNotifier.value = currentLives;

      // Reset damage percentage kembali ke 0% saat mati (Ring Out)
      damagePercentage = 0.0;
      updateDamageUI();
      _smokeParticles.clear(); // Bersihkan efek asap

      if (currentLives[playerIndex] <= 0) {
        isDead = true;
        removeFromParent(); // Hapus karakter permanen
      } else {
        isRespawning = true;
        respawnTimer = 5.0; // Tambah delay jadi 5 Detik
        grabCooldownTimer = 0.0; // Reset cooldown kalau mati
        stunTimer = 0.0;
        hitstopTimer = 0.0;
        punchTimer = 0.0;
        comboCount = 0; // Reset combo
        velocity = Vector2.zero();
        position = Vector2(-100, -100); // Sembunyikan karakter selama respawn
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (isRespawning) return;
    super.render(canvas);

    // 1. Render Sprite di lapis bawah
    if (animationTickers != null) {
      canvas.save();
      if (_facingDirection == MoveDirection.left) {
        canvas.translate(size.x, 0);
        canvas.scale(-1, 1);
      }

      // Render sprite dengan ukuran yang lebih besar
      final double spriteRenderSize =
          100.0; // Ubah angka ini (misal 80, 96, atau 100) untuk mencari ukuran yang paling pas!
      final double offsetX =
          (size.x - spriteRenderSize) /
          2; // Otomatis ke tengah secara horizontal
      final double offsetY =
          size.y -
          spriteRenderSize +
          6; // Otomatis pas di bawah kakinya (Ubah angka +6 jika dirasa kurang naik/turun)

      Paint? tintPaint; // Secara default tidak mewarnai Sprite

      // Efek Visual RAGE (Berkedip merah menyala saat damage pemain >= 35%)
      if (damagePercentage >= 35.0) {
        double maxRageOpacity =
            ((damagePercentage - 35.0) / 115.0).clamp(0.0, 1.0) *
            0.6; // Maksimal 60% merah
        double flashIntensity =
            0.5 +
            0.5 *
                sin(
                  _rageFlashTimer * 10,
                ); // Animasi gelombang berdenyut (sin wave)
        double currentRageOpacity = maxRageOpacity * flashIntensity;

        if (currentRageOpacity > 0.05) {
          tintPaint = Paint()
            ..colorFilter = ColorFilter.mode(
              Colors.red.withOpacity(currentRageOpacity),
              BlendMode.srcATop,
            );
        }
      }

      animationTickers![currentAnimation]?.getSprite().render(
        canvas,
        position: Vector2(offsetX, offsetY),
        size: Vector2(spriteRenderSize, spriteRenderSize),
        overridePaint: tintPaint,
      );
      canvas.restore();
    }

    // 2. Render Efek Asap Hitam (Otentik Smash Bros Style)
    if (_smokeParticles.isNotEmpty) {
      for (final p in _smokeParticles) {
        final progress = p.life / p.maxLife; // 1.0 ke 0.0
        final currentRadius =
            p.radius * (2.5 - progress); // Makin lama makin membesar menyebar

        // Asap pudar di luar (Outline debu yang nge-blend dengan background)
        final outerPaint = Paint()
          ..color = const Color(0xFF555555).withOpacity(0.3 * progress)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

        // Inti asap gelap di dalam yang sangat pekat
        final innerPaint = Paint()
          ..color = const Color(0xFF111111).withOpacity(0.7 * progress)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

        canvas.drawCircle(Offset(p.x, p.y), currentRadius * 1.5, outerPaint);
        canvas.drawCircle(Offset(p.x, p.y), currentRadius, innerPaint);
      }
    }

    // Tulis label (P1, P2) di atas kepala
    _textPainter.paint(canvas, Offset((size.x - _textPainter.width) / 2, -24));

    // Tampilkan indikator timer ring (donat) jika sedang menggendong musuh
    if (grabbedCharacter != null) {
      final double radius = 18.0; // Perbesar ukuran timer lingkaran
      final Offset center = Offset(
        size.x + 25, // Disesuaikan sedikit lebih jauh ke kanan
        25,
      ); // Di sebelah kanan karakter

      // Ring background (opsional agar terlihat track-nya)
      final bgPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0; // Sedikit ditebalkan
      canvas.drawCircle(center, radius, bgPaint);

      // Ring foreground yang bergerak
      final progressPaint = Paint()
        ..color = Colors.orangeAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth =
            5.0 // Sedikit ditebalkan
        ..strokeCap = StrokeCap.round;

      final double progress = 1.0 - (grabTimer / 3.0); // Persentase sisa waktu
      final double sweepAngle = progress * 2 * pi;

      // Gambar garis lengkung dimulai dari titik puncak atas (-pi / 2)
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );

      // Gambar Icon Otot (Emoji) di tengah lingkaran
      final musclePainter = TextPainter(
        text: const TextSpan(text: '💪', style: TextStyle(fontSize: 18)),
        textDirection: TextDirection.ltr,
      )..layout();

      musclePainter.paint(
        canvas,
        Offset(
          center.dx - (musclePainter.width / 2),
          center.dy - (musclePainter.height / 2),
        ),
      );
    }

    // Indikator Off-screen (Karakter terlempar keluar layar)
    final camera = gameRef.camera;
    final visibleLeft = camera.viewfinder.position.x;
    final visibleTop = camera.viewfinder.position.y;
    final visibleWidth = camera.viewport.size.x / camera.viewfinder.zoom;
    final visibleHeight = camera.viewport.size.y / camera.viewfinder.zoom;
    final visibleRight = visibleLeft + visibleWidth;
    final visibleBottom = visibleTop + visibleHeight;

    double playerCenterX = position.x + size.x / 2;
    double playerCenterY = position.y + size.y / 2;

    // Cek apakah karakter berada di luar area layar yang terlihat
    if (playerCenterX < visibleLeft ||
        playerCenterX > visibleRight ||
        playerCenterY < visibleTop ||
        playerCenterY > visibleBottom) {
      // Tentukan posisi indikator (dibatasi di pinggir layar dengan margin 30px)
      double targetWorldX = playerCenterX.clamp(
        visibleLeft + 30,
        visibleRight - 30,
      );
      double targetWorldY = playerCenterY.clamp(
        visibleTop + 30,
        visibleBottom - 30,
      );

      double localX = targetWorldX - position.x;
      double localY = targetWorldY - position.y;

      // Hitung arah panah (menunjuk ke posisi karakter yang sebenarnya)
      double dx = playerCenterX - targetWorldX;
      double dy = playerCenterY - targetWorldY;
      double angle = atan2(dy, dx);

      // Gambar panah penunjuk (segitiga ujung)
      final path = Path()
        ..moveTo(
          localX + cos(angle) * 32,
          localY + sin(angle) * 32,
        ) // Titik ujung
        ..lineTo(
          localX + cos(angle + pi / 2) * 12,
          localY + sin(angle + pi / 2) * 12,
        ) // Sudut alas 1
        ..lineTo(
          localX + cos(angle - pi / 2) * 12,
          localY + sin(angle - pi / 2) * 12,
        ) // Sudut alas 2
        ..close();

      final arrowPaint = Paint()..color = color;
      canvas.drawPath(path, arrowPaint);

      // Gambar gelembung indikator warna karakter
      final bubblePaint = Paint()..color = color.withOpacity(0.8);
      canvas.drawCircle(Offset(localX, localY), 18, bubblePaint);

      // Gambar label nama (P1, P2) di tengah gelembung
      _textPainter.paint(
        canvas,
        Offset(
          localX - _textPainter.width / 2,
          localY - _textPainter.height / 2,
        ),
      );
    }
  }
}

// Class Data Model untuk merepresentasikan sebuah gumpalan asap
class SmokeParticle {
  double x, y;
  double vx, vy;
  double life, maxLife;
  double radius;

  SmokeParticle(
    this.x,
    this.y,
    this.vx,
    this.vy,
    this.life,
    this.maxLife,
    this.radius,
  );
}
