import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Native prelogin shell. Keep this mounted around the actual login so the
/// Tech badge survives the transition; navigate normally after authentication.
class LeivaPrelogin extends StatefulWidget {
  const LeivaPrelogin({
    super.key,
    required this.loginBuilder,
    this.skipIntro = false,
    this.showSkipButton = false,
    this.onLoginReady,
  });

  final WidgetBuilder loginBuilder;
  final bool skipIntro;
  final bool showSkipButton;
  final VoidCallback? onLoginReady;

  static const duration = Duration(seconds: 5);
  static const assetRoot = 'assets/leiva_prelogin/';

  @override
  State<LeivaPrelogin> createState() => _LeivaPreloginState();
}

class _LeivaPreloginState extends State<LeivaPrelogin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: LeivaPrelogin.duration,
    )..addListener(_notifyReady);
  }

  void _notifyReady() {
    if (!_notified && _controller.value >= .9) {
      _notified = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onLoginReady?.call();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (widget.skipIntro || reduceMotion) {
      _controller.value = 1;
      _started = true;
      return;
    }
    if (_started) return;
    _started = true;
    // Do not gate the five-second clock on network, authentication, or loading.
    for (final file in const [
      'leiva.png',
      'leiva_tech.png',
      'inversiones.png',
      'agro.png',
      'seguros.png',
      'turismo.png',
    ]) {
      precacheImage(
        AssetImage('${LeivaPrelogin.assetRoot}$file'),
        context,
        onError: (Object error, StackTrace? stack) {
          debugPrint('Leiva asset: $file — $error');
        },
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_controller.isCompleted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(covariant LeivaPrelogin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.skipIntro && !oldWidget.skipIntro) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    return ColoredBox(
      color: Colors.white,
      child: AnimatedBuilder(
        animation: _controller,
        child: Builder(builder: widget.loginBuilder),
        builder: (context, login) {
          final seconds = _controller.value * 5;
          final reveal = _smooth((seconds - 4.05) / .45);
          final ready = seconds >= 4.5;
          return Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                ignoring: !ready,
                child: ExcludeSemantics(
                  excluding: !ready,
                  child: Opacity(opacity: reveal, child: login),
                ),
              ),
              if (!ready)
                IgnorePointer(
                  child: ExcludeSemantics(
                    child: Opacity(
                      opacity: 1 - reveal,
                      child: ColoredBox(
                        color: Colors.white,
                        child: _canvas(_Intro(seconds: seconds)),
                      ),
                    ),
                  ),
                ),
              // Same instance/trajectory before and after login; no route swap.
              // Hide while typing, so it cannot cover the keyboard or controls.
              if (!keyboardVisible)
                KeyedSubtree(
                  key: const ValueKey('leiva-persistent-footer'),
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: _canvas(_Footer(seconds: seconds)),
                    ),
                  ),
                ),
              if (widget.showSkipButton && !ready)
                Positioned(
                  right: 12,
                  top: MediaQuery.of(context).padding.top + 8,
                  child: TextButton(
                    onPressed: () => _controller.value = 1,
                    child: const Text('Omitir', style: TextStyle(color: _red)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

const _red = Color(0xFFE30613);
const _muted = Color(0xFF896E73);

double _smooth(double x) {
  final p = x.clamp(0.0, 1.0).toDouble();
  return p * p * (3 - 2 * p);
}

double _ease(double x) {
  final p = x.clamp(0.0, 1.0).toDouble();
  return 1 - math.pow(1 - p, 3).toDouble();
}

Widget _canvas(Widget child) => SizedBox.expand(
  child: ClipRect(
    child: FittedBox(
      fit: BoxFit.cover,
      alignment: Alignment.center,
      child: SizedBox(width: 720, height: 1600, child: child),
    ),
  ),
);

Widget _asset(String file, {BoxFit fit = BoxFit.contain}) => Image.asset(
  '${LeivaPrelogin.assetRoot}$file',
  fit: fit,
  filterQuality: FilterQuality.medium,
  gaplessPlayback: true,
  errorBuilder: (_, error, stack) => const SizedBox.shrink(),
);

Widget _label(String text, double size, {Color color = _red}) => Text(
  text,
  textAlign: TextAlign.center,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: TextStyle(
    fontFamily: 'LeivaRobotoCondensed',
    fontVariations: const [FontVariation('wght', 600)],
    fontSize: size,
    height: 1.2,
    color: color,
    decoration: TextDecoration.none,
  ),
);

Widget _at(double y, Widget child, {double left = 0, double width = 720}) =>
    Positioned(top: y, left: left, width: width, child: child);

Widget _logo(double y, double width) => _at(
  y,
  SizedBox(height: width * 69 / 378, child: _asset('leiva.png')),
  left: (720 - width) / 2,
  width: width,
);

class _Intro extends StatelessWidget {
  const _Intro({required this.seconds});
  final double seconds;

  @override
  Widget build(BuildContext context) {
    final opening = seconds < .65;
    final move = _smooth((seconds - .33) / .32);
    final width = (470 + 40 * _ease(seconds / .22)) * (1 - move) + 414 * move;
    final relative = math.max(0.0, seconds - .65);
    final index = (relative / .85).floor().clamp(0, 3).toInt();
    final local = relative - index * .85;
    final p = _smooth(local / .28);
    return ClipRect(
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Colors.white)),
          const Positioned(
            left: 480,
            top: -220,
            width: 560,
            height: 560,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFFDF6F7),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Positioned(
            left: -440,
            top: 1280,
            width: 680,
            height: 680,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFFDF6F7),
                shape: BoxShape.circle,
              ),
            ),
          ),
          _logo(
            opening ? 620 * (1 - move) + 170 * move : 170,
            opening ? width : 414,
          ),
          if (opening && move < .1) ...[
            _at(790, _label('Cerca tuyo. En cada paso.', 30, color: _muted)),
            Positioned(
              left: 360 - 80 * _ease(seconds),
              top: 866,
              width: 160 * _ease(seconds),
              height: 5,
              child: const ColoredBox(color: _red),
            ),
          ],
          if (!opening) ...[
            _at(282, _label('UN MUNDO DE POSIBILIDADES', 22, color: _muted)),
            if (p < 1 && index > 0)
              Positioned.fill(
                child: Opacity(
                  opacity: 1 - p,
                  child: Transform.translate(
                    offset: Offset(-28 * p, 0),
                    child: _Unit(index: index - 1),
                  ),
                ),
              ),
            Positioned.fill(
              child: Opacity(
                opacity: p,
                child: Transform.translate(
                  offset: Offset(44 * (1 - p), 0),
                  child: _Unit(index: index),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Unit extends StatelessWidget {
  const _Unit({required this.index});
  final int index;
  static const files = [
    'inversiones.png',
    'agro.png',
    'seguros.png',
    'turismo.png',
  ];
  static const titles = ['INVERSIONES', 'AGRO', 'SEGUROS', 'TURISMO'];
  static const captions = [
    'Decisiones que miran al futuro',
    'Cerca de quienes producen',
    'Protección para cada etapa',
    'Tu próximo destino empieza acá',
  ];

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: 47,
        top: 453,
        width: 628,
        height: 470,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF2E4E6),
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      Positioned(
        left: 48,
        top: 442,
        width: 624,
        height: 462,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: _asset(files[index]),
        ),
      ),
      _at(970, _label(titles[index], 56)),
      _at(1055, _label(captions[index], 28, color: _muted)),
      for (var j = 0; j < 4; j++)
        Positioned(
          left: 304 + j * 32.0,
          top: 1193,
          width: index == j ? 18 : 8,
          height: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: index == j ? _red : const Color(0xFFECD9DD),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
    ],
  );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.seconds});
  final double seconds;

  @override
  Widget build(BuildContext context) {
    final p = _smooth((seconds - .10) / 3.80);
    final x = -124 + 696 * p;
    // Flutter's positive rotation is clockwise; PIL reference was counterclockwise.
    final angle = -(572 - x) / 56;
    return ClipRect(
      child: Stack(
        children: [
          _at(
            1490,
            Align(
              alignment: Alignment.centerLeft,
              child: _label('leivahnos.com.ar', 22),
            ),
            left: 40,
            width: 280,
          ),
          Positioned(
            key: const ValueKey('leiva-tech-badge'),
            left: x,
            top: 1428 - 8 * math.sin(math.pi * p),
            width: 112,
            height: 112,
            child: Transform.rotate(
              angle: angle,
              child: _asset('leiva_tech.png'),
            ),
          ),
        ],
      ),
    );
  }
}
