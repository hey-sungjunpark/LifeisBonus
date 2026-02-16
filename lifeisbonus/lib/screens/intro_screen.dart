import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'login_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  static const _lineCount = 5;
  static const _firstLineDelay = Duration(milliseconds: 700);
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
      final delay = i == 1
          ? _firstLineDelay
          : (i == 4 ? _highlightDelay : _normalDelay);
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
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: const VisualDensity(
                          horizontal: -4,
                          vertical: -4,
                        ),
                      ),
                      const SizedBox(width: 2),
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
                ),
                const SizedBox(height: 14),
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
    final baseStyle = GoogleFonts.gowunDodum(
      fontSize: 18,
      height: 1.65,
      color: const Color(0xFF6F6F6F),
      fontWeight: FontWeight.w500,
    );
    double measureTextWidth(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
        textScaleFactor: MediaQuery.textScaleFactorOf(context),
      )..layout();
      return painter.size.width;
    }
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
        underline: false,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxTextWidth = math.max(0.0, constraints.maxWidth - 12);
        return SizedBox(
          height: constraints.maxHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(lines.length, (index) {
              final line = lines[index];
              final isVisible = visibleLines > index;
              final duration = (line.highlight || line.emphasize)
                  ? const Duration(milliseconds: 2500)
                  : const Duration(seconds: 2);
              return AnimatedOpacity(
                duration: duration,
                opacity: isVisible ? 1 : 0,
                curve: Curves.easeOut,
                child: AnimatedSlide(
                  duration: duration,
                  offset: isVisible ? Offset.zero : const Offset(0, 0.08),
                  curve: Curves.easeOut,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: SizedBox(
                      width: maxTextWidth,
                      child: _buildIntroLine(
                        line: line,
                        isVisible: isVisible,
                        baseStyle: baseStyle,
                        measureTextWidth: measureTextWidth,
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

Widget _buildIntroLine({
  required _IntroLine line,
  required bool isVisible,
  required TextStyle baseStyle,
  required double Function(String, TextStyle) measureTextWidth,
}) {
  final isHighlight = line.highlight;
  final isEmphasize = line.emphasize;
  const underlineTarget = '보너스 게임';
  final isBonusLine = line.text.contains(underlineTarget);
  final shouldUnderline = isBonusLine && line.underline;
  final highlightSize = isBonusLine ? 18.0 : 20.0;
  final normalSize = 18.0;
  final textStyle = baseStyle.copyWith(
    fontSize: isHighlight ? highlightSize : normalSize,
    color: isHighlight
        ? const Color(0xFFFF6B7A)
        : (isEmphasize ? const Color(0xFF6F6F6F) : null),
    fontWeight: isHighlight
        ? FontWeight.w700
        : (isEmphasize ? FontWeight.w600 : FontWeight.w500),
  );
  if (!shouldUnderline) {
    return Text(
      line.text,
      textAlign: TextAlign.left,
      softWrap: true,
      strutStyle: StrutStyle(
        fontSize: isHighlight ? 20 : 18,
        height: 1.65,
        forceStrutHeight: true,
      ),
      style: textStyle,
    );
  }

  final parts = line.text.split(underlineTarget);
  final before = parts.first;
  final after = parts.length > 1 ? parts.sublist(1).join(underlineTarget) : '';
  final underlineWidth = measureTextWidth(underlineTarget, textStyle);

  return RichText(
    textAlign: TextAlign.left,
    text: TextSpan(
      style: textStyle,
      children: [
        TextSpan(text: before),
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _AnimatedUnderline(
            text: underlineTarget,
            style: textStyle,
            width: underlineWidth,
            show: isVisible,
            color: const Color(0xFFFF6B7A),
          ),
        ),
        TextSpan(text: after),
      ],
    ),
  );
}

class _AnimatedUnderline extends StatelessWidget {
  const _AnimatedUnderline({
    required this.text,
    required this.style,
    required this.width,
    required this.show,
    required this.color,
  });

  final String text;
  final TextStyle style;
  final double width;
  final bool show;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text(text, style: style),
        Positioned(
          left: 0,
          bottom: -2,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            width: show ? width : 0,
            height: 2,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
    );
  }
}

class _IntroLine {
  const _IntroLine(
    this.text, {
    this.highlight = false,
    this.emphasize = false,
    this.underline = true,
  });

  final String text;
  final bool highlight;
  final bool emphasize;
  final bool underline;
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF8D4BFF),
                  Color(0xFFFF4FA6),
                ],
              ),
              boxShadow: const [],
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
      ),
    );
  }
}
