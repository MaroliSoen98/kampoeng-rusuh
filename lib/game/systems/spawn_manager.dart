import 'dart:math';
import 'package:flame/components.dart';
import '../components/player_character.dart';
import '../components/spawn_point.dart';
import '../constants/game_constants.dart';
import '../arena_game.dart';

class SpawnManager {
  final ArenaGame game;
  final List<SpawnPoint> spawnPoints = [];
  final Random _random = Random();

  SpawnManager(this.game) {
    spawnPoints.add(SpawnPoint(Vector2(200, 100))); // Kiri atas
    spawnPoints.add(SpawnPoint(Vector2(830, 100))); // Kanan atas
    spawnPoints.add(SpawnPoint(Vector2(490, 200))); // Tengah
    spawnPoints.add(SpawnPoint(Vector2(640, 50))); // Tengah atas
  }

  void initialSpawns() {
    int totalPlayers = 1 + game.offlineBotCharacters.length;
    game.playerNames = ['P1', 'P2', 'P3', 'P4'].sublist(0, totalPlayers);
    game.playerColors = [
      GameConstants.p1Red,
      GameConstants.p2Blue,
      GameConstants.p3Yellow,
      GameConstants.p4Green,
    ].sublist(0, totalPlayers);
    game.playerLivesNotifier.value = List.filled(totalPlayers, 3);
    game.playerDamageNotifier.value = List.filled(totalPlayers, 0.0);
    game.playerRespawnNotifier.value = List.filled(totalPlayers, 0);

    // Untuk diri sendiri (Player1)
    game.player1 = PlayerCharacter(
      label: game.playerNames[0],
      color: game.playerColors[0],
      position: _getRandomSpawn(),
      isPlayer: true,
      playerIndex: 0,
      characterName: game.offlineCharacter,
    );
    game.world.add(game.player1!);

    // Untuk bot
    for (int i = 0; i < game.offlineBotCharacters.length; i++) {
      int playerIndex = i + 1;
      game.world.add(
        PlayerCharacter(
          label: game.playerNames[playerIndex],
          color: game.playerColors[playerIndex],
          position: _getRandomSpawn(),
          playerIndex: playerIndex,
          characterName: game.offlineBotCharacters[i],
        ),
      );
    }
  }

  void respawnPlayer(PlayerCharacter player) {
    player.position = _getRandomSpawn();
    player.velocity = Vector2.zero();
  }

  Vector2 _getRandomSpawn() {
    final spawn = spawnPoints[_random.nextInt(spawnPoints.length)];
    return spawn.position.clone();
  }
}
