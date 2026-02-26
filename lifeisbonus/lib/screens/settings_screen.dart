import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_settings_service.dart';
import '../services/premium_service.dart';
import '../services/push_notification_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _privacyPolicyUrl =
      'https://sore-spatula-c9f.notion.site/30bf010910c6806f8dfce301204521db';
  static const String _termsOfServiceUrl =
      'https://sore-spatula-c9f.notion.site/30bf010910c6800a89fdd655046839d4';
  bool _alertsEnabled = true;
  bool _loadingProfile = true;
  String? _nickname;
  String? _photoUrl;
  String? _avatarEmoji;
  int? _age;
  String? _userDocId;
  PremiumStatus? _premiumStatus;
  bool _loadingPremium = false;
  bool _deletingAccount = false;
  bool _isPasswordAccount = false;

  static final RegExp _nicknamePattern = RegExp(r'^[a-zA-Z0-9가-힣]+$');
  static const int _minNicknameLength = 2;
  static const int _maxNicknameLength = 12;
  static const List<String> _defaultAvatarEmojis = [
    '🙂',
    '😄',
    '😊',
    '😎',
    '🥳',
    '🌟',
    '🍀',
    '🐻',
    '🦊',
    '🐼',
    '🐨',
    '🐯',
    '🐶',
    '🐱',
    '🦁',
    '🐰',
    '🐸',
    '🐵',
    '🦄',
    '🐙',
    '🍎',
    '🍉',
    '🍓',
    '🍒',
    '🌈',
    '☀️',
    '🌙',
    '⭐',
    '🎈',
    '🎵',
    '🎮',
    '⚽',
  ];
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
    _loadAppSettings();
    _loadProfile();
    _loadPremiumStatus();
  }

  Future<void> _loadAppSettings() async {
    await AppSettingsService.ensureLoaded();
    if (!mounted) {
      return;
    }
    setState(() {
      _alertsEnabled = AppSettingsService.alertsEnabled.value;
    });
  }

  Future<void> _loadProfile() async {
    final docId = await _resolveUserDocId();
    if (!mounted) {
      return;
    }
    if (docId == null) {
      setState(() {
        _loadingProfile = false;
      });
      return;
    }
    final authUser = FirebaseAuth.instance.currentUser;
    final providerIds =
        authUser?.providerData.map((provider) => provider.providerId).toSet() ??
        <String>{};
    _isPasswordAccount = providerIds.contains('password');
    _userDocId = docId;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .get();
      final data = doc.data();
      final displayName = data?['displayName'];
      final birthDateValue = data?['birthDate'];
      DateTime? birthDate;
      if (birthDateValue is String) {
        birthDate = DateTime.tryParse(birthDateValue);
      }
      setState(() {
        _nickname = displayName is String ? displayName.trim() : null;
        _photoUrl = (data?['photoUrl'] as String?)?.trim();
        _avatarEmoji = (data?['avatarEmoji'] as String?)?.trim();
        _age = birthDate == null
            ? null
            : _calculateAge(birthDate, DateTime.now());
        if (data?['notificationsEnabled'] is bool) {
          _alertsEnabled = data?['notificationsEnabled'] as bool;
        }
        _loadingProfile = false;
      });
      if (data?['notificationsEnabled'] is bool) {
        await AppSettingsService.setAlertsEnabled(
          data?['notificationsEnabled'] as bool,
        );
      }
    } catch (_) {
      setState(() {
        _loadingProfile = false;
      });
    }
  }

  Future<void> _loadPremiumStatus() async {
    if (_loadingPremium) {
      return;
    }
    setState(() {
      _loadingPremium = true;
    });
    try {
      final status = await PremiumService.fetchStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _premiumStatus = status;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingPremium = false;
        });
      }
    }
  }

  Future<void> _openUrlWithRetry({
    required String url,
    required String label,
  }) async {
    while (mounted) {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (opened || !mounted) {
        return;
      }
      final retry = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$label 열기 실패'),
          content: const Text('페이지를 열 수 없어요. 다시 시도할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('닫기'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('재시도'),
            ),
          ],
        ),
      );
      if (retry != true) {
        return;
      }
    }
  }

  Future<void> _openPrivacyPolicy() =>
      _openUrlWithRetry(url: _privacyPolicyUrl, label: '개인정보 처리방침');

  Future<void> _openTermsOfService() =>
      _openUrlWithRetry(url: _termsOfServiceUrl, label: '서비스 이용약관');

  Future<void> _openHelpCenter() async {
    if (!mounted) {
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _HelpFaqScreen()));
  }

  Future<void> _openCustomerCenter() async {
    if (!mounted) {
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _CustomerCenterScreen()));
  }

  Future<void> _openPremiumManager() async {
    await _loadPremiumStatus();
    if (!mounted) {
      return;
    }
    final status = _premiumStatus;
    final isPremium = status?.isPremium == true;
    final until = status?.premiumUntil;
    final untilLabel = until == null
        ? null
        : '${until.year}.${until.month.toString().padLeft(2, '0')}.${until.day.toString().padLeft(2, '0')}';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '프리미엄 구독',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                isPremium ? '현재 프리미엄 이용 중입니다.' : '현재 무료 멤버입니다.',
                style: const TextStyle(fontSize: 13),
              ),
              if (isPremium && untilLabel != null) ...[
                const SizedBox(height: 6),
                Text(
                  '만료 예정일: $untilLabel',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A8A8A),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (isPremium)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('구독 해지'),
                          content: const Text('프리미엄 구독을 해지할까요?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('해지'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('취소'),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) {
                        return;
                      }
                      final uri =
                          await PremiumService.buildManageSubscriptionUri(
                            productId: 'lifeisbonus_premium_monthly',
                          );
                      if (uri == null) {
                        if (!mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('이 기기에서는 구독 관리를 열 수 없어요.'),
                          ),
                        );
                        return;
                      }
                      final opened = await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                      if (!opened) {
                        if (!mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('스토어 구독 관리 페이지를 열 수 없어요.'),
                          ),
                        );
                        return;
                      }
                      if (!mounted) {
                        return;
                      }
                      await showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('안내'),
                          content: const Text(
                            '스토어 구독 관리 화면으로 이동했습니다.\n해지는 해당 화면에서 완료해 주세요.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('확인'),
                            ),
                          ],
                        ),
                      );
                      if (!mounted) {
                        return;
                      }
                      Navigator.of(context).pop();
                      await _loadPremiumStatus();
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('스토어에서 구독 관리'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFDECEC),
                      foregroundColor: const Color(0xFFD64545),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A8DFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '닫기',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = FirebaseAuth.instance.currentUser?.email?.trim();
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('가입 이메일 정보를 찾을 수 없어요.')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('비밀번호 변경'),
        content: Text('$email 로 비밀번호 재설정 메일을 보낼까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('발송'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await FirebaseAuth.instance.setLanguageCode('ko');
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$email 로 비밀번호 재설정 메일을 보냈어요.')));
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('재설정 메일 전송 실패: ${e.code}')));
    }
  }

  Future<String?> _resolveUserDocId() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString('lastProvider');
    final providerId = prefs.getString('lastProviderId');
    if ((provider == 'kakao' || provider == 'naver') &&
        providerId != null &&
        providerId.isNotEmpty) {
      return '$provider:$providerId';
    }
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      return authUser.uid;
    }
    if (providerId != null && providerId.isNotEmpty) {
      return providerId;
    }
    return null;
  }

  int _calculateAge(DateTime birthDate, DateTime now) {
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age -= 1;
    }
    return age;
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

  Future<bool> _isNicknameAvailable(String nickname) async {
    final currentDocId = _userDocId;
    if (currentDocId == null) {
      return false;
    }
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

  Future<String> _uploadProfileImage({
    required String userDocId,
    required XFile picked,
  }) async {
    final bytes = await picked.readAsBytes();
    final ref = FirebaseStorage.instance.ref().child(
      'users/$userDocId/profile/profile.jpg',
    );
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<void> _deleteStorageImageByUrl(String? url) async {
    final target = url?.trim();
    if (target == null || target.isEmpty) {
      return;
    }
    try {
      await FirebaseStorage.instance.refFromURL(target).delete();
    } catch (_) {}
  }

  Widget _buildProfileAvatar({
    required String displayName,
    String? photoUrl,
    String? avatarEmoji,
  }) {
    final initial = displayName.isNotEmpty ? displayName.substring(0, 1) : '?';
    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFFF1E9FF),
        backgroundImage: NetworkImage(photoUrl.trim()),
      );
    }
    if (avatarEmoji != null && avatarEmoji.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFFFFE3D3),
        child: Text(avatarEmoji.trim(), style: const TextStyle(fontSize: 20)),
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFFFFE3D3),
      child: Text(
        initial,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFFB356FF),
        ),
      ),
    );
  }

  Future<void> _openNicknameEditor() async {
    final controller = TextEditingController(text: _nickname ?? '');
    bool isChecking = false;
    bool isUploadingImage = false;
    bool isChecked = false;
    String? lastChecked;
    String? inlineNotice;
    bool inlineNoticeIsError = false;
    String? draftPhotoUrl = _photoUrl;
    String? draftAvatarEmoji = _avatarEmoji;
    bool removePhotoOnSave = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickFromGallery() async {
              final docId = _userDocId;
              if (docId == null) {
                return;
              }
              final picker = ImagePicker();
              final picked = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 1080,
                maxHeight: 1080,
                imageQuality: 85,
              );
              if (picked == null) {
                return;
              }
              setSheetState(() {
                isUploadingImage = true;
              });
              try {
                final uploadedUrl = await _uploadProfileImage(
                  userDocId: docId,
                  picked: picked,
                );
                setSheetState(() {
                  draftPhotoUrl = uploadedUrl;
                  draftAvatarEmoji = null;
                  removePhotoOnSave = false;
                });
              } catch (e) {
                if (context.mounted) {
                  setSheetState(() {
                    inlineNotice = '이미지 업로드에 실패했어요. ($e)';
                    inlineNoticeIsError = true;
                  });
                }
              } finally {
                if (context.mounted) {
                  setSheetState(() {
                    isUploadingImage = false;
                  });
                }
              }
            }

            Future<void> checkNickname() async {
              final nickname = controller.text.trim();
              if (nickname.isEmpty) {
                setSheetState(() {
                  inlineNotice = '닉네임을 입력해주세요.';
                  inlineNoticeIsError = true;
                });
                return;
              }
              final validationMessage = _validateNickname(nickname);
              if (validationMessage != null) {
                setSheetState(() {
                  inlineNotice = validationMessage;
                  inlineNoticeIsError = true;
                });
                return;
              }
              setSheetState(() {
                isChecking = true;
              });
              final available = await _isNicknameAvailable(nickname);
              setSheetState(() {
                isChecking = false;
                isChecked = available;
                lastChecked = available ? nickname : null;
                inlineNotice = available
                    ? '사용 가능한 닉네임입니다.'
                    : '이미 사용 중인 닉네임입니다.';
                inlineNoticeIsError = !available;
              });
            }

            Future<void> saveNickname() async {
              final nickname = controller.text.trim();
              if (nickname.isEmpty) {
                setSheetState(() {
                  inlineNotice = '닉네임을 입력해주세요.';
                  inlineNoticeIsError = true;
                });
                return;
              }
              final validationMessage = _validateNickname(nickname);
              if (validationMessage != null) {
                setSheetState(() {
                  inlineNotice = validationMessage;
                  inlineNoticeIsError = true;
                });
                return;
              }
              final currentNickname = (_nickname ?? '').trim();
              final nicknameChanged = nickname != currentNickname;
              final currentPhotoUrl = (_photoUrl ?? '').trim();
              final currentAvatarEmoji = (_avatarEmoji ?? '').trim();
              final nextPhotoUrl = (draftPhotoUrl ?? '').trim();
              final nextAvatarEmoji = (draftAvatarEmoji ?? '').trim();
              final profileOnlyChanged =
                  !nicknameChanged &&
                  (currentPhotoUrl != nextPhotoUrl ||
                      currentAvatarEmoji != nextAvatarEmoji);

              if (!nicknameChanged && !profileOnlyChanged) {
                Navigator.of(context).pop();
                return;
              }

              if (nicknameChanged && (!isChecked || lastChecked != nickname)) {
                await checkNickname();
                if (!isChecked || lastChecked != nickname) {
                  return;
                }
              }
              final docId = _userDocId;
              if (docId == null) {
                return;
              }
              final prevPhotoUrl = _photoUrl?.trim();
              final nextPhotoUrlRaw = draftPhotoUrl?.trim();
              final shouldDeletePrevPhoto =
                  removePhotoOnSave &&
                  prevPhotoUrl != null &&
                  prevPhotoUrl.isNotEmpty &&
                  (nextPhotoUrlRaw == null || nextPhotoUrlRaw.isEmpty);
              if (shouldDeletePrevPhoto) {
                await _deleteStorageImageByUrl(prevPhotoUrl);
              }
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(docId)
                  .set({
                    'displayName': nickname,
                    'displayNameLower': nickname.toLowerCase(),
                    'photoUrl': nextPhotoUrlRaw?.isNotEmpty == true
                        ? nextPhotoUrlRaw
                        : null,
                    'avatarEmoji': draftAvatarEmoji?.trim().isNotEmpty == true
                        ? draftAvatarEmoji!.trim()
                        : null,
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
              if (!mounted) {
                return;
              }
              setState(() {
                _nickname = nickname;
                _photoUrl = nextPhotoUrlRaw?.isNotEmpty == true
                    ? nextPhotoUrlRaw
                    : null;
                _avatarEmoji = draftAvatarEmoji?.trim().isNotEmpty == true
                    ? draftAvatarEmoji!.trim()
                    : null;
              });
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('프로필이 변경되었습니다.')));
              Navigator.of(context).pop();
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '프로필 편집',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildProfileAvatar(
                        displayName: controller.text.trim().isEmpty
                            ? (_nickname ?? '나')
                            : controller.text.trim(),
                        photoUrl: draftPhotoUrl,
                        avatarEmoji: draftAvatarEmoji,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: isUploadingImage
                                  ? null
                                  : () => pickFromGallery(),
                              icon: const Icon(
                                Icons.photo_library_outlined,
                                size: 16,
                              ),
                              label: const Text('사진 선택'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                textStyle: const TextStyle(fontSize: 12),
                                foregroundColor: const Color(0xFF8E5BFF),
                                side: const BorderSide(
                                  color: Color(0xFF8E5BFF),
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                setSheetState(() {
                                  draftPhotoUrl = null;
                                  removePhotoOnSave = true;
                                });
                              },
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: const Text('사진 제거'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                            if (isUploadingImage)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '기본 이모지 아바타 선택',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _defaultAvatarEmojis.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final emoji = _defaultAvatarEmojis[index];
                        final selected = draftAvatarEmoji == emoji;
                        return InkWell(
                          onTap: () {
                            setSheetState(() {
                              draftAvatarEmoji = emoji;
                              draftPhotoUrl = null;
                              removePhotoOnSave = true;
                            });
                          },
                          borderRadius: BorderRadius.circular(999),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: selected
                                ? const Color(0xFFDCC7FF)
                                : const Color(0xFFF4EEFF),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          maxLength: _maxNicknameLength,
                          decoration: InputDecoration(
                            hintText: '닉네임을 입력하세요',
                            counterText: '',
                            filled: true,
                            fillColor: const Color(0xFFF7F7F7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: isChecking ? null : checkNickname,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isChecked
                                ? const Color(0xFF2FA66A)
                                : const Color(0xFFFF7A3D),
                            side: BorderSide(
                              color: isChecked
                                  ? const Color(0xFF2FA66A)
                                  : const Color(0xFFFF7A3D),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: isChecking
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : isChecked
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
                  if (inlineNotice != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: inlineNoticeIsError
                            ? const Color(0xFFFFF1F1)
                            : const Color(0xFFEEFFF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: inlineNoticeIsError
                              ? const Color(0xFFFFD4D4)
                              : const Color(0xFFC8F1DA),
                        ),
                      ),
                      child: Text(
                        inlineNotice!,
                        style: TextStyle(
                          fontSize: 12,
                          color: inlineNoticeIsError
                              ? const Color(0xFFC63D3D)
                              : const Color(0xFF1D8A52),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: isUploadingImage ? null : saveNickname,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7A3D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '저장',
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
      },
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말 로그아웃할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A3D),
                foregroundColor: Colors.white,
              ),
              child: const Text('로그아웃'),
            ),
          ],
        );
      },
    );
    if (shouldLogout != true) {
      return;
    }
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    try {
      await UserApi.instance.logout();
    } catch (_) {}
    try {
      await FlutterNaverLogin.logOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lastProvider');
    await prefs.remove('lastProviderId');
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount() async {
    if (_deletingAccount) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('회원 탈퇴'),
          content: const Text('정말 탈퇴할까요? 탈퇴하면 저장된 정보가 모두 삭제됩니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
                foregroundColor: Colors.white,
              ),
              child: const Text('탈퇴하기'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    setState(() {
      _deletingAccount = true;
    });

    final userDocId = await _resolveUserDocId();
    if (userDocId == null) {
      if (mounted) {
        setState(() {
          _deletingAccount = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인 정보가 없어 탈퇴할 수 없어요.')));
      }
      return;
    }

    Future<void> deleteCollection(CollectionReference ref, String label) async {
      final snap = await ref.get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
      debugPrint('[delete-account] deleted $label: ${snap.size}');
    }

    Future<void> deleteStorageTree(Reference ref, String label) async {
      try {
        final result = await ref.listAll();
        for (final item in result.items) {
          await item.delete();
        }
        for (final prefix in result.prefixes) {
          await deleteStorageTree(prefix, label);
        }
        debugPrint('[delete-account] deleted storage tree: $label');
      } on FirebaseException catch (e) {
        if (e.code == 'object-not-found') {
          return;
        }
        rethrow;
      }
    }

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId);
      debugPrint('[delete-account] userDocId=$userDocId');
      final storage = FirebaseStorage.instance;
      await _deleteStorageImageByUrl(_photoUrl);
      await deleteStorageTree(
        storage.ref('users/$userDocId/profile'),
        'profile',
      );
      await deleteStorageTree(storage.ref('users/$userDocId/media'), 'media');
      await deleteCollection(userRef.collection('schools'), 'schools');
      await deleteCollection(
        userRef.collection('neighborhoods'),
        'neighborhoods',
      );
      await deleteCollection(userRef.collection('plans'), 'plans');
      await deleteCollection(userRef.collection('memories'), 'memories');
      await deleteCollection(userRef.collection('media'), 'media');
      await deleteCollection(userRef.collection('blocks'), 'blocks');
      await deleteCollection(userRef.collection('reports'), 'reports');
      await userRef.delete();
      debugPrint('[delete-account] user doc deleted');
    } catch (e) {
      debugPrint('[delete-account] firestore error: $e');
      if (mounted) {
        setState(() {
          _deletingAccount = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('탈퇴 중 오류가 발생했어요. 정보 삭제를 완료하지 못했습니다. ($e)')),
        );
      }
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await currentUser?.delete();
    } catch (e) {
      debugPrint('[delete-account] auth delete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('탈퇴는 완료되었지만, 계정 삭제를 위해 다시 로그인해주세요.')),
        );
      }
    }

    try {
      await UserApi.instance.unlink();
    } catch (_) {}
    try {
      await FlutterNaverLogin.logOut();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lastProvider');
    await prefs.remove('lastProviderId');

    if (!mounted) {
      return;
    }
    setState(() {
      _deletingAccount = false;
    });
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final displayName = _nickname?.trim().isNotEmpty == true
        ? _nickname!.trim()
        : '닉네임 없음';
    final bonusYearLabel = _age == null ? '보너스 게임 정보 없음' : '보너스 게임 ${_age}년차';
    final memberLabel = _premiumStatus?.isPremium == true
        ? '프리미엄 가입자'
        : '무료 멤버';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          Text(
            '설정',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? colorScheme.primary : const Color(0xFFFF7A3D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '앱 설정과 계정 정보를 관리하세요',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? colorScheme.onSurface.withOpacity(0.6)
                  : const Color(0xFF9B9B9B),
            ),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: _buildProfileAvatar(
                    displayName: displayName,
                    photoUrl: _photoUrl,
                    avatarEmoji: _avatarEmoji,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? colorScheme.onSurface : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bonusYearLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? colorScheme.onSurface.withOpacity(0.6)
                              : const Color(0xFF8A8A8A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        memberLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? colorScheme.onSurface.withOpacity(0.6)
                              : const Color(0xFF8A8A8A),
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _loadingProfile ? null : _openNicknameEditor,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    side: BorderSide(
                      color: isDark
                          ? colorScheme.outline.withOpacity(0.6)
                          : const Color(0xFFE0E0E0),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    '편집',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A7A7A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionHeader(title: '계정'),
          _SettingsCard(
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.person_outline,
                  label: '프로필 편집',
                  onTap: _loadingProfile ? null : _openNicknameEditor,
                ),
                if (_isPasswordAccount) ...[
                  Divider(
                    height: 1,
                    color: isDark ? colorScheme.outlineVariant : null,
                  ),
                  _SettingRow(
                    icon: Icons.lock_reset_rounded,
                    label: '비밀번호 변경',
                    onTap: _sendPasswordResetEmail,
                  ),
                ],
                Divider(
                  height: 1,
                  color: isDark ? colorScheme.outlineVariant : null,
                ),
                _SettingRow(
                  icon: Icons.workspace_premium_rounded,
                  label: '프리미엄 구독',
                  trailing: _Badge(
                    label: _premiumStatus?.isPremium == true ? '프리미엄' : '무료',
                  ),
                  onTap: _openPremiumManager,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionHeader(title: '앱 설정'),
          _SettingsCard(
            child: Column(
              children: [
                _SettingToggleRow(
                  icon: Icons.notifications_none_rounded,
                  label: '알림 설정',
                  value: _alertsEnabled,
                  onChanged: (value) async {
                    if (value && !_alertsEnabled) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('알림 설정'),
                          content: const Text('알림을 켜시겠어요?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('확인'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('취소'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) {
                        return;
                      }
                    }
                    setState(() {
                      _alertsEnabled = value;
                    });
                    await AppSettingsService.setAlertsEnabled(value);
                    await PushNotificationService.syncNotificationPreference(
                      value,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionHeader(title: '지원'),
          _SettingsCard(
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.help_outline_rounded,
                  label: '도움말',
                  onTap: _openHelpCenter,
                ),
                Divider(
                  height: 1,
                  color: isDark ? colorScheme.outlineVariant : null,
                ),
                _SettingRow(
                  icon: Icons.privacy_tip_outlined,
                  label: '개인정보 처리방침',
                  onTap: _openPrivacyPolicy,
                ),
                Divider(
                  height: 1,
                  color: isDark ? colorScheme.outlineVariant : null,
                ),
                _SettingRow(
                  icon: Icons.description_outlined,
                  label: '서비스 이용약관',
                  onTap: _openTermsOfService,
                ),
                Divider(
                  height: 1,
                  color: isDark ? colorScheme.outlineVariant : null,
                ),
                _SettingRow(
                  icon: Icons.support_agent_rounded,
                  label: '고객센터',
                  onTap: _openCustomerCenter,
                ),
                Divider(
                  height: 1,
                  color: isDark ? colorScheme.outlineVariant : null,
                ),
                _SettingRow(
                  icon: Icons.person_remove_alt_1_rounded,
                  label: _deletingAccount ? '탈퇴 처리 중...' : '탈퇴하기',
                  trailing: _deletingAccount
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.chevron_right,
                          color: Color(0xFFBDBDBD),
                        ),
                  onTap: _deletingAccount ? null : _deleteAccount,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Text(
                '인생은 보너스',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? colorScheme.onSurface.withOpacity(0.6)
                      : const Color(0xFF8A8A8A),
                ),
              ),
              SizedBox(height: 4),
              Text(
                '버전 1.0.0',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? colorScheme.onSurface.withOpacity(0.5)
                      : const Color(0xFFB0B0B0),
                ),
              ),
              SizedBox(height: 4),
              Text(
                '© 2026 Life is Bonus. All rights reserved.',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? colorScheme.onSurface.withOpacity(0.5)
                      : const Color(0xFFB0B0B0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _logout,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              side: BorderSide(
                color: isDark
                    ? colorScheme.error.withOpacity(0.6)
                    : const Color(0xFFFFD4D4),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: Icon(
              Icons.logout,
              color: isDark ? colorScheme.error : const Color(0xFFFF6B6B),
            ),
            label: Text(
              '로그아웃',
              style: TextStyle(
                color: isDark ? colorScheme.error : const Color(0xFFFF6B6B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? colorScheme.onSurface.withOpacity(0.6)
                : const Color(0xFF9B9B9B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _IconBubble(icon: icon),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: labelColor ?? (isDark ? colorScheme.onSurface : null),
              ),
            ),
            const Spacer(),
            trailing ??
                const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
          ],
        ),
      ),
    );
  }
}

class _SettingToggleRow extends StatelessWidget {
  const _SettingToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _IconBubble(icon: icon),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? colorScheme.onSurface : null,
            ),
          ),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFFF7A3D),
          ),
        ],
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceVariant : const Color(0xFFF4F4F4),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 16,
        color: isDark
            ? colorScheme.onSurface.withOpacity(0.7)
            : const Color(0xFF8A8A8A),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.primaryContainer : const Color(0xFFF3E6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isDark
              ? colorScheme.onPrimaryContainer
              : const Color(0xFF8E5BFF),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HelpFaqScreen extends StatelessWidget {
  const _HelpFaqScreen();

  @override
  Widget build(BuildContext context) {
    final isIOSPlatform = Theme.of(context).platform == TargetPlatform.iOS;
    final refundPolicyText = isIOSPlatform
        ? '인앱결제 환불은 Apple App Store 결제 정책을 따릅니다. App Store 결제내역에서 환불 요청을 진행해 주세요.'
        : '인앱결제 환불은 Google Play 결제 정책을 따릅니다. Google Play 결제내역에서 환불 요청을 진행해 주세요.';
    final faqs = <({String q, String a})>[
      (
        q: '인생은보너스 앱은 어떤 서비스인가요?',
        a: '학교/동네/추억/계획 기록을 기반으로 비슷한 배경과 계획을 가진 사람을 매칭하고, 프리미엄 구독 시 쪽지로 대화할 수 있는 서비스입니다.',
      ),
      (
        q: '회원가입 시 만 14세 미만도 이용할 수 있나요?',
        a: '아니요. 만 14세 미만은 회원가입 및 로그인이 제한됩니다.',
      ),
      (
        q: '매칭 수는 어떤 기준으로 계산되나요?',
        a: '학교/동네/계획 조건의 일치 여부를 기준으로 계산합니다. 동일 사용자라도 조건이 다르면 각각 별도 매칭으로 집계될 수 있습니다.',
      ),
      (
        q: '프리미엄 구독을 해지하면 바로 이용이 중단되나요?',
        a: '자동갱신만 중단되며, 이미 결제된 이용 기간이 남아 있으면 기간 종료 시점까지 프리미엄 기능을 사용할 수 있습니다.',
      ),
      (q: '환불은 어디서 진행하나요?', a: refundPolicyText),
      (
        q: '알림이 오지 않을 때는 어떻게 하나요?',
        a: '앱 설정의 알림 설정이 ON인지 확인하고, 단말 OS 설정에서 인생은보너스 알림 권한(잠금화면/배너/소리)을 허용해 주세요.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('도움말')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Text(
            '자주 묻는 질문',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...faqs.map(
            (item) => Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE9E9EF)),
              ),
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide.none,
                  ),
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide.none,
                  ),
                  title: Text(
                    item.q,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.a,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xFF66666F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerCenterScreen extends StatelessWidget {
  const _CustomerCenterScreen();

  static const String _supportEmail = 'lifeisbonus.app@gmail.com';

  Future<void> _openMailApp(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {'subject': '[인생은보너스] 문의'},
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('메일 앱을 열 수 없어요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('고객센터')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '문의 안내',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              '앱 이용 중 문의 사항 또는 결제/환불 관련 요청은 아래 이메일로 연락해 주세요.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF66666F),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7FB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE9E9EF)),
              ),
              child: const SelectableText(
                _supportEmail,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => _openMailApp(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A3D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('메일로 문의하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
