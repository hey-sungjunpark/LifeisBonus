import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  int _methodIndex = 0; // 0: email, 1: phone
  DateTime? _birthDate;
  bool _isSubmitting = false;

  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    int selectedYear = _birthDate?.year ?? 1987;
    int selectedMonth = _birthDate?.month ?? 8;
    int selectedDay = _birthDate?.day ?? 14;

    int maxDayFor(int year, int month) {
      final lastDay = DateTime(year, month + 1, 0).day;
      return lastDay;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final days = maxDayFor(selectedYear, selectedMonth);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '생년월일 선택',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4C4C4C),
                ),
              ),
              const SizedBox(height: 12),
              CupertinoTheme(
                data: const CupertinoThemeData(
                  textTheme: CupertinoTextThemeData(
                    pickerTextStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4C4C4C),
                    ),
                  ),
                ),
                child: SizedBox(
                  height: 180,
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(
                            initialItem: selectedYear - 1900,
                          ),
                          itemExtent: 36,
                          selectionOverlay: Container(
                            decoration: BoxDecoration(
                              color: const Color(0x1AFF7A3D),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0x33FF7A3D),
                              ),
                            ),
                          ),
                          onSelectedItemChanged: (index) {
                            selectedYear = 1900 + index;
                          },
                          children: List.generate(
                            now.year - 1900 + 1,
                            (index) => Center(child: Text('${1900 + index}년')),
                          ),
                        ),
                      ),
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(
                            initialItem: selectedMonth - 1,
                          ),
                          itemExtent: 36,
                          selectionOverlay: Container(
                            decoration: BoxDecoration(
                              color: const Color(0x1AFF7A3D),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0x33FF7A3D),
                              ),
                            ),
                          ),
                          onSelectedItemChanged: (index) {
                            selectedMonth = index + 1;
                          },
                          children: List.generate(
                            12,
                            (index) => Center(child: Text('${index + 1}월')),
                          ),
                        ),
                      ),
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(
                            initialItem: selectedDay - 1,
                          ),
                          itemExtent: 36,
                          selectionOverlay: Container(
                            decoration: BoxDecoration(
                              color: const Color(0x1AFF7A3D),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0x33FF7A3D),
                              ),
                            ),
                          ),
                          onSelectedItemChanged: (index) {
                            selectedDay = index + 1;
                          },
                          children: List.generate(
                            days,
                            (index) => Center(child: Text('${index + 1}일')),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final maxDay = maxDayFor(selectedYear, selectedMonth);
                    if (selectedDay > maxDay) {
                      selectedDay = maxDay;
                    }
                    setState(() {
                      _birthDate = DateTime(
                        selectedYear,
                        selectedMonth,
                        selectedDay,
                      );
                    });
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A3D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '선택 완료',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String get _birthDateLabel {
    final date = _birthDate;
    if (date == null) {
      return '생년월일을 선택하세요';
    }
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  Future<void> _completeSignUp() async {
    if (_methodIndex == 1) {
      _showMessage('전화번호 가입은 추후 제공 예정입니다.');
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showMessage('이메일과 비밀번호를 입력해주세요.');
      return;
    }
    if (password != confirm) {
      _showMessage('비밀번호가 일치하지 않습니다.');
      return;
    }
    if (_birthDate == null) {
      _showMessage('생년월일을 선택해주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });
    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': email,
          'birthDate': _birthDate!.toIso8601String(),
          'createdAt': FieldValue.serverTimestamp(),
          'method': 'email',
        });
      }
      if (!mounted) {
        return;
      }
      _showMessage('가입이 완료되었습니다.');
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (error) {
      _showMessage(_messageForAuthError(error));
    } catch (_) {
      _showMessage('가입 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _messageForAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'invalid-email':
        return '이메일 형식이 올바르지 않습니다.';
      case 'weak-password':
        return '비밀번호가 너무 약합니다. 더 강한 비밀번호를 입력해주세요.';
      default:
        return '가입에 실패했습니다. (${error.code})';
    }
  }

  void _showMessage(String message) {
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
                const _Header(),
                const SizedBox(height: 20),
                _MethodTabs(
                  currentIndex: _methodIndex,
                  onChanged: (index) {
                    setState(() {
                      _methodIndex = index;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _SignUpCard(
                  methodIndex: _methodIndex,
                  emailController: _emailController,
                  phoneController: _phoneController,
                  passwordController: _passwordController,
                  confirmController: _confirmController,
                  birthDateLabel: _birthDateLabel,
                  onPickBirthDate: _pickBirthDate,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 46,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _completeSignUp,
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
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                '가입 완료하기',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    '이미 계정이 있으신가요? 로그인',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8A8A8A),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
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
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              '회원가입',
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
          '보너스 게임을 시작할 준비를 해볼까요?',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF9B9B9B),
          ),
        ),
      ],
    );
  }
}

class _MethodTabs extends StatelessWidget {
  const _MethodTabs({
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _TabChip(
            label: '이메일로 가입',
            active: currentIndex == 0,
            onTap: () => onChanged(0),
          ),
          _TabChip(
            label: '전화번호로 가입',
            active: currentIndex == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFFF0E6) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active
                    ? const Color(0xFFFF7A3D)
                    : const Color(0xFF8A8A8A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignUpCard extends StatelessWidget {
  const _SignUpCard({
    required this.methodIndex,
    required this.emailController,
    required this.phoneController,
    required this.passwordController,
    required this.confirmController,
    required this.birthDateLabel,
    required this.onPickBirthDate,
  });

  final int methodIndex;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final String birthDateLabel;
  final VoidCallback onPickBirthDate;

  @override
  Widget build(BuildContext context) {
    final isEmail = methodIndex == 0;
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
          _LabeledField(
            label: isEmail ? '이메일' : '전화번호',
            hintText: isEmail ? '이메일을 입력하세요' : '휴대폰 번호를 입력하세요',
            controller: isEmail ? emailController : phoneController,
          ),
          if (!isEmail) ...[
            const SizedBox(height: 10),
            const Text(
              '전화번호 가입은 추후 제공 예정입니다.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
            ),
          ],
          if (isEmail) ...[
            const SizedBox(height: 10),
            _LabeledField(
              label: '비밀번호',
              hintText: '비밀번호를 입력하세요',
              controller: passwordController,
              obscureText: true,
            ),
            const SizedBox(height: 10),
            _LabeledField(
              label: '비밀번호 확인',
              hintText: '비밀번호를 다시 입력하세요',
              controller: confirmController,
              obscureText: true,
            ),
            const SizedBox(height: 10),
            _LabeledField(
              label: '생년월일',
              hintText: birthDateLabel,
              readOnly: true,
              onTap: onPickBirthDate,
              trailing: const Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: Color(0xFFB5B5B5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.hintText,
    this.controller,
    this.trailing,
    this.readOnly = false,
    this.obscureText = false,
    this.onTap,
  });

  final String label;
  final String hintText;
  final TextEditingController? controller;
  final Widget? trailing;
  final bool readOnly;
  final bool obscureText;
  final VoidCallback? onTap;

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
          readOnly: readOnly,
          onTap: onTap,
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
