import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_screen.dart';
import 'sign_up_screen.dart';
import 'google_profile_screen.dart';
import 'kakao_profile_screen.dart';
import 'naver_profile_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _kakaoNativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: '2fb2536b99bf76097001386b2837c5ce',
  );
  static const String _naverClientId = String.fromEnvironment(
    'NAVER_CLIENT_ID',
    defaultValue: 'Pk2pE37pz6xuUEj9j6bA',
  );
  static const String _naverClientSecret = String.fromEnvironment(
    'NAVER_CLIENT_SECRET',
    defaultValue: 'NcLY4aB1UD',
  );
  static const String _naverClientName = String.fromEnvironment(
    'NAVER_CLIENT_NAME',
    defaultValue: '인생은보너스',
  );

  int _methodIndex = 0; // 0: email, 1: phone
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phoneCodeController = TextEditingController();
  bool _isLoading = false;
  bool _isVerifying = false;
  bool _smsCodeSent = false;
  bool _phoneVerified = false;
  String? _phoneVerificationId;
  String _countryCode = '+82';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _phoneCodeController.dispose();
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

  String? _normalizePhoneNumber(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return null;
    }
    if (digits.startsWith('0') && _countryCode == '+82') {
      return '+82${digits.substring(1)}';
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

  Future<void> _sendPhoneCode() async {
    final phone = _phoneController.text.trim();
    final normalized = _normalizePhoneNumber(phone);
    if (normalized == null) {
      _showError('휴대폰 번호를 입력해주세요.');
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
          _showError('전화번호 인증이 완료되었습니다.');
        },
        verificationFailed: (error) {
          if (!mounted) {
            return;
          }
          setState(() {
            _isVerifying = false;
          });
          _showError('인증에 실패했습니다. (${error.code})');
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
          _showError('인증 코드가 전송되었습니다.');
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
      _showError('인증 요청에 실패했습니다. 잠시 후 다시 시도해주세요.');
    }
  }

  Future<void> _verifyPhoneCode() async {
    final code = _phoneCodeController.text.trim();
    if (code.isEmpty) {
      _showError('인증 코드를 입력해주세요.');
      return;
    }
    final verificationId = _phoneVerificationId;
    if (verificationId == null) {
      _showError('먼저 인증 코드를 전송해주세요.');
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
      _showError('전화번호 인증이 완료되었습니다.');
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
      _showError('인증에 실패했습니다. (${error.code})');
    }
  }

  Future<void> _handlePhoneLogin() async {
    if (!_phoneVerified) {
      _showError('전화번호 인증을 완료해주세요.');
      return;
    }
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
  }

  Future<void> _handleGoogleLogin() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = result.user;
      if (user == null || !mounted) {
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      final hasBirthDate = data != null && data['birthDate'] != null;

      if (!mounted) {
        return;
      }

      if (hasBirthDate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인에 성공했습니다.')),
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
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const GoogleProfileScreen(),
          ),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      _showError(_messageForAuthError(error));
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showError('구글 로그인 중 문제가 발생했습니다.');
    }
  }

  Future<void> _handleKakaoLogin() async {
    if (_kakaoNativeAppKey == 'YOUR_KAKAO_NATIVE_APP_KEY') {
      _showError('카카오 네이티브 앱 키를 설정해주세요.');
      return;
    }
    try {
      final OAuthToken token;
      final isInstalled = await isKakaoTalkInstalled();
      if (isInstalled) {
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }
      if (token.accessToken.isEmpty) {
        if (!mounted) {
          return;
        }
        _showError('카카오 로그인에 실패했습니다.');
        return;
      }
      final user = await UserApi.instance.me();
      if (!mounted) {
        return;
      }
      final kakaoId = user.id;
      if (kakaoId == null) {
        _showError('카카오 사용자 정보를 가져오지 못했습니다.');
        return;
      }
      final nickname = user.kakaoAccount?.profile?.nickname;
      final email = user.kakaoAccount?.email;

      await _storeLastProvider('kakao', kakaoId.toString());

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc('kakao:$kakaoId')
          .get();
      final data = doc.data();
      final hasBirthDate = data != null && data['birthDate'] != null;

      if (!mounted) {
        return;
      }

      if (hasBirthDate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nickname == null ? '카카오 로그인에 성공했습니다.' : '카카오 로그인 성공: $nickname',
            ),
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
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => KakaoProfileScreen(
              kakaoId: kakaoId.toString(),
              email: email,
              nickname: nickname,
            ),
          ),
        );
      }
    } on KakaoAuthException catch (error) {
      if (!mounted) {
        return;
      }
      _showError('카카오 로그인에 실패했습니다. (${error.error} / ${error.errorDescription})');
    } on KakaoClientException catch (error) {
      if (!mounted) {
        return;
      }
      _showError('카카오 로그인에 실패했습니다. (${error.msg})');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showError('카카오 로그인 중 문제가 발생했습니다.');
    }
  }

  Future<void> _handleNaverLogin() async {
    if (_naverClientId == 'YOUR_NAVER_CLIENT_ID' ||
        _naverClientSecret == 'YOUR_NAVER_CLIENT_SECRET' ||
        _naverClientName == 'YOUR_NAVER_CLIENT_NAME') {
      _showError('네이버 로그인 키를 설정해주세요.');
      return;
    }
    try {
      final result = await FlutterNaverLogin.logIn();
      if (result.status != NaverLoginStatus.loggedIn) {
        _showError('네이버 로그인에 실패했습니다.');
        return;
      }

      final account = result.account;
      final naverId = account?.id;
      if (naverId == null || naverId.isEmpty) {
        _showError('네이버 사용자 정보를 가져오지 못했습니다.');
        return;
      }

      await _storeLastProvider('naver', naverId);

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc('naver:$naverId')
          .get();
      final data = doc.data();
      final hasBirthDate = data != null && data['birthDate'] != null;

      if (!mounted) {
        return;
      }

      if (hasBirthDate) {
        final nickname = account?.nickname;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nickname == null ? '네이버 로그인에 성공했습니다.' : '네이버 로그인 성공: $nickname',
            ),
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
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => NaverProfileScreen(
              naverId: naverId,
              email: account?.email,
              nickname: account?.nickname,
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showError('네이버 로그인 중 문제가 발생했습니다.');
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

  Future<void> _storeLastProvider(String provider, String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastProvider', provider);
    await prefs.setString('lastProviderId', id);
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
                const SizedBox(height: 16),
                _MethodTabs(
                  currentIndex: _methodIndex,
                  onChanged: (index) {
                    setState(() {
                      _methodIndex = index;
                      _smsCodeSent = false;
                      _phoneVerified = false;
                      _phoneVerificationId = null;
                      _phoneCodeController.clear();
                    });
                  },
                ),
                const SizedBox(height: 26),
                _methodIndex == 0
                    ? _LoginCard(
                        emailController: _emailController,
                        passwordController: _passwordController,
                        isLoading: _isLoading,
                        onLoginPressed: _handleEmailLogin,
                      )
                    : _PhoneLoginCard(
                        countryCode: _countryCode,
                        onSelectCountryCode: _selectCountryCode,
                        phoneController: _phoneController,
                        codeController: _phoneCodeController,
                        smsCodeSent: _smsCodeSent,
                        phoneVerified: _phoneVerified,
                        isVerifying: _isVerifying,
                        onSendCode: _sendPhoneCode,
                        onVerifyCode: _verifyPhoneCode,
                        onLoginPressed: _handlePhoneLogin,
                      ),
                const SizedBox(height: 18),
                const _DividerOr(),
                const SizedBox(height: 18),
                _SocialButtons(
                  onGooglePressed: _handleGoogleLogin,
                  onKakaoPressed: _handleKakaoLogin,
                  onNaverPressed: _handleNaverLogin,
                ),
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
            icon: Icons.mail_outline_rounded,
            label: '이메일로 로그인',
            active: currentIndex == 0,
            onTap: () => onChanged(0),
          ),
          _TabChip(
            icon: Icons.sms_outlined,
            label: '전화번호로 로그인',
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
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: active
                      ? const Color(0xFFFF7A3D)
                      : const Color(0xFF8A8A8A),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? const Color(0xFFFF7A3D)
                        : const Color(0xFF8A8A8A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

class _PhoneLoginCard extends StatelessWidget {
  const _PhoneLoginCard({
    required this.countryCode,
    required this.onSelectCountryCode,
    required this.phoneController,
    required this.codeController,
    required this.smsCodeSent,
    required this.phoneVerified,
    required this.isVerifying,
    required this.onSendCode,
    required this.onVerifyCode,
    required this.onLoginPressed,
  });

  final String countryCode;
  final VoidCallback onSelectCountryCode;
  final TextEditingController phoneController;
  final TextEditingController codeController;
  final bool smsCodeSent;
  final bool phoneVerified;
  final bool isVerifying;
  final VoidCallback onSendCode;
  final VoidCallback onVerifyCode;
  final VoidCallback onLoginPressed;

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
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: '인증 코드',
                  hintText: '코드를 입력하세요',
                  controller: codeController,
                  enabled: smsCodeSent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: isVerifying ? null : onSendCode,
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
                  onPressed: phoneVerified ? null : onVerifyCode,
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
          const SizedBox(height: 16),
          _LoginButton(
            onPressed: phoneVerified ? onLoginPressed : null,
            isLoading: false,
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
    this.enabled = true,
  });

  final String label;
  final String hintText;
  final Widget? trailing;
  final TextEditingController? controller;
  final bool obscureText;
  final bool enabled;

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
  const _SocialButtons({
    required this.onGooglePressed,
    required this.onKakaoPressed,
    required this.onNaverPressed,
  });

  final VoidCallback onGooglePressed;
  final VoidCallback onKakaoPressed;
  final VoidCallback onNaverPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SocialButton(
          label: 'Google로 시작하기',
          background: Colors.white,
          textColor: const Color(0xFF5E5E5E),
          borderColor: const Color(0xFFE2E2E2),
          icon: const Icon(
            Icons.g_mobiledata_rounded,
            color: Color(0xFF4285F4),
            size: 24,
          ),
          onPressed: onGooglePressed,
        ),
        const SizedBox(height: 12),
        _SocialButton(
          label: '카카오로 시작하기',
          background: Color(0xFFFEE500),
          textColor: Color(0xFF3C1E1E),
          icon: Icon(
            Icons.chat_bubble_rounded,
            color: Color(0xFF3C1E1E),
            size: 18,
          ),
          onPressed: onKakaoPressed,
        ),
        const SizedBox(height: 12),
        _SocialButton(
          label: '네이버로 시작하기',
          background: Color(0xFF03C75A),
          textColor: Colors.white,
          icon: Icon(
            Icons.circle,
            color: Colors.white,
            size: 10,
          ),
          onPressed: onNaverPressed,
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
    this.onPressed,
  });

  final String label;
  final Color background;
  final Color textColor;
  final Color? borderColor;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed ?? () {},
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
