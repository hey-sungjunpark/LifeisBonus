import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  static const _lineCount = 5;
  static const _normalDelay = Duration(seconds: 2);
  static const _highlightDelay = Duration(milliseconds: 2500);
  int _visibleLines = 0;
  bool _hideForMonth = false;

  @override
  void initState() {
    super.initState();
    _revealLines();
  }

  Future<void> _revealLines() async {
    for (var i = 1; i <= _lineCount; i++) {
      final delay = i == 4 ? _highlightDelay : _normalDelay;
      await Future<void>.delayed(delay);
      if (!mounted) {
        return;
      }
      setState(() {
        _visibleLines = i;
      });
    }
  }

  Future<void> _handleStart() async {
    final prefs = await SharedPreferences.getInstance();
    if (_hideForMonth) {
      final hideUntil = DateTime.now().add(const Duration(days: 30));
      await prefs.setString('introHideUntil', hideUntil.toIso8601String());
    } else {
      await prefs.remove('introHideUntil');
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFF4E6),
              Color(0xFFFCE7F1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 28),
                const _Header(),
                const SizedBox(height: 24),
                Expanded(
                  child: _IntroText(visibleLines: _visibleLines),
                ),
                _PageDots(activeCount: _visibleLines),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _hideForMonth,
                      onChanged: (value) {
                        setState(() {
                          _hideForMonth = value ?? false;
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      activeColor: const Color(0xFFFF7A3D),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '1개월 동안 안보기',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A8A8A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _StartButton(
                  onPressed: _handleStart,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.card_giftcard_rounded,
              color: Color(0xFFFF7A3D),
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              '인생은 보너스',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFF7A3D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 4,
          width: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFA24B),
                Color(0xFFFF6B7A),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IntroText extends StatelessWidget {
  const _IntroText({required this.visibleLines});

  final int visibleLines;

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      fontSize: 14,
      height: 1.65,
      color: Color(0xFF6F6F6F),
      fontWeight: FontWeight.w500,
    );
    final lines = <_IntroLine>[
      const _IntroLine('우리는 가끔 내 삶의 목적을 고민합니다.'),
      const _IntroLine('하지만 태어난 것만으로 이미 목적은 이뤘습니다.'),
      const _IntroLine('그럼 지금 이 시간은 무엇일까요?'),
      const _IntroLine(
        '신이 우리를 예뻐해서 주신 보너스 게임입니다.',
        highlight: true,
      ),
      const _IntroLine(
        '지나온 시간을 기록하고 남은 보너스 게임을 즐겁게 설계해 보세요!',
        emphasize: true,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const lineStep = 56.0;
        const baseLineHeight = 26.0;
        final centerY = constraints.maxHeight / 2;
        return SizedBox(
          height: constraints.maxHeight,
          child: Stack(
            children: List.generate(lines.length, (index) {
              final line = lines[index];
              final isVisible = visibleLines > index;
              final duration = (line.highlight || line.emphasize)
                  ? const Duration(milliseconds: 2500)
                  : const Duration(seconds: 2);
              final targetY = centerY +
                  ((index - (visibleLines - 1)) * lineStep) -
                  baseLineHeight / 2;
              return AnimatedPositioned(
                duration: duration,
                curve: Curves.easeOut,
                left: 0,
                right: 0,
                top: targetY.isFinite ? targetY : centerY,
                child: AnimatedOpacity(
                  duration: duration,
                  opacity: isVisible ? 1 : 0,
                  curve: Curves.easeOut,
                  child: AnimatedScale(
                    duration: duration,
                    scale: isVisible
                        ? (line.highlight ? 1.06 : 1)
                        : (line.highlight ? 0.95 : 1),
                    curve: Curves.easeOut,
                    alignment: Alignment.centerLeft,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        line.text,
                        textAlign: TextAlign.left,
                        style: baseStyle.copyWith(
                          fontSize: line.highlight ? 16 : 14,
                          color: line.highlight
                              ? const Color(0xFFFF6B7A)
                              : (line.emphasize
                                  ? const Color(0xFF4E4E4E)
                                  : null),
                          fontWeight: line.highlight
                              ? FontWeight.w700
                              : (line.emphasize
                                  ? FontWeight.w600
                                  : FontWeight.w500),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _IntroLine {
  const _IntroLine(this.text, {this.highlight = false, this.emphasize = false});

  final String text;
  final bool highlight;
  final bool emphasize;
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.activeCount});

  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        5,
        (index) {
          final isActive = index < activeCount;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 8,
            width: 8,
            decoration: BoxDecoration(
              color:
                  isActive ? const Color(0xFFFFA24B) : const Color(0xFFE0E0E0),
              shape: BoxShape.circle,
            ),
          );
        },
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF8D4BFF),
                Color(0xFFFF4FA6),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '시작하기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
