import 'dart:async';
import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const GameApp());
}

class GameApp extends StatefulWidget {
  const GameApp({super.key});

  @override
  State<GameApp> createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> {
  late final BrickBreaker game;

  @override
  void initState() {
    super.initState();
    game = BrickBreaker();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xffa9d6e5),
                Color(0xfff2e8cf),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: Center(
                child: FittedBox(
                  child: SizedBox(
                    width: gameWidth,
                    height: gameHeight,
                    child: GameWidget(
                      game: game,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BrickBreaker extends FlameGame
    with HasCollisionDetection, KeyboardEvents, TapDetector {
  BrickBreaker()
      : super(
            camera: CameraComponent.withFixedResolution(
                width: gameWidth, height: gameHeight));

  final rand = math.Random();
  int score = 0;
  int lives = 3;
  bool isGameOver = false;
  double get width => size.x;
  double get height => size.y;

  late TextComponent scoreText;
  late TextComponent livesText;
  late TextComponent gameOverText;

  @override
  FutureOr<void> onLoad() async {
    super.onLoad();
    camera.viewfinder.anchor = Anchor.topLeft;
    world.add(PlayArea());

    // Add score text component
    scoreText = TextComponent(
      text: 'Score: $score',
      position: Vector2(10, 10),
      anchor: Anchor.topLeft,
      textRenderer:
          TextPaint(style: const TextStyle(color: Colors.black, fontSize: 24)),
    );
    world.add(scoreText);

    // Add lives text component
    livesText = TextComponent(
      text: 'Lives: $lives',
      position: Vector2(width - 100, 10),
      anchor: Anchor.topLeft,
      textRenderer:
          TextPaint(style: const TextStyle(color: Colors.black, fontSize: 24)),
    );
    world.add(livesText);

    // Initialize game over text component (will be added later)
    gameOverText = TextComponent(
      text: 'Game Over!\nTap to Restart',
      position: Vector2(width / 2, height / 2),
      anchor: Anchor.center,
      textRenderer:
          TextPaint(style: const TextStyle(color: Colors.red, fontSize: 32)),
    );
    gameOverText.priority = 1;

    // Add pause button using custom MyButton component
    world.add(MyButton(
      text: 'Pause',
      onPressed: () {
        pauseEngine(); // Pause the game
        showPauseOverlay();
      },
      position: Vector2(width - 80, 20),
    ));

    startGame();
    //  debugMode = true;
  }

  void startGame() {
    score = 0;
    lives = 3;
    isGameOver = false;
    scoreText.text = 'Score: $score';
    livesText.text = 'Lives: $lives';

    // Remove game over text if it exists
    if (world.contains(gameOverText)) {
      gameOverText.removeFromParent();
    }

    world.removeAll(world.children.query<Ball>());
    world.removeAll(world.children.query<Paddle>());
    world.removeAll(world.children.query<Brick>());

    world.add(Ball(
      difficultyModifier: difficultyModifier,
      radius: ballRadius,
      position: size / 2,
      velocity:
          Vector2((rand.nextDouble() - 0.5) * width, height * 0.3).normalized()
            ..scale(height / 4),
    ));

    world.add(Paddle(
      size: Vector2(paddleWidth, paddleHeight),
      cornerRadius: const Radius.circular(ballRadius / 2),
      position: Vector2(width / 2, height * 0.95),
    ));

    addBricks();
  }

  void addBricks() {
    final brickColumns = (gameWidth / (brickWidth + brickGutter)).floor();
    const brickRows = 5;

    for (var i = 0; i < brickColumns; i++) {
      for (var j = 0; j < brickRows; j++) {
        world.add(Brick(
          Vector2(
            (i + 0.5) * brickWidth + (i + 1) * brickGutter,
            (j + 2.0) * brickHeight + j * brickGutter,
          ),
          brickColors[rand.nextInt(brickColors.length)],
        ));
      }
    }
  }

  void updateScore() {
    score++;
    scoreText.text = 'Score: $score';
  }

  void updateLives() {
    lives--;
    livesText.text = 'Lives: $lives';
    print('lives = $lives');
    if (lives <= 0) {
      showGameOverPopup();
    }
  }

  void showGameOverPopup() {
    if (isGameOver) {
      isGameOver = true;
      add(gameOverText); // Display game over message
      // Add a restart button using custom MyButton component
      add(MyButton(
        text: 'Restart',
        onPressed: () {
          removeGameOverPopup();
          startGame(); // Restart the game
        },
        position: Vector2(gameWidth / 2, gameHeight / 2 + 50),
      ));
      // pauseEngine(); // Pause the game
    }
  }

  void removeGameOverPopup() {
    // Remove game over text and restart button
    gameOverText.removeFromParent();
    world.children
        .query<MyButton>()
        .forEach((button) => button.removeFromParent());
  }

  void showPauseOverlay() {
    // Add a resume button when paused using custom MyButton component
    world.add(MyButton(
      text: 'Resume',
      onPressed: () {
        resumeEngine(); // Resume the game
      },
      position: Vector2(size.x / 2, size.y / 2),
    ));
  }

  void checkWinCondition() {
    if (world.children.query<Brick>().isEmpty) {
      showStageCompleted();
    }
  }

  void showStageCompleted() {
    // Display "Stage Completed" message
    world.add(TextComponent(
      text: 'Stage Completed!',
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.green, fontSize: 32),
      ),
    ));

    // After a delay, move to the next stage
    Future.delayed(const Duration(seconds: 2), () {
      nextStage();
    });
  }

  void nextStage() {
    // Increase difficulty by reducing paddle size, speeding up ball, etc.
    Paddle? paddle = world.children.query<Paddle>().firstOrNull;
    if (paddle != null) {
      paddle.size = Vector2(paddle.size.x * 0.9, paddle.size.y);
    }

    Ball? ball = world.children.query<Ball>().firstOrNull;
    if (ball != null) {
      ball.velocity.scale(1.1); // Increase ball speed
    }

    // Add a new brick layout
    addBricks();
  }

  @override
  Color backgroundColor() => const Color(0xfff2e8cf);
}

class Ball extends CircleComponent
    with CollisionCallbacks, HasGameReference<BrickBreaker> {
  Ball({
    required this.velocity,
    required super.position,
    required double radius,
    required this.difficultyModifier,
  }) : super(
            radius: radius,
            anchor: Anchor.center,
            paint: Paint()
              ..color = const Color(0xff1e6091)
              ..style = PaintingStyle.fill,
            children: [CircleHitbox()]);

  final Vector2 velocity;
  final double difficultyModifier;
  final double maxBallSpeed = 800.0;

  @override
  void update(double dt) {
    super.update(dt);

    // Clamp ball velocity
    if (velocity.length > maxBallSpeed) {
      velocity.setFrom(velocity.normalized() * maxBallSpeed);
    }

    position += velocity * dt;

    // Clamp position to prevent ball from going out of bounds
    position.x = position.x.clamp(0 + radius, game.width - radius);
    position.y = position.y.clamp(0 + radius, game.height - radius);

    // Bounce back if ball hits the top, left, or right boundaries
    if (position.y <= 0 + radius) {
      velocity.y = -velocity.y;
    }
    if (position.x <= 0 + radius || position.x >= game.width - radius) {
      velocity.x = -velocity.x;
    }

    // If ball hits the bottom, lose a life or end game
    if (position.y >= game.height - radius) {
      game.updateLives();
      position.setFrom(Vector2(game.width / 2, game.height / 2)); // Reset ball
      velocity.setFrom(Vector2(
          (game.rand.nextDouble() - 0.5) * game.width, game.height * 0.3)
        ..normalized()
        ..scale(game.height / 4));
    }
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Paddle) {
      velocity.y = -velocity.y;
      velocity.x = velocity.x +
          (position.x - other.position.x) / other.size.x * game.width * 0.3;
    } else if (other is Brick) {
      velocity.setFrom(velocity * difficultyModifier);
      game.updateScore();
      // other.removeFromParent();
      if (game.world.children.query<Brick>().isEmpty) {
        game.checkWinCondition(); // Check for win condition
      }

      // Decrease brick hit points by 1 on each collision
      other.hitPoints--;

      // Reflect the ball's velocity to bounce back
      velocity.y = -velocity.y; // Reverse vertical direction
      velocity.x = velocity.x +
          (position.x - other.position.x) /
              other.size.x *
              game.width *
              0.1; // Add slight horizontal variation

      // Check if brick should be removed
      if (other.hitPoints <= 0) {
        other.removeFromParent(); // Remove the brick when hitPoints reach 0
        other.hitText.removeFromParent(); // Remove the hit points display
      } else {
        other.updateColor(); // Update brick color based on remaining hit points
      }
    }
  }
}

class Paddle extends PositionComponent
    with DragCallbacks, HasGameReference<BrickBreaker>, KeyboardHandler {
  Paddle({
    required this.cornerRadius,
    required super.position,
    required super.size,
  }) : super(anchor: Anchor.center, children: [RectangleHitbox()]);

  final Radius cornerRadius;
  double paddleSpeed = 0.0;
  final double maxPaddleSpeed = 500.0;
  final double acceleration = 1000.0;
  final double deceleration = 1500.0;

  final _paint = Paint()
    ..color = const Color(0xff1e6091)
    ..style = PaintingStyle.fill;

  @override
  void update(double dt) {
    super.update(dt);

    final keysPressed = HardwareKeyboard.instance.logicalKeysPressed;
    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA)) {
      paddleSpeed = (paddleSpeed - acceleration * dt).clamp(-maxPaddleSpeed, 0);
    } else if (keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD)) {
      paddleSpeed = (paddleSpeed + acceleration * dt).clamp(0, maxPaddleSpeed);
    } else {
      if (paddleSpeed > 0) {
        paddleSpeed =
            (paddleSpeed - deceleration * dt).clamp(0, maxPaddleSpeed);
      } else {
        paddleSpeed =
            (paddleSpeed + deceleration * dt).clamp(-maxPaddleSpeed, 0);
      }
    }

    position.x = (position.x + paddleSpeed * dt)
        .clamp(size.x / 2, game.width - size.x / 2);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size.toSize(),
        cornerRadius,
      ),
      _paint,
    );
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (isRemoved) return;
    super.onDragUpdate(event);
    position.x = (position.x + event.localDelta.x)
        .clamp(size.x / 2, game.width - size.x / 2);
  }
}

class Brick extends RectangleComponent
    with CollisionCallbacks, HasGameReference<BrickBreaker> {
  late TextComponent hitText;
  int hitPoints;

  Brick(Vector2 position, Color color)
      : hitPoints = math.Random().nextInt(10) + 1, // Random between 1 and 10
        super(
          position: position,
          size: Vector2(brickWidth, brickHeight),
          anchor: Anchor.center,
          paint: Paint()
            ..color = color
            ..style = PaintingStyle.fill,
          children: [RectangleHitbox()],
        ) {
    hitText = TextComponent(
      text: '$hitPoints',
      anchor: Anchor.center,
      position: position,
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }

  @override
  void onLoad() {
    super.onLoad();
    game.world.add(hitText); // Add text display for hitPoints
  }

  @override
  void update(double dt) {
    super.update(dt);
    hitText.position = position;
    hitText.text = '$hitPoints'; // Update displayed hit points
  }

  void updateColor() {
    // Adjust brick color based on hit points (lighter as it gets closer to 0)
    final int colorValue = (255 * (hitPoints / 10)).toInt();
    paint.color =
        Color.fromRGBO(colorValue, 0, 0, 1.0); // Red fades based on hits
  }
}

class PlayArea extends RectangleComponent with HasGameReference<BrickBreaker> {
  PlayArea() : super(children: [RectangleHitbox()]);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    size = Vector2(game.width, game.height);
  }
}

const brickColors = [
  Color(0xfff94144),
  Color(0xfff3722c),
  Color(0xfff8961e),
  Color(0xfff9844a),
  Color(0xfff9c74f),
];

const gameWidth = 820.0;
const gameHeight = 1600.0;
const ballRadius = gameWidth * 0.02;
const paddleWidth = gameWidth * 0.4;
const paddleHeight = ballRadius * 4;
const brickGutter = gameWidth * 0.015;
final brickWidth =
    (gameWidth - (brickGutter * (brickColors.length + 1))) / brickColors.length;
const brickHeight = gameHeight * 0.03;
const difficultyModifier = 1.21;

class MyButton extends PositionComponent
    with TapCallbacks, HasGameReference<BrickBreaker> {
  final String text;
  final void Function() onPressed;

  MyButton({
    required this.text,
    required this.onPressed,
    required Vector2 position,
  }) {
    this.position = position;
    size = Vector2(150, 50); // Button size
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Add text to the button
    add(TextComponent(
      text: text,
      anchor: Anchor.center,
      position: size / 2,
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 24),
      ),
    ));

    // Optional: Add a background rectangle for the button
    final buttonBackground = RectangleComponent(
      position: Vector2.zero(),
      size: size,
      paint: Paint()..color = Colors.blueAccent,
    );
    add(buttonBackground);
  }

  @override
  void onTapUp(TapUpEvent event) {
    onPressed(); // Execute the button's action when tapped
  }
}
