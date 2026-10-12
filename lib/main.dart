import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const TurboRacingApp());

class TurboRacingApp extends StatelessWidget {
  const TurboRacingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turbo Racing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF080D15),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF5A1F), brightness: Brightness.dark),
      ),
      home: const RacingScreen(),
    );
  }
}

class RacingScreen extends StatefulWidget {
  const RacingScreen({super.key});
  @override
  State<RacingScreen> createState() => _RacingScreenState();
}

class _RacingScreenState extends State<RacingScreen> with SingleTickerProviderStateMixin {
  Timer? loop;
  double carX = 0;
  double speed = 0;
  double roadOffset = 0;
  double nitro = 100;
  double elapsed = 0;
  int score = 0;
  int distance = 0;
  int lives = 3;
  bool won = false;
  bool running = false;
  bool paused = false;
  bool finished = false;
  bool accelerating = false;
  bool braking = false;
  bool left = false;
  bool right = false;
  bool usingNitro = false;
  final List<RoadObstacle> obstacles = [];
  final math.Random random = math.Random();
  DateTime? lastTick;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    loop?.cancel();
    super.dispose();
  }

  void startGame() {
    loop?.cancel();
    setState(() {
      carX = 0; speed = 0; roadOffset = 0; nitro = 100; elapsed = 0;
      score = 0; distance = 0; lives = 3; won = false; obstacles.clear();
      running = true; paused = false; finished = false;
      accelerating = false; braking = false; left = false; right = false; usingNitro = false;
      lastTick = DateTime.now();
    });
    loop = Timer.periodic(const Duration(milliseconds: 32), (_) => tick());
  }

  void tick() {
    if (!mounted || !running || paused || finished) return;
    final now = DateTime.now();
    final double dt = (now.difference(lastTick ?? now).inMilliseconds / 1000).clamp(0.0, 0.06).toDouble();
    lastTick = now;
    setState(() {
      elapsed += dt;
      final target = accelerating ? 190.0 : braking ? 65.0 : 115.0;
      speed += (target - speed) * (accelerating || braking ? 2.6 : 0.8) * dt;
      if (usingNitro && nitro > 0) {
        speed = math.min(270.0, speed + 210 * dt).toDouble();
        nitro = math.max(0.0, nitro - 30 * dt).toDouble();
      } else {
        nitro = math.min(100.0, nitro + 5 * dt).toDouble();
      }
      if (left) carX -= (1.4 + speed / 130) * dt;
      if (right) carX += (1.4 + speed / 130) * dt;
      carX = carX.clamp(-0.82, 0.82).toDouble();
      roadOffset = (roadOffset + speed * dt) % 1000;
      distance += (speed * dt / 4).round();
      score = distance * 3;
      if (random.nextDouble() < 0.014 && obstacles.length < 4) {
        obstacles.add(RoadObstacle(x: (random.nextDouble() * 1.45) - 0.725, y: -0.1));
      }
      for (final o in obstacles) {
        o.y += (speed / 320) * dt;
        // La colisión solo cuenta cuando la piedra llega a la zona del automóvil.
        // La distancia se compara en coordenadas relativas de la pista.
        if (!o.passed && o.y > 0.78 && o.y < 0.99 && (o.x * 1.6 - carX).abs() < 0.38) {
          o.passed = true;
          lives -= 1;
          speed = math.max(25.0, speed * 0.32).toDouble();
          score = math.max(0, score - 250);
          if (lives <= 0) {
            finished = true;
            won = false;
            running = false;
            loop?.cancel();
          }
        }
      }
      obstacles.removeWhere((o) => o.y > 1.15);
      if (distance >= 1800 && lives > 0) {
        finished = true;
        won = true;
        running = false;
        loop?.cancel();
      }
    });
  }

  void togglePause() {
    setState(() {
      paused = !paused;
      lastTick = DateTime.now();
      accelerating = false; braking = false; left = false; right = false; usingNitro = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(
              painter: RacePainter(carX: carX, roadOffset: roadOffset, obstacles: obstacles, speed: speed, nitro: usingNitro && nitro > 0),
            )),
            if (!running && !finished)
              Center(child: _panel(
                title: 'TURBO RACING',
                subtitle: 'CARRERA EXTREMA',
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.sports_motorsports, size: 70, color: Color(0xFFFF5A1F)),
                  const SizedBox(height: 8),
                  const Text('Pisa el acelerador. Domina la pista.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 22),
                  _mainButton('INICIAR CARRERA', Icons.flag, startGame),
                  const SizedBox(height: 12),
                  const Text('Evita los obstáculos y llega a la meta.', style: TextStyle(fontSize: 12, color: Colors.white54)),
                ]),
              )),
            if (running || finished) ...[
              Positioned(top: 12, left: 12, right: 12, child: Column(children: [_hud(), const SizedBox(height: 6), Align(alignment: Alignment.centerLeft, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0xD9101825), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)), child: Text('VIDAS  ${List.filled(lives, '♥').join(' ')} ${List.filled(3 - lives, '♡').join(' ')}', style: const TextStyle(color: Color(0xFFFF795C), fontWeight: FontWeight.bold, fontSize: 13))))])),
              if (paused)
                Center(child: _panel(title: 'PAUSA', subtitle: 'Tu carrera está detenida', child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _mainButton('CONTINUAR', Icons.play_arrow, togglePause),
                  const SizedBox(height: 10),
                  _mainButton('REINICIAR', Icons.refresh, startGame),
                ]))),
              if (finished)
                Center(child: _panel(title: won ? '¡META!' : 'GAME OVER', subtitle: won ? '¡Carrera completada!' : 'Choque total: agotaste tus 3 vidas', child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Tiempo: ${elapsed.toStringAsFixed(1)} s', style: const TextStyle(fontSize: 18)),
                  Text('Puntuación: $score', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF7B35))),
                  const SizedBox(height: 18),
                  _mainButton('VOLVER A CORRER', Icons.refresh, startGame),
                ]))),
              if (!paused && !finished) Positioned(left: 12, right: 12, bottom: 16, child: _controls()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hud() => Row(children: [
    _hudCard('VELOCIDAD', '${speed.round()} km/h', Icons.speed),
    const SizedBox(width: 7),
    _hudCard('TIEMPO', '${elapsed.toStringAsFixed(1)} s', Icons.timer_outlined),
    const SizedBox(width: 7),
    _hudCard('PUNTOS', '$score', Icons.bolt),
    const SizedBox(width: 7),
    SizedBox(width: 44, height: 48, child: ElevatedButton(
      onPressed: togglePause,
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF182333), padding: EdgeInsets.zero),
      child: const Icon(Icons.pause, color: Colors.white),
    )),
  ]);

  Widget _hudCard(String label, String value, IconData icon) => Expanded(child: Container(
    height: 48, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(color: const Color(0xD9101825), border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 11, color: const Color(0xFFFF7B35)), const SizedBox(width: 3), Flexible(child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 8, color: Colors.white60, letterSpacing: .5)))]),
      FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900))),
    ]),
  ));

  Widget _controls() => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      GestureDetector(
        onTapDown: (_) => setState(() => usingNitro = true),
        onTapUp: (_) => setState(() => usingNitro = false),
        onTapCancel: () => setState(() => usingNitro = false),
        child: Container(width: 76, height: 60, decoration: BoxDecoration(
          color: const Color(0xDDFF5A1F), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white30)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.bolt, size: 25), const Text('NITRO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            Text('${nitro.round()}%', style: const TextStyle(fontSize: 9)),
          ]),
        ),
      ),
    ]),
    const SizedBox(height: 10),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        _holdButton(Icons.arrow_left, 'IZQ.', (v) => left = v),
        const SizedBox(width: 8),
        _holdButton(Icons.arrow_right, 'DER.', (v) => right = v),
      ]),
      Row(children: [
        _holdButton(Icons.south, 'FRENO', (v) => braking = v, orange: false),
        const SizedBox(width: 8),
        _holdButton(Icons.keyboard_double_arrow_up, 'GAS', (v) => accelerating = v),
      ]),
    ]),
  ]);

  Widget _holdButton(IconData icon, String label, ValueChanged<bool> setValue, {bool orange = true}) => GestureDetector(
    onTapDown: (_) => setState(() => setValue(true)),
    onTapUp: (_) => setState(() => setValue(false)),
    onTapCancel: () => setState(() => setValue(false)),
    child: Container(width: 66, height: 64, decoration: BoxDecoration(
      color: orange ? const Color(0xDDFF5A1F) : const Color(0xDD182333),
      borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white24)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 26), Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
      ]),
    ),
  );

  Widget _panel({required String title, required String subtitle, required Widget child}) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 26),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color(0xF00A111D), borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFFF5A1F), width: 1.4),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24, spreadRadius: 3)],
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.white)),
      const SizedBox(height: 5),
      Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFF7B35), fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
      const SizedBox(height: 18),
      child,
    ]),
  );

  Widget _mainButton(String text, IconData icon, VoidCallback onPressed) => SizedBox(
    width: double.infinity, height: 50,
    child: ElevatedButton.icon(
      onPressed: onPressed, icon: Icon(icon), label: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: .5)),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5A1F), foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
    ),
  );
}


class RoadObstacle {
  RoadObstacle({required this.x, required this.y});
  double x;
  double y;
  bool passed = false;
}

class RacePainter extends CustomPainter {
  RacePainter({required this.carX, required this.roadOffset, required this.obstacles, required this.speed, required this.nitro});
  final double carX, roadOffset, speed;
  final List<RoadObstacle> obstacles;
  final bool nitro;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..shader = const LinearGradient(
      colors: [Color(0xFF17283A), Color(0xFF0A111B), Color(0xFF080D15)],
      begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(Offset.zero & size));
    final horizon = h * .27;
    final skyPaint = Paint()..color = const Color(0xFF23394A);
    canvas.drawRect(Rect.fromLTWH(0, horizon - 60, w, 95), skyPaint);
    final mountain = Path()..moveTo(0, horizon + 5)..lineTo(w*.12, horizon-32)..lineTo(w*.23,horizon+5)..lineTo(w*.36,horizon-48)..lineTo(w*.51,horizon+4)..lineTo(w*.68,horizon-35)..lineTo(w*.82,horizon+5)..lineTo(w,horizon-18)..lineTo(w,horizon+55)..lineTo(0,horizon+55)..close();
    canvas.drawPath(mountain, Paint()..color = const Color(0xFF152333));
    final road = Path()
      ..moveTo(w*.43, horizon)..lineTo(w*.57, horizon)
      ..lineTo(w*1.05, h)..lineTo(-w*.05, h)..close();
    canvas.drawPath(road, Paint()..color = const Color(0xFF242B33));
    final edge = Paint()..color = const Color(0xFFFF5A1F)..strokeWidth = 4..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w*.43, horizon), Offset(-w*.05,h), edge);
    canvas.drawLine(Offset(w*.57, horizon), Offset(w*1.05,h), edge);
    final dash = Paint()..color = Colors.white70..strokeWidth = 2.5;
    for (int i=0; i<12; i++) {
      final t = ((i / 12) + (roadOffset / 1000)) % 1;
      final y = horizon + (t*t)*(h-horizon);
      final half = (y-horizon)/(h-horizon);
      final x = w*.5 + math.sin(roadOffset/260 + t*2)*w*.025*half;
      final dashH = 3 + 22*half;
      canvas.drawLine(Offset(x,y), Offset(x,y+dashH), dash..strokeWidth=1+4*half);
    }
    // roadside markers
    for (int i=0; i<10; i++) {
      final t = ((i / 10) + (roadOffset / 850)) % 1;
      final y = horizon + t*t*(h-horizon);
      final spread = t * w*.58;
      final markerW = 2 + t*8;
      for (final sign in [-1,1]) {
        final x = w*.5 + sign*(w*.075 + spread);
        canvas.drawRect(Rect.fromCenter(center: Offset(x,y), width: markerW, height: markerW*2.5), Paint()..color = i.isEven ? Colors.white : const Color(0xFFFF5A1F));
      }
    }
    for (final o in obstacles) {
      if (o.y < 0) continue;
      final t = o.y.clamp(0.0,1.0);
      final y = horizon + t*t*(h-horizon);
      final roadHalf = w*.07 + t*w*.48;
      final x = w*.5 + o.x*roadHalf;
      final s = 4 + t*34;
      // Sombra sobre el asfalto para que la roca parezca apoyada en la pista.
      canvas.drawOval(Rect.fromCenter(center: Offset(x + s*.10, y + s*.52), width: s*2.1, height: s*.62), Paint()..color = Colors.black45);
      final rock = Path()
        ..moveTo(x-s*.88, y+s*.12)
        ..lineTo(x-s*.72, y-s*.38)
        ..lineTo(x-s*.22, y-s*.82)
        ..lineTo(x+s*.30, y-s*.70)
        ..lineTo(x+s*.86, y-s*.18)
        ..lineTo(x+s*.78, y+s*.36)
        ..lineTo(x+s*.26, y+s*.64)
        ..lineTo(x-s*.42, y+s*.58)
        ..close();
      canvas.drawPath(rock, Paint()..color = const Color(0xFF555A60));
      final litFace = Path()
        ..moveTo(x-s*.72, y-s*.38)..lineTo(x-s*.22, y-s*.82)
        ..lineTo(x+s*.30, y-s*.70)..lineTo(x+s*.04, y-s*.20)
        ..lineTo(x-s*.40, y-s*.10)..close();
      canvas.drawPath(litFace, Paint()..color = const Color(0xFF85898C));
      final darkFace = Path()
        ..moveTo(x+s*.04, y-s*.20)..lineTo(x+s*.30, y-s*.70)
        ..lineTo(x+s*.86, y-s*.18)..lineTo(x+s*.78, y+s*.36)
        ..lineTo(x+s*.26, y+s*.64)..close();
      canvas.drawPath(darkFace, Paint()..color = const Color(0xFF393E43));
      canvas.drawLine(Offset(x-s*.34,y-s*.08), Offset(x+s*.02,y+s*.20), Paint()..color=const Color(0xFFB2B4B5)..strokeWidth=1+t*2);
      canvas.drawPath(rock, Paint()..color = const Color(0xFF24282D)..style = PaintingStyle.stroke..strokeWidth = 1.0+t);
    }
    // Automóvil deportivo visto desde atrás: neumáticos, carrocería, luneta,
    // alerón, luces traseras, reflejos y sombra para darle más volumen.
    final cx = w*.5 + carX*w*.27;
    final cy = h*.76;
    final carW = w*.20, carH = h*.15;
    if (nitro) {
      final flame = Path()..moveTo(cx-carW*.22,cy+carH*.39)..quadraticBezierTo(cx-carW*.12,cy+carH*.82,cx,cy+carH*.95)..quadraticBezierTo(cx+carW*.12,cy+carH*.82,cx+carW*.22,cy+carH*.39)..close();
      canvas.drawPath(flame, Paint()..color = const Color(0xFFFF8A28));
      canvas.drawPath(flame, Paint()..color = const Color(0xFFFFE7A1)..style=PaintingStyle.stroke..strokeWidth=1.5);
    }
    canvas.drawOval(Rect.fromCenter(center: Offset(cx,cy+carH*.31),width:carW*1.32,height:carH*.50), Paint()..color=Colors.black54);
    // neumáticos y pasos de rueda
    for (final side in [-1,1]) {
      final wheelX = cx + side*carW*.43;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(wheelX,cy+carH*.12),width:carW*.22,height:carH*.47),const Radius.circular(5)), Paint()..color=const Color(0xFF090B0E));
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(wheelX,cy+carH*.12),width:carW*.11,height:carH*.30),const Radius.circular(3)), Paint()..color=const Color(0xFF343A40));
      for (int k=0;k<3;k++) {
        canvas.drawLine(Offset(wheelX-carW*.035,cy+carH*(-.01+k*.12)),Offset(wheelX+carW*.035,cy+carH*(.04+k*.12)),Paint()..color=Colors.white24..strokeWidth=1);
      }
    }
    final body = Path()
      ..moveTo(cx-carW*.48,cy+carH*.43)
      ..quadraticBezierTo(cx-carW*.52,cy+carH*.26,cx-carW*.43,cy+carH*.05)
      ..lineTo(cx-carW*.34,cy-carH*.30)
      ..quadraticBezierTo(cx-carW*.26,cy-carH*.52,cx-carW*.12,cy-carH*.56)
      ..lineTo(cx+carW*.12,cy-carH*.56)
      ..quadraticBezierTo(cx+carW*.26,cy-carH*.52,cx+carW*.34,cy-carH*.30)
      ..lineTo(cx+carW*.43,cy+carH*.05)
      ..quadraticBezierTo(cx+carW*.52,cy+carH*.26,cx+carW*.48,cy+carH*.43)
      ..close();
    canvas.drawPath(body, Paint()..shader=const LinearGradient(colors:[Color(0xFFFFA05E),Color(0xFFFF5A1F),Color(0xFFB92F12)],begin:Alignment.centerLeft,end:Alignment.centerRight).createShader(Rect.fromCenter(center:Offset(cx,cy),width:carW,height:carH)));
    canvas.drawPath(body, Paint()..color=const Color(0xFFFFC19D)..style=PaintingStyle.stroke..strokeWidth=1.5);
    // luneta trasera oscura y reflejos del cristal
    final glass = Path()..moveTo(cx-carW*.27,cy-carH*.27)..lineTo(cx-carW*.15,cy-carH*.47)..quadraticBezierTo(cx,cy-carH*.53,cx+carW*.15,cy-carH*.47)..lineTo(cx+carW*.27,cy-carH*.27)..close();
    canvas.drawPath(glass, Paint()..color=const Color(0xFF8CC9D8));
    canvas.drawLine(Offset(cx-carW*.16,cy-carH*.44),Offset(cx+carW*.10,cy-carH*.29),Paint()..color=Colors.white54..strokeWidth=2);
    canvas.drawLine(Offset(cx-carW*.30,cy-carH*.20),Offset(cx+carW*.30,cy-carH*.20),Paint()..color=const Color(0xFF8D2415)..strokeWidth=2);
    // alerón deportivo
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(cx,cy-carH*.52),width:carW*.66,height:carH*.075),const Radius.circular(3)),Paint()..color=const Color(0xFF20252A));
    canvas.drawLine(Offset(cx-carW*.24,cy-carH*.48),Offset(cx-carW*.24,cy-carH*.39),Paint()..color=const Color(0xFF30353A)..strokeWidth=2);
    canvas.drawLine(Offset(cx+carW*.24,cy-carH*.48),Offset(cx+carW*.24,cy-carH*.39),Paint()..color=const Color(0xFF30353A)..strokeWidth=2);
    // luces traseras y placa
    for (final side in [-1,1]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(cx+side*carW*.32,cy+carH*.27),width:carW*.20,height:carH*.075),const Radius.circular(3)),Paint()..color=const Color(0xFFFFE3D4));
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(cx+side*carW*.32,cy+carH*.27),width:carW*.14,height:carH*.045),const Radius.circular(2)),Paint()..color=const Color(0xFFFF2E24));
    }
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center:Offset(cx,cy+carH*.37),width:carW*.22,height:carH*.065),const Radius.circular(2)),Paint()..color=const Color(0xFFFFE7C9));
    canvas.drawLine(Offset(cx,cy-carH*.10),Offset(cx,cy+carH*.19),Paint()..color=const Color(0xFFFFD1B7)..strokeWidth=2);
    // progress indicator
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*.22,h*.18,w*.56,5),const Radius.circular(4)), Paint()..color=Colors.white24);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*.22,h*.18,w*.56*(roadOffset/1000),5),const Radius.circular(4)), Paint()..color=const Color(0xFFFF5A1F));
  }

  @override
  bool shouldRepaint(covariant RacePainter oldDelegate) => true;
}
