import 'dart:math';
import 'dart:ui';
import 'player_character.dart';

enum MoveDirection { left, right, idle }

class BotController {
  final Random _random = Random();
  double _stateTimer = 0;
  double _actionTimer = 0;

  MoveDirection currentDirection = MoveDirection.idle;
  bool wantsToJump = false;
  bool wantsToPunch = false;
  bool wantsToGrab = false;
  bool wantsToDropDown = false;

  void update(double dt, PlayerCharacter self) {
    _stateTimer -= dt;
    _actionTimer -= dt;

    wantsToJump = false;
    wantsToPunch = false;
    wantsToGrab = false;
    wantsToDropDown = false;

    // SURVIVAL MODE: Prioritaskan selamat kembali ke arena jika terlempar ke jurang/pinggir
    if (!self.isGrounded &&
        (self.position.x < 50 ||
            self.position.x > 1230 ||
            self.position.y > 550)) {
      // Ambang batas deteksi bahaya ditingkatkan
      currentDirection = self.position.x < 640
          ? MoveDirection.right
          : MoveDirection.left;

      if (self.velocity.y > 0 && _random.nextDouble() < 0.4) {
        wantsToJump = true; // Berusaha double jump perlahan untuk selamat
      }
      return; // Jangan pedulikan nyerang musuh jika sedang sekarat mau jatuh
    }

    if (_stateTimer <= 0) {
      // Waktu reaksi AI dibuat sedikit lebih cepat (Medium)
      _stateTimer = 0.2 + _random.nextDouble() * 0.5;
      _decideAction(self);
    }

    _preventSuicide(self);
  }

  void _decideAction(PlayerCharacter self) {
    if (self.grabbedCharacter != null) {
      // Jika sedang menggendong musuh, langsung lemparkan!
      wantsToGrab = true;
      return;
    }

    PlayerCharacter? target = _getClosestTarget(self);

    if (target == null) {
      // Jika tidak ada target (menang/sendirian), gerak mondar-mandir
      currentDirection = MoveDirection.values[_random.nextInt(3)];
      return;
    }

    double dx = target.position.x - self.position.x;
    double dy = target.position.y - self.position.y;
    double dist = sqrt(dx * dx + dy * dy);

    if (dist < 70) {
      // Jarak dekat: Hadapkan badan ke musuh, lalu serang!
      currentDirection = dx > 0 ? MoveDirection.right : MoveDirection.left;

      if (_actionTimer <= 0) {
        _actionTimer = 0.3 + _random.nextDouble() * 0.5; // Cooldown serangan AI
        if (self.grabCooldownTimer <= 0 && _random.nextBool()) {
          wantsToGrab = true;
        } else {
          wantsToPunch = true;
        }
      }
    } else {
      // Jarak jauh: Kejar musuh
      if (dx < -15) {
        currentDirection = MoveDirection.left;
      } else if (dx > 15) {
        currentDirection = MoveDirection.right;
      } else {
        currentDirection = MoveDirection.idle;
      }

      // NAVIGASI VERTIKAL DINAMIS
      if (dx.abs() < 250) {
        // Cek vertikal dari jarak lebih jauh
        // Jika musuh berada lurus di atas/di bawahnya
        if (dy < -30 && _random.nextDouble() < 0.6) {
          // Target di atas, lompat mengejar!
          wantsToJump = true;
        } else if (dy > 40 && _random.nextDouble() < 0.4) {
          // Target di bawah, turun tembus platform!
          wantsToDropDown = true;
          wantsToJump = true;
        }
      }
    }
  }

  PlayerCharacter? _getClosestTarget(PlayerCharacter self) {
    PlayerCharacter? closest;
    double minDist = double.infinity;

    for (final other
        in self.gameRef.world.children.whereType<PlayerCharacter>()) {
      if (other != self && !other.isDead && !other.isRespawning) {
        double dist = self.position.distanceTo(other.position);
        if (dist < minDist) {
          minDist = dist;
          closest = other;
        }
      }
    }
    return closest;
  }

  void _preventSuicide(PlayerCharacter self) {
    if (!self.isGrounded || currentDirection == MoveDirection.idle) return;

    // Cek keberadaan tanah di depan karakter (agak ke bawah)
    double checkX =
        self.position.x +
        (currentDirection == MoveDirection.right ? self.size.x + 20 : -20);
    double checkY = self.position.y + self.size.y + 10;

    bool hasGroundAhead = false;
    for (final platform in self.gameRef.platforms) {
      if (platform.toRect().contains(Offset(checkX, checkY))) {
        hasGroundAhead = true;
        break;
      }
    }

    if (!hasGroundAhead) {
      // Jurang terdeteksi!
      if (_random.nextDouble() < 0.5) {
        // AI lebih berani melompat melewati celah saat mengejar musuh
        wantsToJump = true;
      } else {
        // Sesekali memutar arah agar terlihat lebih natural
        reverseDirection(); // Putar balik cari aman
      }
    }
  }

  void reverseDirection() {
    if (currentDirection == MoveDirection.left) {
      currentDirection = MoveDirection.right;
    } else if (currentDirection == MoveDirection.right) {
      currentDirection = MoveDirection.left;
    }
    _stateTimer = 1.0 + _random.nextDouble();
  }
}
