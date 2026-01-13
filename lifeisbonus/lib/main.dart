import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const LifeIsBonusApp());
}

class LifeIsBonusApp extends StatelessWidget {
  const LifeIsBonusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '인생은 보너스',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansKrTextTheme(),
      ),
      home: const IntroScreen(),
    );
  }
}

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          const SizedBox(height: 28),
                          _Header(),
                          const SizedBox(height: 56),
                          const _IntroText(),
                          const Spacer(),
                          const _PageDots(),
                          const SizedBox(height: 18),
                          const _StartButton(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
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
  const _IntroText();

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      fontSize: 14,
      height: 1.65,
      color: Color(0xFF6F6F6F),
      fontWeight: FontWeight.w500,
    );
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: const [
          TextSpan(text: '흔히, 내가 태어난 이유와 소명을 고민하곤 합니다.\n\n'),
          TextSpan(text: '그러나 사람은 태어난 게 목적이고 목적을 이미 이뤘습니다.\n\n'),
          TextSpan(text: '그럼 지금 살고 있는 시간은 무엇일까요?\n\n'),
          TextSpan(
            text: '신이 우리를 예뻐해서 주신 보너스 게임입니다.\n\n',
            style: TextStyle(color: Color(0xFFFF6B7A)),
          ),
          TextSpan(
            text: '지난 세월을 기록해보고 남은 보너스 게임을 어떻게 즐길\n게 보낼지 계획해봐요!',
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        5,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: 8,
          decoration: const BoxDecoration(
            color: Color(0xFFFFA24B),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      width: double.infinity,
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
    );
  }
}
