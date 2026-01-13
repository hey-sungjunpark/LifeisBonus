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
                _Header(),
                const SizedBox(height: 24),
                Expanded(
                  child: _IntroText(visibleLines: _visibleLines),
                ),
                _PageDots(activeCount: _visibleLines),
                const SizedBox(height: 18),
                _StartButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
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
      const _IntroLine('하지만 태어났다는 것만으로 이미 목적은 이루어졌습니다.'),
      const _IntroLine('그럼 지금 이 시간은 무엇일까요?'),
      const _IntroLine(
        '신이 우리를 예뻐해서 주신 보너스 게임입니다.',
        highlight: true,
      ),
      const _IntroLine(
        '지나온 시간을 기록하고 남은 보너스 게임을 즐겁게 설계해 보세요!',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const lineStep = 46.0;
        const baseLineHeight = 26.0;
        final centerY = constraints.maxHeight / 2;
        return SizedBox(
          height: constraints.maxHeight,
          child: Stack(
            children: List.generate(lines.length, (index) {
              final line = lines[index];
              final isVisible = visibleLines > index;
              final duration = line.highlight
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
                    child: Text(
                      line.text,
                      textAlign: TextAlign.center,
                      style: baseStyle.copyWith(
                        fontSize: line.highlight ? 16 : 14,
                        color: line.highlight ? const Color(0xFFFF6B7A) : null,
                        fontWeight: line.highlight
                            ? FontWeight.w700
                            : FontWeight.w500,
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
  const _IntroLine(this.text, {this.highlight = false});

  final String text;
  final bool highlight;
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
              color: isActive ? const Color(0xFFFFA24B) : const Color(0xFFE0E0E0),
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

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(
              children: [
                const SizedBox(height: 18),
                const _LoginHeader(),
                const SizedBox(height: 26),
                const _LoginCard(),
                const SizedBox(height: 18),
                const _DividerOr(),
                const SizedBox(height: 18),
                const _SocialButtons(),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    '나중에 하기',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8A8A8A),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const _LegalText(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

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
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              '인생은 보너스',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFF7A3D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          '당신의 보너스 게임을 시작해보세요',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF9B9B9B),
          ),
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.mail_outline_rounded,
                size: 18,
                color: Color(0xFFFF7A3D),
              ),
              SizedBox(width: 6),
              Text(
                '이메일로 로그인',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5E5E5E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _LabeledField(
            label: '이메일',
            hintText: '이메일을 입력하세요',
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: '비밀번호',
            hintText: '비밀번호를 입력하세요',
            trailing: const Icon(
              Icons.visibility_off_rounded,
              color: Color(0xFFB5B5B5),
              size: 18,
            ),
          ),
          const SizedBox(height: 16),
          const _LoginButton(),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              text: '계정이 없으신가요? ',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8A8A8A),
              ),
              children: [
                TextSpan(
                  text: '회원가입',
                  style: const TextStyle(
                    color: Color(0xFFFF4FA6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.hintText,
    this.trailing,
  });

  final String label;
  final String hintText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6F6F6F),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              fontSize: 12,
              color: Color(0xFFB6B6B6),
            ),
            filled: true,
            fillColor: const Color(0xFFF7F7F7),
            suffixIcon: trailing,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF7A3D),
                Color(0xFFFF4FA6),
              ],
            ),
          ),
          child: const Center(
            child: Text(
              '로그인',
              style: TextStyle(
                fontSize: 14,
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

class _DividerOr extends StatelessWidget {
  const _DividerOr();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: Color(0xFFE0E0E0), thickness: 1),
        ),
        const SizedBox(width: 10),
        const Text(
          '또는',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF9B9B9B),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Divider(color: Color(0xFFE0E0E0), thickness: 1),
        ),
      ],
    );
  }
}

class _SocialButtons extends StatelessWidget {
  const _SocialButtons();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _SocialButton(
          label: 'Google로 시작하기',
          background: Colors.white,
          textColor: Color(0xFF5E5E5E),
          borderColor: Color(0xFFE2E2E2),
          icon: Icon(
            Icons.g_mobiledata_rounded,
            color: Color(0xFF4285F4),
            size: 24,
          ),
        ),
        SizedBox(height: 12),
        _SocialButton(
          label: '카카오로 시작하기',
          background: Color(0xFFFEE500),
          textColor: Color(0xFF3C1E1E),
          icon: Icon(
            Icons.chat_bubble_rounded,
            color: Color(0xFF3C1E1E),
            size: 18,
          ),
        ),
        SizedBox(height: 12),
        _SocialButton(
          label: '네이버로 시작하기',
          background: Color(0xFF03C75A),
          textColor: Colors.white,
          icon: Icon(
            Icons.circle,
            color: Colors.white,
            size: 10,
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.background,
    required this.textColor,
    this.borderColor,
    required this.icon,
  });

  final String label;
  final Color background;
  final Color textColor;
  final Color? borderColor;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderColor ?? Colors.transparent),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalText extends StatelessWidget {
  const _LegalText();

  @override
  Widget build(BuildContext context) {
    return Text(
      '로그인하시면 서비스 이용약관과\n개인정보 처리방침에 동의한 것으로 간주됩니다.',
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 11,
        height: 1.5,
        color: Color(0xFFB0B0B0),
      ),
    );
  }
}
