import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'home_screen.dart';
import 'sign_up_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('이메일과 비밀번호를 입력해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인에 성공했습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      _showError(_messageForAuthError(error));
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showError('로그인 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _messageForAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return '등록되지 않은 이메일입니다.';
      case 'wrong-password':
        return '비밀번호가 올바르지 않습니다.';
      case 'invalid-email':
        return '이메일 형식이 올바르지 않습니다.';
      case 'user-disabled':
        return '사용이 중지된 계정입니다.';
      case 'too-many-requests':
        return '시도 횟수가 많습니다. 잠시 후 다시 시도해주세요.';
      default:
        return '로그인에 실패했습니다. (${error.code})';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(
              children: [
                const SizedBox(height: 18),
                const _LoginHeader(),
                const SizedBox(height: 26),
                _LoginCard(
                  emailController: _emailController,
                  passwordController: _passwordController,
                  isLoading: _isLoading,
                  onLoginPressed: _handleEmailLogin,
                ),
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
  const _LoginCard({
    required this.onLoginPressed,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
  });

  final VoidCallback onLoginPressed;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;

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
            controller: emailController,
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: '비밀번호',
            hintText: '비밀번호를 입력하세요',
            trailing: Icon(
              Icons.visibility_off_rounded,
              color: Color(0xFFB5B5B5),
              size: 18,
            ),
            controller: passwordController,
            obscureText: true,
          ),
          const SizedBox(height: 16),
          _LoginButton(
            onPressed: isLoading ? null : onLoginPressed,
            isLoading: isLoading,
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SignUpScreen(),
                ),
              );
            },
            child: Text.rich(
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
    this.controller,
    this.obscureText = false,
  });

  final String label;
  final String hintText;
  final Widget? trailing;
  final TextEditingController? controller;
  final bool obscureText;

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
          controller: controller,
          obscureText: obscureText,
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
  const _LoginButton({required this.onPressed, required this.isLoading});

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
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
          child: Center(
            child: isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
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
