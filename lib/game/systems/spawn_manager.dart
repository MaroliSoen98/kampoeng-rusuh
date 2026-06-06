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
    game.playerNames = ['P1', 'P2', 'P3', 'P4'];
    game.playerColors = [
      GameConstants.p1Red,
      GameConstants.p2Blue,
      GameConstants.p3Yellow,
      GameConstants.p4Green,
    ];
    game.playerLivesNotifier.value = [3, 3, 3, 3];

    game.player1 = PlayerCharacter(
      label: game.playerNames[0],
      color: game.playerColors[0],
      position: _getRandomSpawn(),
      isPlayer: true,
      playerIndex: 0,
    );
    game.world.add(game.player1!);

    game.world.add(
      PlayerCharacter(
        label: game.playerNames[1],
        color: game.playerColors[1],
        position: _getRandomSpawn(),
        playerIndex: 1,
      ),
    );
    game.world.add(
      PlayerCharacter(
        label: game.playerNames[2],
        color: game.playerColors[2],
        position: _getRandomSpawn(),
        playerIndex: 2,
      ),
    );
    game.world.add(
      PlayerCharacter(
        label: game.playerNames[3],
        color: game.playerColors[3],
        position: _getRandomSpawn(),
        playerIndex: 3,
      ),
    );
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
