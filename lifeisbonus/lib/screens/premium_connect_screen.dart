import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/premium_service.dart';

class PremiumConnectScreen extends StatefulWidget {
  const PremiumConnectScreen({super.key});

  @override
  State<PremiumConnectScreen> createState() => _PremiumConnectScreenState();
}

class _PremiumConnectScreenState extends State<PremiumConnectScreen> {
  bool _loading = true;
  PremiumStatus? _status;
  int _schoolMatchCount = 0;
  int _planMatchCount = 0;
  String? _schoolMatchLabel;
  String? _planMatchLabel;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPremium();
  }

  Future<void> _loadPremium() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await PremiumService.fetchStatus();
      _status = status;
      await _loadMatches();
    } catch (e) {
      _error = '프리미엄 정보를 불러오지 못했어요.';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMatches() async {
    final userDocId = await PremiumService.resolveUserDocId();
    if (userDocId == null) {
      return;
    }
    final schoolSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('schools')
        .orderBy('updatedAt', descending: true)
        .get();
    if (schoolSnapshot.docs.isNotEmpty) {
      final matchKeyMap = <String, Set<String>>{};
      String? lastSchoolName;
      for (final doc in schoolSnapshot.docs) {
        final data = doc.data();
        lastSchoolName ??= data['name'] as String?;
        final storedSchoolKey = data['schoolKey']?.toString();
        final schoolKey = storedSchoolKey ?? _buildSchoolKeyFromData(data);
        final storedKeys = data['matchKeys'] is List
            ? (data['matchKeys'] as List).map((key) => key.toString()).toList()
            : <String>[];
        final computedKeys = storedKeys.isNotEmpty
            ? storedKeys
            : _buildMatchKeysFromData(data, schoolKey);
        if (schoolKey.isEmpty || computedKeys.isEmpty) {
          continue;
        }
        if (data['schoolKey'] == null || data['matchKeys'] == null) {
          await doc.reference.set({
            'schoolKey': schoolKey,
            'matchKeys': computedKeys,
          }, SetOptions(merge: true));
        }
        matchKeyMap.putIfAbsent(schoolKey, () => <String>{});
        matchKeyMap[schoolKey]!.addAll(computedKeys);
      }
      if (matchKeyMap.isNotEmpty) {
        final matchedUsers = <String>{};
        final allKeys = matchKeyMap.values
            .expand((keys) => keys)
            .where((key) => key.isNotEmpty)
            .toSet()
            .toList();
        for (final key in allKeys) {
          final matchSnap = await FirebaseFirestore.instance
              .collectionGroup('schools')
              .where('matchKeys', arrayContains: key)
              .get();
          for (final matchDoc in matchSnap.docs) {
            final data = matchDoc.data();
            final ownerId = data['ownerId'] as String?;
            final parentUserId = matchDoc.reference.parent.parent?.id;
            final resolvedId = ownerId ?? parentUserId;
            if (resolvedId == null || resolvedId == userDocId) {
              continue;
            }
            matchedUsers.add(resolvedId);
          }
        }
        _schoolMatchCount = matchedUsers.length;
        _schoolMatchLabel = lastSchoolName;
      }
    }

    final planSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('plans')
        .orderBy('endDate', descending: false)
        .limit(1)
        .get();
    if (planSnapshot.docs.isNotEmpty) {
      final doc = planSnapshot.docs.first;
      final data = doc.data();
      final matchKey = _buildPlanMatchKeyFromData(data);
      if (matchKey != null && matchKey.isNotEmpty) {
        if (data['matchKey'] == null) {
          await doc.reference.set({'matchKey': matchKey}, SetOptions(merge: true));
        }
        final matchSnap = await FirebaseFirestore.instance
            .collectionGroup('plans')
            .where('matchKey', isEqualTo: matchKey)
            .get();
        final count = matchSnap.docs.where((matchDoc) {
          final ownerId = matchDoc.data()['ownerId'];
          final parentUserId = matchDoc.reference.parent.parent?.id;
          return ownerId != userDocId && parentUserId != userDocId;
        }).length;
        _planMatchCount = count;
        _planMatchLabel = data['title'] as String?;
      }
    }
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(' ', '').replaceAll('-', '');

  String _normalizeProvince(String value) {
    var normalized = _normalize(value);
    if (normalized.isEmpty) {
      return normalized;
    }
    const suffixes = [
      '특별자치시',
      '특별자치도',
      '광역시',
      '특별시',
      '자치시',
      '자치도',
      '도',
      '시',
    ];
    for (final suffix in suffixes) {
      if (normalized.endsWith(suffix)) {
        normalized = normalized.substring(0, normalized.length - suffix.length);
        break;
      }
    }
    return normalized;
  }

  String _normalizeDistrict(String value) {
    var normalized = _normalize(value);
    if (normalized.isEmpty) {
      return normalized;
    }
    const suffixes = ['특별자치구', '자치구', '구', '군', '시'];
    for (final suffix in suffixes) {
      if (normalized.endsWith(suffix)) {
        normalized = normalized.substring(0, normalized.length - suffix.length);
        break;
      }
    }
    return normalized;
  }

  String _normalizeDong(String value) {
    var normalized = _normalize(value);
    if (normalized.isEmpty) {
      return normalized;
    }
    const suffixes = ['읍', '면', '동', '리'];
    for (final suffix in suffixes) {
      if (normalized.endsWith(suffix)) {
        normalized = normalized.substring(0, normalized.length - suffix.length);
        break;
      }
    }
    return normalized;
  }

  int? _parseFlexibleInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toInt();
    }
    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty || text == '모름' || text == 'unknown') {
      return null;
    }
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }
    return int.tryParse(digits);
  }

  String _buildSchoolKeyFromData(Map<String, dynamic> data) {
    final level = data['level']?.toString() ?? '';
    final name = _normalize(data['name']?.toString() ?? '');
    final province = _normalizeProvince(data['province']?.toString() ?? '');
    final district = _normalizeDistrict(data['district']?.toString() ?? '');
    final dong = _normalizeDong(data['dong']?.toString() ?? '');
    return [level, name, province, district, dong].join('|');
  }

  List<String> _buildMatchKeysFromData(
    Map<String, dynamic> data,
    String schoolKey,
  ) {
    final keys = <String>[];
    final gradeEntries = data['gradeEntries'];
    if (gradeEntries is List) {
      for (final entry in gradeEntries) {
        if (entry is Map) {
          final year = _parseFlexibleInt(entry['year']);
          final grade = _parseFlexibleInt(entry['grade']);
          final classNumber = _parseFlexibleInt(entry['classNumber']);
          if (year != null && grade != null && classNumber != null) {
            keys.add('$schoolKey|$year|$grade|$classNumber');
          }
        }
      }
    } else {
      final year = _parseFlexibleInt(data['year']);
      final grade = _parseFlexibleInt(data['grade']);
      final classNumber = _parseFlexibleInt(data['classNumber']);
      if (year != null && grade != null && classNumber != null) {
        keys.add('$schoolKey|$year|$grade|$classNumber');
      }
    }
    return keys;
  }

  String? _buildPlanMatchKeyFromData(Map<String, dynamic> data) {
    final location = _normalize(data['location']?.toString() ?? '');
    final start = data['startDate'];
    DateTime? startDate;
    if (start is Timestamp) {
      startDate = start.toDate();
    } else if (start is DateTime) {
      startDate = start;
    } else if (start is String) {
      startDate = DateTime.tryParse(start);
    }
    if (startDate == null || location.isEmpty) {
      return null;
    }
    return '${startDate.year}|$location';
  }

  Future<void> _subscribe() async {
    await PremiumService.activateMonthly();
    await _loadPremium();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = _status?.isPremium == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('프리미엄 연결'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  _PremiumHeader(isPremium: isPremium),
                  const SizedBox(height: 16),
                  _MatchSummaryCard(
                    title: _schoolMatchLabel ?? '같은 학교 친구',
                    subtitle: '동일 학교/반/년도 기반 매칭',
                    count: _schoolMatchCount,
                    icon: Icons.school_rounded,
                  ),
                  const SizedBox(height: 12),
                  _MatchSummaryCard(
                    title: _planMatchLabel ?? '같은 계획',
                    subtitle: '동일 장소/기간 기반 매칭',
                    count: _planMatchCount,
                    icon: Icons.map_rounded,
                  ),
                  const SizedBox(height: 16),
                  if (!isPremium)
                    _SubscribeCard(onSubscribe: _subscribe)
                  else
                    const _PremiumActiveCard(),
                  const SizedBox(height: 16),
                  const _ChatInfoCard(),
                ],
              ),
            ),
    );
  }
}

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB356FF), Color(0xFFFF4FA6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded,
              color: Colors.white, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPremium ? '프리미엄 활성화됨' : '프리미엄으로 연결하기',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchSummaryCard extends StatelessWidget {
  const _MatchSummaryCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFF1E9FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF8E5BFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9B9B9B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${count}명',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF3A8DFF),
                fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscribeCard extends StatelessWidget {
  const _SubscribeCard({required this.onSubscribe});

  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E6FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            '월 9,900원으로 매칭 시작',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            '스토어 인앱결제 연결 전 테스트용 구독 흐름입니다.',
            style: TextStyle(fontSize: 11, color: Color(0xFF7A7A7A)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: onSubscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A3D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '구독 시작하기',
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
  }
}

class _PremiumActiveCard extends StatelessWidget {
  const _PremiumActiveCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8FFF1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Color(0xFF2FA66A)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '프리미엄 활성화 중입니다. 매칭 결과를 확인해보세요.',
              style: TextStyle(fontSize: 12, color: Color(0xFF3A3A3A)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatInfoCard extends StatelessWidget {
  const _ChatInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: const [
          Icon(Icons.chat_bubble_outline, color: Color(0xFF8E5BFF)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '매칭된 사용자와 쪽지 탭에서 대화를 시작할 수 있어요.',
              style: TextStyle(fontSize: 12, color: Color(0xFF7A7A7A)),
            ),
          ),
        ],
      ),
    );
  }
}
