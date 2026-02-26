import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/age_gate_service.dart';
import 'home_screen.dart';

class GoogleProfileScreen extends StatefulWidget {
  const GoogleProfileScreen({super.key});

  @override
  State<GoogleProfileScreen> createState() => _GoogleProfileScreenState();
}

class _GoogleProfileScreenState extends State<GoogleProfileScreen> {
  DateTime? _birthDate;
  bool _birthDateLocked = false;
  bool _isSaving = false;
  bool _isCheckingNickname = false;
  bool _isNicknameChecked = false;
  String? _lastCheckedNickname;
  final TextEditingController _nicknameController = TextEditingController();

  static final RegExp _nicknamePattern = RegExp(r'^[a-zA-Z0-9가-힣]+$');
  static const int _minNicknameLength = 2;
  static const int _maxNicknameLength = 12;
  static const List<String> _forbiddenNicknames = [
    'admin',
    'administrator',
    'root',
    'system',
    'support',
    'operator',
    'test',
    '운영자',
    '관리자',
    '시스템',
    '테스트',
    '고객센터',
    '바보',
    '병신',
    '개새끼',
    '새끼',
    '섹스',
    '섹',
    '욕',
  ];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nicknameController.text = user?.displayName?.trim() ?? '';
    _nicknameController.addListener(_onNicknameChanged);
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _nicknameController.removeListener(_onNicknameChanged);
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data == null) {
        return;
      }
      final displayName = data['displayName'] as String?;
      final birthDateValue = data['birthDate'] as String?;
      if (displayName != null && displayName.trim().isNotEmpty) {
        _nicknameController.text = displayName.trim();
      }
      if (birthDateValue != null) {
        final parsed = DateTime.tryParse(birthDateValue);
        if (parsed != null) {
          setState(() {
            _birthDate = parsed;
            _birthDateLocked = true;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    int selectedYear = _birthDate?.year ?? 1987;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                '출생연도 선택',
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
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                      initialItem: selectedYear - 1900,
                    ),
                    itemExtent: 36,
                    selectionOverlay: Container(
                      decoration: BoxDecoration(
                        color: const Color(0x1AFF7A3D),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x33FF7A3D)),
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
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      // Month/day are no longer collected. Use a conservative
                      // normalized date to avoid overestimating age.
                      _birthDate = DateTime(selectedYear, 12, 31);
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
                    '확인',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
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
      return '출생연도를 선택하세요';
    }
    return '${date.year}년';
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final resolvedNickname = _resolveNickname(user.displayName);
    if (resolvedNickname == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('닉네임을 입력해주세요.')));
      return;
    }
    final validationMessage = _validateNickname(resolvedNickname);
    if (validationMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }
    if (_birthDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('출생연도를 선택해주세요.')));
      return;
    }
    if (!AgeGateService.isAllowed(_birthDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('만 14세 미만은 회원가입 및 로그인이 불가합니다.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (!_isNicknameChecked || _lastCheckedNickname != resolvedNickname) {
        final isAvailable = await _isNicknameAvailable(
          resolvedNickname,
          user.uid,
        );
        if (!isAvailable) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('이미 사용 중인 닉네임입니다.')));
          return;
        }
        _isNicknameChecked = true;
        _lastCheckedNickname = resolvedNickname;
      }
      final users = FirebaseFirestore.instance.collection('users');
      await users.doc(user.uid).set({
        'email': user.email,
        'displayName': resolvedNickname,
        'displayNameLower': resolvedNickname.toLowerCase(),
        'birthYear': _birthDate!.year,
        'birthDate': _birthDate!.toIso8601String(),
        'method': 'google',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장 중 문제가 발생했습니다.')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _onNicknameChanged() {
    final current = _nicknameController.text.trim();
    if (_lastCheckedNickname == null || current != _lastCheckedNickname) {
      _isNicknameChecked = false;
    }
  }

  Future<void> _checkNicknameAvailability() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('닉네임을 입력해주세요.')));
      return;
    }
    final validationMessage = _validateNickname(nickname);
    if (validationMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }
    setState(() {
      _isCheckingNickname = true;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final available = await _isNicknameAvailable(nickname, user.uid);
    if (!mounted) {
      return;
    }
    setState(() {
      _isCheckingNickname = false;
      _isNicknameChecked = available;
      _lastCheckedNickname = available ? nickname : null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(available ? '사용 가능한 닉네임입니다.' : '이미 사용 중인 닉네임입니다.'),
      ),
    );
  }

  String? _resolveNickname(String? fallback) {
    final input = _nicknameController.text.trim();
    if (input.isNotEmpty) {
      return input;
    }
    final trimmed = fallback?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return null;
  }

  String? _validateNickname(String nickname) {
    if (nickname.length < _minNicknameLength ||
        nickname.length > _maxNicknameLength) {
      return '닉네임은 $_minNicknameLength~$_maxNicknameLength자여야 합니다.';
    }
    if (!_nicknamePattern.hasMatch(nickname)) {
      return '닉네임은 한글/영문/숫자만 사용할 수 있어요.';
    }
    final lowered = nickname.toLowerCase();
    for (final word in _forbiddenNicknames) {
      if (lowered.contains(word.toLowerCase())) {
        return '사용할 수 없는 닉네임입니다.';
      }
    }
    return null;
  }

  Future<bool> _isNicknameAvailable(
    String nickname,
    String currentDocId,
  ) async {
    final users = FirebaseFirestore.instance.collection('users');
    final normalized = nickname.toLowerCase();
    final lowerSnap = await users
        .where('displayNameLower', isEqualTo: normalized)
        .get();
    for (final doc in lowerSnap.docs) {
      if (doc.id != currentDocId) {
        return false;
      }
    }
    final exactSnap = await users
        .where('displayName', isEqualTo: nickname)
        .get();
    for (final doc in exactSnap.docs) {
      if (doc.id != currentDocId) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF4E6), Color(0xFFFCE7F1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Text(
                  '추가 정보 입력',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5E5E5E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _birthDateLocked ? '닉네임만 입력해주세요.' : '구글 로그인 후 출생연도를 입력해주세요.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9B9B9B),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 20,
                  ),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '닉네임',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6F6F6F),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nicknameController,
                              maxLength: _maxNicknameLength,
                              decoration: InputDecoration(
                                hintText: '닉네임을 입력하세요',
                                counterText: '',
                                filled: true,
                                fillColor: const Color(0xFFF7F7F7),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFF7A3D),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 40,
                            child: OutlinedButton(
                              onPressed: _isCheckingNickname
                                  ? null
                                  : _checkNicknameAvailability,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _isNicknameChecked
                                    ? const Color(0xFF2FA66A)
                                    : const Color(0xFFFF7A3D),
                                side: BorderSide(
                                  color: _isNicknameChecked
                                      ? const Color(0xFF2FA66A)
                                      : const Color(0xFFFF7A3D),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _isCheckingNickname
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : _isNicknameChecked
                                  ? const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle, size: 14),
                                        SizedBox(width: 4),
                                        Text('확인됨'),
                                      ],
                                    )
                                  : const Text('중복체크'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '출생연도',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6F6F6F),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _birthDateLocked ? null : _pickBirthDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _birthDateLocked
                                ? const Color(0xFFEFEFEF)
                                : const Color(0xFFF7F7F7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _birthDateLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _birthDate == null
                                      ? const Color(0xFFB6B6B6)
                                      : const Color(0xFF4C4C4C),
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFFB6B6B6),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 46,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
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
                                colors: [Color(0xFFFF7A3D), Color(0xFFFF4FA6)],
                              ),
                            ),
                            child: Center(
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      '저장하고 시작하기',
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
                    ],
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
