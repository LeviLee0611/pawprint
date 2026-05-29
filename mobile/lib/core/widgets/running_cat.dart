import 'dart:math';
import 'package:flutter/material.dart';

class RunningCatLoading extends StatefulWidget {
  const RunningCatLoading({super.key});

  @override
  State<RunningCatLoading> createState() => _RunningCatLoadingState();
}

class _RunningCatLoadingState extends State<RunningCatLoading>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late List<AnimationController> _pawControllers;
  late List<Animation<double>> _pawOpacities;
  late List<Animation<double>> _pawOffsets;

  final _random = Random();

  final List<_PawConfig> _paws = [
    _PawConfig(left: 30, top: 40, size: 22, angle: -0.3),
    _PawConfig(right: 25, top: 60, size: 18, angle: 0.4),
    _PawConfig(left: 50, bottom: 80, size: 20, angle: 0.2),
    _PawConfig(right: 45, bottom: 100, size: 16, angle: -0.5),
    _PawConfig(left: 15, top: 130, size: 14, angle: 0.6),
    _PawConfig(right: 15, top: 160, size: 18, angle: -0.2),
  ];

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pawControllers = List.generate(_paws.length, (i) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 1200 + _random.nextInt(600)),
      );
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) controller.repeat(reverse: true);
      });
      return controller;
    });

    _pawOpacities = _pawControllers.map((c) =>
      Tween<double>(begin: 0.15, end: 0.7).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      ),
    ).toList();

    _pawOffsets = _pawControllers.map((c) =>
      Tween<double>(begin: 0, end: -8).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      ),
    ).toList();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    for (final c in _pawControllers) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 떠다니는 발바닥들
          for (int i = 0; i < _paws.length; i++)
            _buildPaw(i),

          // 메인 바운싱 이미지
          AnimatedBuilder(
            animation: _bounceController,
            builder: (context, child) {
              final bounce = -18 * sin(_bounceController.value * pi);
              return Transform.translate(
                offset: Offset(0, bounce),
                child: child,
              );
            },
            child: Image.asset(
              'assets/images/로딩화면사진.png',
              width: 300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaw(int i) {
    final paw = _paws[i];
    return AnimatedBuilder(
      animation: _pawControllers[i],
      builder: (context, _) {
        return Positioned(
          left: paw.left,
          right: paw.right,
          top: paw.top != null ? paw.top! + _pawOffsets[i].value : null,
          bottom: paw.bottom != null ? paw.bottom! - _pawOffsets[i].value : null,
          child: Opacity(
            opacity: _pawOpacities[i].value,
            child: Transform.rotate(
              angle: paw.angle,
              child: Text(
                '🐾',
                style: TextStyle(fontSize: paw.size),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PawConfig {
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double size;
  final double angle;

  const _PawConfig({
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.size,
    required this.angle,
  });
}
