import 'dart:math';

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
  bool _verificationSent = false;
  bool _emailVerified = false;
  bool _isVerifying = false;
  bool _smsCodeSent = false;
  bool _phoneVerified = false;
  String? _phoneVerificationId;
  final _birthFieldKey = GlobalKey();
  String _countryCode = '+82';

  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phoneCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _phoneCodeController.dispose();
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

  String _generateTempPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(16, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  void _resetVerificationState() {
    _verificationSent = false;
    _emailVerified = false;
    _smsCodeSent = false;
    _phoneVerified = false;
    _phoneVerificationId = null;
    _phoneCodeController.clear();
  }

  String? _normalizePhoneNumber(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return null;
    }
    if (digits.startsWith('0')) {
      if (_countryCode == '+82') {
        return '+82${digits.substring(1)}';
      }
      return '$_countryCode$digits';
    }
    if (input.trim().startsWith('+')) {
      return input.trim();
    }
    return '$_countryCode$digits';
  }

  Future<void> _selectCountryCode() async {
    const codes = ['+82', '+1', '+81', '+86'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final code = codes[index];
              return ListTile(
                title: Text(code),
                trailing: code == _countryCode
                    ? const Icon(Icons.check, color: Color(0xFF27C068))
                    : null,
                onTap: () => Navigator.of(context).pop(code),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: codes.length,
          ),
        );
      },
    );
    if (selected != null && selected != _countryCode) {
      setState(() {
        _countryCode = selected;
      });
    }
  }

  Future<void> _scrollToBirthField() async {
    final context = _birthFieldKey.currentContext;
    if (context == null) {
      return;
    }
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendVerificationEmail() async {
    if (_methodIndex == 1) {
      _showMessage('전화번호 가입은 추후 제공 예정입니다.');
      return;
    }
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('이메일을 입력해주세요.');
      return;
    }

    setState(() {
      _isVerifying = true;
    });
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.email == email) {
        await currentUser.sendEmailVerification();
      } else {
        if (currentUser != null) {
          await FirebaseAuth.instance.signOut();
        }
        final credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: _generateTempPassword(),
        );
        await credential.user?.sendEmailVerification();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _verificationSent = true;
        _emailVerified = false;
      });
      _showMessage('인증 메일을 보냈습니다. 이메일을 확인해주세요.');
    } on FirebaseAuthException catch (error) {
      _showMessage(_messageForAuthError(error));
    } catch (_) {
      _showMessage('인증 메일 전송에 실패했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _checkEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('먼저 인증 메일을 보내주세요.');
      return;
    }
    await user.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed?.emailVerified ?? false) {
        if (!mounted) {
          return;
        }
        setState(() {
          _emailVerified = true;
        });
        await _scrollToBirthField();
        _showMessage('이메일 인증이 완료되었습니다.');
      } else {
      _showMessage('아직 인증되지 않았습니다. 메일을 확인해주세요.');
    }
  }

  Future<void> _sendPhoneCode() async {
    final phone = _phoneController.text.trim();
    final normalized = _normalizePhoneNumber(phone);
    if (normalized == null) {
      _showMessage('휴대폰 번호를 입력해주세요.');
      return;
    }
    setState(() {
      _isVerifying = true;
    });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: normalized,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (!mounted) {
            return;
          }
          setState(() {
            _phoneVerified = true;
            _smsCodeSent = true;
            _isVerifying = false;
          });
          await _scrollToBirthField();
          _showMessage('전화번호 인증이 완료되었습니다.');
        },
        verificationFailed: (error) {
          if (!mounted) {
            return;
          }
          setState(() {
            _isVerifying = false;
          });
          _showMessage('인증에 실패했습니다. (${error.code})');
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) {
            return;
          }
          setState(() {
            _phoneVerificationId = verificationId;
            _smsCodeSent = true;
            _isVerifying = false;
          });
          _showMessage('인증 코드가 전송되었습니다.');
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _phoneVerificationId = verificationId;
          if (mounted) {
            setState(() {
              _isVerifying = false;
            });
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
      _showMessage('인증 요청에 실패했습니다. 잠시 후 다시 시도해주세요.');
    }
  }

  Future<void> _verifyPhoneCode() async {
    final code = _phoneCodeController.text.trim();
    if (code.isEmpty) {
      _showMessage('인증 코드를 입력해주세요.');
      return;
    }
    final verificationId = _phoneVerificationId;
    if (verificationId == null) {
      _showMessage('먼저 인증 코드를 전송해주세요.');
      return;
    }
    setState(() {
      _isVerifying = true;
    });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) {
        return;
      }
      setState(() {
        _phoneVerified = true;
        _isVerifying = false;
      });
      await _scrollToBirthField();
      _showMessage('전화번호 인증이 완료되었습니다.');
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
      _showMessage('인증에 실패했습니다. (${error.code})');
    }
  }

  Future<void> _completeSignUp() async {
    if (_methodIndex == 0) {
      if (!_emailVerified) {
        _showMessage('이메일 인증을 완료해주세요.');
        return;
      }
    } else {
      if (!_phoneVerified) {
        _showMessage('전화번호 인증을 완료해주세요.');
        return;
      }
    }
    if (_birthDate == null) {
      _showMessage('생년월일을 선택해주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showMessage('회원 정보가 없습니다. 인증을 다시 시도해주세요.');
        return;
      }
      if (_methodIndex == 0) {
        await user.updatePassword(_passwordController.text);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': _emailController.text.trim(),
          'birthDate': _birthDate!.toIso8601String(),
          'createdAt': FieldValue.serverTimestamp(),
          'method': 'email',
        });
      } else {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'phone': _normalizePhoneNumber(_phoneController.text.trim()),
          'birthDate': _birthDate!.toIso8601String(),
          'createdAt': FieldValue.serverTimestamp(),
          'method': 'phone',
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
                      _resetVerificationState();
                    });
                  },
                ),
                const SizedBox(height: 16),
                _SignUpCard(
                  methodIndex: _methodIndex,
                  emailController: _emailController,
                  phoneController: _phoneController,
                  phoneCodeController: _phoneCodeController,
                  passwordController: _passwordController,
                  confirmController: _confirmController,
                  birthDateLabel: _birthDateLabel,
                  onPickBirthDate: _pickBirthDate,
                  birthFieldKey: _birthFieldKey,
                  verificationSent: _verificationSent,
                  emailVerified: _emailVerified,
                  onSendVerification: _isVerifying ? null : _sendVerificationEmail,
                  onCheckVerification: _checkEmailVerified,
                  smsCodeSent: _smsCodeSent,
                  phoneVerified: _phoneVerified,
                  onSendPhoneCode: _isVerifying ? null : _sendPhoneCode,
                  onVerifyPhoneCode: _verifyPhoneCode,
                  countryCode: _countryCode,
                  onSelectCountryCode: _selectCountryCode,
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
    required this.phoneCodeController,
    required this.passwordController,
    required this.confirmController,
    required this.birthDateLabel,
    required this.onPickBirthDate,
    required this.birthFieldKey,
    required this.verificationSent,
    required this.emailVerified,
    required this.onSendVerification,
    required this.onCheckVerification,
    required this.smsCodeSent,
    required this.phoneVerified,
    required this.onSendPhoneCode,
    required this.onVerifyPhoneCode,
    required this.countryCode,
    required this.onSelectCountryCode,
  });

  final int methodIndex;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController phoneCodeController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final String birthDateLabel;
  final VoidCallback onPickBirthDate;
  final GlobalKey birthFieldKey;
  final bool verificationSent;
  final bool emailVerified;
  final VoidCallback? onSendVerification;
  final VoidCallback onCheckVerification;
  final bool smsCodeSent;
  final bool phoneVerified;
  final VoidCallback? onSendPhoneCode;
  final VoidCallback onVerifyPhoneCode;
  final String countryCode;
  final VoidCallback onSelectCountryCode;

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
          if (isEmail)
            _LabeledField(
              label: '이메일',
              hintText: '이메일을 입력하세요',
              controller: emailController,
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '전화번호',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6F6F6F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    InkWell(
                      onTap: onSelectCountryCode,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Text(
                              countryCode,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: Color(0xFF9B9B9B),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: '휴대폰 번호를 입력하세요',
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB6B6B6),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF7F7F7),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          if (isEmail) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSendVerification,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(
                        color: emailVerified
                            ? const Color(0xFF27C068)
                            : const Color(0xFFFFC7A7),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor:
                          emailVerified ? const Color(0xFFE6F7ED) : null,
                    ),
                    child: Text(
                      emailVerified
                          ? '인증 완료'
                          : (verificationSent ? '인증 메일 재전송' : '이메일 인증하기'),
                      style: TextStyle(
                        fontSize: 12,
                        color: emailVerified
                            ? const Color(0xFF27C068)
                            : const Color(0xFFFF7A3D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onCheckVerification,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      backgroundColor: emailVerified
                          ? const Color(0xFF27C068)
                          : const Color(0xFFFF7A3D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      emailVerified ? '인증 완료' : '인증 확인',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: '비밀번호',
              hintText: '비밀번호를 입력하세요',
              controller: passwordController,
              obscureText: true,
              enabled: emailVerified,
            ),
            const SizedBox(height: 10),
            _LabeledField(
              label: '비밀번호 확인',
              hintText: '비밀번호를 다시 입력하세요',
              controller: confirmController,
              obscureText: true,
              enabled: emailVerified,
            ),
            const SizedBox(height: 10),
            KeyedSubtree(
              key: birthFieldKey,
              child: _LabeledField(
                label: '생년월일',
                hintText: birthDateLabel,
                readOnly: true,
                enabled: emailVerified,
                onTap: emailVerified ? onPickBirthDate : null,
                trailing: const Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: Color(0xFFB5B5B5),
                ),
              ),
            ),
          ],
          if (!isEmail) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _LabeledField(
                    label: '인증 코드',
                    hintText: '코드를 입력하세요',
                    controller: phoneCodeController,
                    enabled: smsCodeSent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSendPhoneCode,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(
                        color: phoneVerified
                            ? const Color(0xFF27C068)
                            : const Color(0xFFFFC7A7),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor:
                          phoneVerified ? const Color(0xFFE6F7ED) : null,
                    ),
                    child: Text(
                      phoneVerified
                          ? '인증 완료'
                          : (smsCodeSent ? '코드 재전송' : '코드 전송'),
                      style: TextStyle(
                        fontSize: 12,
                        color: phoneVerified
                            ? const Color(0xFF27C068)
                            : const Color(0xFFFF7A3D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: phoneVerified ? null : onVerifyPhoneCode,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      backgroundColor: phoneVerified
                          ? const Color(0xFF27C068)
                          : const Color(0xFFFF7A3D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      phoneVerified ? '인증 완료' : '인증 확인',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            KeyedSubtree(
              key: birthFieldKey,
              child: _LabeledField(
                label: '생년월일',
                hintText: birthDateLabel,
                readOnly: true,
                enabled: phoneVerified,
                onTap: phoneVerified ? onPickBirthDate : null,
                trailing: const Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: Color(0xFFB5B5B5),
                ),
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
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.onTap,
  });

  final String label;
  final String hintText;
  final TextEditingController? controller;
  final Widget? trailing;
  final bool enabled;
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
          enabled: enabled,
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

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF3A8DFF) : const Color(0xFFEAF1FF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: filled ? Colors.white : const Color(0xFF3A8DFF),
          ),
        ),
      ),
    );
  }
}
