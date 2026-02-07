import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'placeholder_screen.dart';
import 'record_screen.dart';
import 'plan_screen.dart';
import 'message_screen.dart';
import 'settings_screen.dart';
import 'google_profile_screen.dart';
import 'kakao_profile_screen.dart';
import 'naver_profile_screen.dart';
import 'premium_connect_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _checkedNickname = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureNickname();
    });
  }

  Future<void> _ensureNickname() async {
    if (_checkedNickname) {
      return;
    }
    _checkedNickname = true;
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString('lastProvider');
    final providerId = prefs.getString('lastProviderId');

    String? docId;
    if ((provider == 'kakao' || provider == 'naver') &&
        providerId != null &&
        providerId.isNotEmpty) {
      docId = '$provider:$providerId';
    } else {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        docId = authUser.uid;
      }
    }

    if (docId == null) {
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(docId).get();
      final displayName = doc.data()?['displayName'];
      final hasNickname = displayName is String && displayName.trim().isNotEmpty;
      if (hasNickname) {
        return;
      }
    } catch (_) {
      return;
    }

    if (!mounted) {
      return;
    }

    if (provider == 'kakao' && providerId != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => KakaoProfileScreen(kakaoId: providerId),
        ),
      );
      return;
    }
    if (provider == 'naver' && providerId != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => NaverProfileScreen(naverId: providerId),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const GoogleProfileScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const _HomeBody(),
      const RecordScreen(),
      const PlanScreen(),
      const MessageScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FB),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: _HomeBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    return const _HomeBodyContent();
  }
}

class _HomeBodyContent extends StatefulWidget {
  const _HomeBodyContent();

  @override
  State<_HomeBodyContent> createState() => _HomeBodyContentState();
}

class _HomeBodyContentState extends State<_HomeBodyContent> {
  late Future<_UserMetrics> _metricsFuture = _loadMetrics();
  late Future<String?> _nicknameFuture = _loadNickname();
  late Future<_MatchCounts> _matchCountsFuture = _loadMatchCounts();
  int? _targetAgeOverride;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_UserMetrics>(
      future: _metricsFuture,
      builder: (context, snapshot) {
        final metrics = snapshot.data ?? _UserMetrics.empty;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            children: [
              FutureBuilder<String?>(
                future: _nicknameFuture,
                builder: (context, snapshot) {
                  return _TodayBonusCard(nickname: snapshot.data);
                },
              ),
              const SizedBox(height: 16),
              _RemainingBonusCard(
                metrics: metrics,
                onChangeTargetAge: _updateTargetAge,
              ),
              const SizedBox(height: 16),
              _LifeJourneyCard(metrics: metrics),
              const SizedBox(height: 16),
              FutureBuilder<_MatchCounts>(
                future: _matchCountsFuture,
                builder: (context, snapshot) {
                  final counts = snapshot.data ?? const _MatchCounts();
                  return _PeopleCard(counts: counts);
                },
              ),
              const SizedBox(height: 90),
            ],
          ),
        );
      },
    );
  }

  Future<_UserMetrics> _loadMetrics() async {
    final birthDate = await _loadBirthDate();
    final prefs = await SharedPreferences.getInstance();
    final storedTargetAge = prefs.getInt('targetAge');

    if (birthDate == null) {
      return _UserMetrics.empty;
    }

    final now = DateTime.now();
    final age = _calculateAge(birthDate, now);
    final targetAge = _targetAgeOverride ?? storedTargetAge ?? 80;
    final targetDate = _addYears(birthDate, targetAge);
    final livedDays = now.difference(birthDate).inDays;
    final remainingDays = targetDate.difference(now).inDays.clamp(0, 100000);
    final progress = targetAge == 0 ? null : age / targetAge;
    return _UserMetrics(
      age: age,
      targetAge: targetAge,
      livedDays: livedDays,
      remainingDays: remainingDays,
      progress: progress?.clamp(0.0, 1.0),
    );
  }

  Future<DateTime?> _loadBirthDate() async {
    final docId = await _resolveUserDocId();
    if (docId == null) {
      return null;
    }
    return _fetchBirthDate('users', docId);
  }

  Future<String?> _loadNickname() async {
    final docId = await _resolveUserDocId();
    if (docId == null) {
      return null;
    }
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(docId).get();
      final displayName = doc.data()?['displayName'];
      if (displayName is String && displayName.trim().isNotEmpty) {
        return displayName.trim();
      }
    } catch (_) {}
    return null;
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

  Future<DateTime?> _fetchBirthDate(String collection, String docId) async {
    final doc = await FirebaseFirestore.instance.collection(collection).doc(docId).get();
    final data = doc.data();
    final birthDateValue = data?['birthDate'];
    if (birthDateValue is String) {
      return DateTime.tryParse(birthDateValue);
    }
    return null;
  }

  int _calculateAge(DateTime birthDate, DateTime now) {
    var age = now.year - birthDate.year;
    final hasBirthdayPassed = (now.month > birthDate.month) ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hasBirthdayPassed) {
      age -= 1;
    }
    if (age < 0) {
      age = 0;
    }
    return age;
  }

  DateTime _addYears(DateTime date, int years) {
    final year = date.year + years;
    final month = date.month;
    final day = date.day;
    final lastDay = DateTime(year, month + 1, 0).day;
    final safeDay = day <= lastDay ? day : lastDay;
    return DateTime(year, month, safeDay);
  }

  void _updateTargetAge(int nextAge) {
    final clamped = nextAge.clamp(1, 120);
    setState(() {
      _targetAgeOverride = clamped;
      _metricsFuture = _applyOverrides(targetAge: clamped);
    });
  }

  Future<_UserMetrics> _applyOverrides({
    int? targetAge,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (targetAge != null) {
      await prefs.setInt('targetAge', targetAge);
    }
    return _loadMetrics();
  }

  Future<_MatchCounts> _loadMatchCounts() async {
    final userDocId = await _resolveUserDocId();
    if (userDocId == null) {
      return const _MatchCounts();
    }
    final counts = <String, int>{};
    final uniqueUsers = <String>{};

    Future<void> applyCount(
      QuerySnapshot<Map<String, dynamic>> snapshot,
      String key,
    ) async {
      final users = snapshot.docs.map((doc) {
        final ownerId = doc.data()['ownerId'] as String?;
        final parentId = doc.reference.parent.parent?.id;
        return ownerId ?? parentId;
      }).whereType<String>().where((id) => id != userDocId).toSet();
      counts[key] = users.length;
      uniqueUsers.addAll(users);
    }

    final schoolSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('schools')
        .orderBy('updatedAt', descending: true)
        .get();
    if (schoolSnapshot.docs.isNotEmpty) {
      final matchKeyMap = <String, Set<String>>{};
      for (final doc in schoolSnapshot.docs) {
        final data = doc.data();
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
        final existingKeys = data['matchKeys'];
        final existingSet = existingKeys is List
            ? existingKeys.map((key) => key.toString()).toSet()
            : <String>{};
        final computedSet = computedKeys.toSet();
        final needsUpdate =
            (data['schoolKey'] != schoolKey) ||
            (computedSet.isNotEmpty &&
                (existingSet.isEmpty ||
                    existingSet.length != computedSet.length ||
                    !existingSet.containsAll(computedSet)));
        if (needsUpdate || data['ownerId'] == null) {
          await doc.reference.set({
            'schoolKey': schoolKey,
            'matchKeys': computedKeys,
            'ownerId': userDocId,
            'updatedAt': FieldValue.serverTimestamp(),
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
        for (var i = 0; i < allKeys.length; i += 10) {
          final batch = allKeys.sublist(
            i,
            i + 10 > allKeys.length ? allKeys.length : i + 10,
          );
          final snap = await FirebaseFirestore.instance
              .collectionGroup('schools')
              .where('matchKeys', arrayContainsAny: batch)
              .get();
          for (final doc in snap.docs) {
            final data = doc.data();
            final ownerId = data['ownerId'] as String?;
            final parentId = doc.reference.parent.parent?.id;
            final resolvedId = ownerId ?? parentId;
            if (resolvedId == null || resolvedId == userDocId) {
              continue;
            }
            matchedUsers.add(resolvedId);
          }
        }
        counts['school'] = matchedUsers.length;
        uniqueUsers.addAll(matchedUsers);
      }
    }

    final latestNeighborhood = await FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('neighborhoods')
        .orderBy('startYear', descending: true)
        .limit(1)
        .get();
    if (latestNeighborhood.docs.isNotEmpty) {
      final data = latestNeighborhood.docs.first.data();
      final matchKey = data['matchKey'] as String?;
      if (matchKey != null && matchKey.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collectionGroup('neighborhoods')
            .where('matchKey', isEqualTo: matchKey)
            .get();
        await applyCount(snap, 'neighborhood');
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcomingPlan = await FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('plans')
        .where('endDate', isGreaterThanOrEqualTo: today)
        .orderBy('endDate')
        .limit(1)
        .get();
    if (upcomingPlan.docs.isNotEmpty) {
      final data = upcomingPlan.docs.first.data();
      final matchKey = data['matchKey'] as String?;
      if (matchKey != null && matchKey.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collectionGroup('plans')
            .where('matchKey', isEqualTo: matchKey)
            .get();
        await applyCount(snap, 'plan');
      }
    }

    final latestMemory = await FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('memories')
        .orderBy('date', descending: true)
        .limit(1)
        .get();
    if (latestMemory.docs.isNotEmpty) {
      final data = latestMemory.docs.first.data();
      final matchKeys = data['matchKeys'] as List<dynamic>?;
      if (matchKeys != null && matchKeys.isNotEmpty) {
        final matchKey = matchKeys.first.toString();
        final snap = await FirebaseFirestore.instance
            .collectionGroup('memories')
            .where('matchKeys', arrayContains: matchKey)
            .get();
        await applyCount(snap, 'memory');
      }
    }

    return _MatchCounts(
      total: uniqueUsers.length,
      sameMemory: counts['memory'] ?? 0,
      sameSchool: counts['school'] ?? 0,
      sameNeighborhood: counts['neighborhood'] ?? 0,
      similarPlan: counts['plan'] ?? 0,
    );
  }

  String _normalizeMatchValue(String value) {
    return value.trim().toLowerCase().replaceAll(' ', '').replaceAll('-', '');
  }

  String _normalizeProvince(String value) {
    var normalized = _normalizeMatchValue(value);
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
    var normalized = _normalizeMatchValue(value);
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
    var normalized = _normalizeMatchValue(value);
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
    final name = _normalizeMatchValue(data['name']?.toString() ?? '');
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
}

class _TodayBonusCard extends StatelessWidget {
  const _TodayBonusCard({this.nickname});

  final String? nickname;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    final weekday = weekdays[now.weekday - 1];
    final dateLabel = '${now.year}년 ${now.month}월 ${now.day}일 $weekday';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFB356FF),
            Color(0xFFFF4FA6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.card_giftcard_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 6),
              if (nickname != null && nickname!.trim().isNotEmpty)
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: nickname!.trim(),
                        style: const TextStyle(
                          color: Color(0xFFFFC940),
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const TextSpan(
                        text: '님의 보너스 게임',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Text(
                  '오늘의 보너스 게임',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '매일은 소중한 선물입니다. 오늘도 즐겁게 보내세요!',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              dateLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemainingBonusCard extends StatelessWidget {
  const _RemainingBonusCard({
    required this.metrics,
    required this.onChangeTargetAge,
  });

  final _UserMetrics metrics;
  final ValueChanged<int> onChangeTargetAge;

  @override
  Widget build(BuildContext context) {
    final ageLabel = metrics.age?.toString() ?? '--';
    final targetAge = metrics.targetAge ?? 80;
    final remainingYears = metrics.age == null
        ? '--'
        : (targetAge - metrics.age!).clamp(0, 200).toString();
    final progressLabel = metrics.progress == null
        ? '--'
        : '${(metrics.progress! * 100).round()}%';
    final progressValue = metrics.progress ?? 0.0;
    return _HomeCard(
      title: '남은 보너스 게임',
      leading: Icons.calendar_today_rounded,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _AgePicker(
                  label: '현재 나이',
                  value: ageLabel,
                  onIncrease: null,
                  onDecrease: null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _AgePicker(
                  label: '목표 나이',
                  value: targetAge.toString(),
                  onIncrease: () => onChangeTargetAge(targetAge + 1),
                  onDecrease: () => onChangeTargetAge(targetAge - 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(label: '지난 년수', value: ageLabel, color: const Color(0xFFB356FF)),
              _StatItem(label: '남은 년수', value: remainingYears, color: const Color(0xFFFF4FA6)),
              _StatItem(label: '진행률', value: progressLabel, color: const Color(0xFF6A6A6A)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Text(
                '인생 진행률',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7A7A7A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                progressLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7A7A7A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6E1EE),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progressValue,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB356FF), Color(0xFFFF4FA6)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                '출생',
                style: TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
              ),
              const Spacer(),
              _CurrentAgeBadge(label: metrics.age == null ? '현재 --세' : '현재 ${metrics.age}세'),
              const Spacer(),
              Text(
                '${targetAge}세',
                style: const TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LifeJourneyCard extends StatelessWidget {
  const _LifeJourneyCard({required this.metrics});

  final _UserMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final ageLabel = metrics.age?.toString() ?? '--';
    final livedDays = metrics.livedDays;
    final remainingDays = metrics.remainingDays;
    final remainingYearsLabel =
        metrics.remainingYears == null ? '--' : metrics.remainingYears!.toString();
    final age = metrics.age ?? -1;
    final stageInfo = _stageForAge(age);
    final progressText = livedDays == null || remainingDays == null
        ? '나이를 입력하면 진행률이 표시됩니다.'
        : '${_formatNumber(livedDays)}일 살았어요.';
    final remainingText = remainingDays == null
        ? '+--일 더!'
        : '+${_formatNumber(remainingDays)}일 더!';
    final progressValue = metrics.progress ?? 0.0;
    return _HomeCard(
      title: '인생의 여정',
      leading: Icons.workspace_premium_rounded,
      child: Column(
        children: [
          const SizedBox(height: 6),
          _JourneyRing(
            progress: progressValue,
            ageLabel: ageLabel,
            livedDaysText: progressText,
            remainingText: remainingText,
          ),
          const SizedBox(height: 16),
          _StageRow(
            emoji: '🧸',
            chipColor: const Color(0xFFE8F1FF),
            chipTextColor: const Color(0xFF2C6BFF),
            label: '유년기',
            range: '0-10세',
            active: stageInfo.activeRangeIndex >= 0,
            highlight: stageInfo.currentRangeIndex == 0,
            progress: stageInfo.currentRangeIndex == 0
                ? _stageProgress(age, 0)
                : (stageInfo.activeRangeIndex >= 0 ? 1.0 : 0.0),
          ),
          const SizedBox(height: 10),
          _StageRow(
            emoji: '📚',
            chipColor: const Color(0xFFE7FAEC),
            chipTextColor: const Color(0xFF16A34A),
            label: '청소년기',
            range: '11-20세',
            active: stageInfo.activeRangeIndex >= 1,
            highlight: stageInfo.currentRangeIndex == 1,
            progress: stageInfo.currentRangeIndex == 1
                ? _stageProgress(age, 1)
                : (stageInfo.activeRangeIndex >= 1 ? 1.0 : 0.0),
          ),
          const SizedBox(height: 10),
          _StageRow(
            emoji: '🚀',
            chipColor: const Color(0xFFF0E8FF),
            chipTextColor: const Color(0xFF7C3AED),
            label: '청년기',
            range: '21-35세',
            active: stageInfo.activeRangeIndex >= 2,
            highlight: stageInfo.currentRangeIndex == 2,
            progress: stageInfo.currentRangeIndex == 2
                ? _stageProgress(age, 2)
                : (stageInfo.activeRangeIndex >= 2 ? 1.0 : 0.0),
          ),
          const SizedBox(height: 10),
          _StageRow(
            emoji: '💼',
            chipColor: const Color(0xFFFFF1E6),
            chipTextColor: const Color(0xFFF97316),
            label: '중년기',
            range: '36-60세',
            active: stageInfo.activeRangeIndex >= 3,
            highlight: stageInfo.currentRangeIndex == 3,
            progress: stageInfo.currentRangeIndex == 3
                ? _stageProgress(age, 3)
                : (stageInfo.activeRangeIndex >= 3 ? 1.0 : 0.0),
          ),
          const SizedBox(height: 10),
          _StageRow(
            emoji: '🌅',
            chipColor: const Color(0xFFFFEFF6),
            chipTextColor: const Color(0xFFDB2777),
            label: '노년기',
            range: '61세+',
            active: stageInfo.activeRangeIndex >= 4,
            highlight: stageInfo.currentRangeIndex == 4,
            progress: stageInfo.currentRangeIndex == 4
                ? _stageProgress(age, 4)
                : (stageInfo.activeRangeIndex >= 4 ? 1.0 : 0.0),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F0FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: metrics.age == null || metrics.progress == null
                ? const Text(
                    '생년월일을 입력하면 진행 상황을 보여드려요 ✨',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF8A8A8A)),
                  )
                : RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(fontSize: 11, color: Color(0xFF8A8A8A)),
                      children: [
                        const TextSpan(text: '현재 '),
                        TextSpan(
                          text: '${metrics.age}세',
                          style: const TextStyle(
                            color: Color(0xFFB356FF),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: '로 인생의 '),
                        TextSpan(
                          text: '${(metrics.progress! * 100).round()}%',
                          style: const TextStyle(
                            color: Color(0xFFB356FF),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: '를 경험했습니다\n'),
                        const TextSpan(text: '앞으로 '),
                        TextSpan(
                          text: '${remainingYearsLabel}년',
                          style: const TextStyle(
                            color: Color(0xFFB356FF),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: '의 소중한 시간이 남아있습니다 ✨'),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PeopleCard extends StatelessWidget {
  const _PeopleCard({required this.counts});

  final _MatchCounts counts;

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      title: '같은 추억을 가진 사람들',
      leading: Icons.group_rounded,
      gradient: const LinearGradient(
        colors: [Color(0xFFF3E6FF), Color(0xFFFDE9F6)],
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          Text(
            '${counts.total}명',
            style: const TextStyle(
              fontSize: 22,
              color: Color(0xFFB356FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '나와 비슷한 기록과 계획을 가진 사람들이 있습니다',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _PeopleRow(
                  label: '같은 학교 출신',
                  value: '${counts.sameSchool}명',
                ),
                const SizedBox(height: 8),
                _PeopleRow(
                  label: '같은 동네 거주',
                  value: '${counts.sameNeighborhood}명',
                ),
                const SizedBox(height: 8),
                _PeopleRow(
                  label: '비슷한 목표',
                  value: '${counts.similarPlan}명',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PremiumConnectScreen(),
                  ),
                );
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [Color(0xFFB356FF), Color(0xFFFF4FA6)],
                  ),
                ),
                child: Center(
                  child: Text(
                    '프리미엄으로 연결하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.title,
    required this.leading,
    required this.child,
    this.gradient,
  });

  final String title;
  final IconData leading;
  final Widget child;
  final LinearGradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: gradient,
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
          Row(
            children: [
              Icon(leading, color: const Color(0xFFB356FF), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4C4C4C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AgePicker extends StatelessWidget {
  const _AgePicker({
    required this.label,
    required this.value,
    this.onIncrease,
    this.onDecrease,
  });

  final String label;
  final String value;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF7A7A7A),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE3E3E3)),
          ),
          child: Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _AgeIconButton(
                icon: Icons.keyboard_arrow_up_rounded,
                onPressed: onIncrease,
              ),
              _AgeIconButton(
                icon: Icons.keyboard_arrow_down_rounded,
                onPressed: onDecrease,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AgeIconButton extends StatelessWidget {
  const _AgeIconButton({
    required this.icon,
    this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Icon(
          icon,
          size: 18,
          color: isEnabled ? const Color(0xFF4C4C4C) : const Color(0xFFBDBDBD),
        ),
      ),
    );
  }
}

class _UserMetrics {
  const _UserMetrics({
    this.age,
    this.targetAge,
    this.livedDays,
    this.remainingDays,
    this.progress,
  });

  final int? age;
  final int? targetAge;
  final int? livedDays;
  final int? remainingDays;
  final double? progress;

  int? get remainingYears {
    if (age == null || targetAge == null) {
      return null;
    }
    return (targetAge! - age!).clamp(0, 200);
  }

  static const empty = _UserMetrics();
}

class _JourneyRing extends StatefulWidget {
  const _JourneyRing({
    required this.progress,
    required this.ageLabel,
    required this.livedDaysText,
    required this.remainingText,
  });

  final double progress;
  final String ageLabel;
  final String livedDaysText;
  final String remainingText;

  @override
  State<_JourneyRing> createState() => _JourneyRingState();
}

class _JourneyRingState extends State<_JourneyRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartController;
  late final Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _heartScale = Tween<double>(begin: 0.96, end: 1.08).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: widget.progress),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return SizedBox(
          height: 156,
          width: 156,
          child: CustomPaint(
            painter: _RingPainter(progress: value),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _heartScale,
                    child: const Text('💖', style: TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${widget.ageLabel}세',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB356FF),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.livedDaysText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF7A7A7A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.remainingText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: Color(0xFFFF5A4E)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFF0F0F3);
    canvas.drawCircle(center, radius, backgroundPaint);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = const SweepGradient(
      colors: [
        Color(0xFFFFD6D6),
        Color(0xFFFFB3B3),
        Color(0xFFFF8A8A),
        Color(0xFFFF5A5A),
      ],
      startAngle: -3.141592653589793 / 2,
      endAngle: 3 * 3.141592653589793 / 2,
    );
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(rect);

    final sweep = progress.clamp(0.0, 1.0) * 2 * 3.141592653589793;
    canvas.drawArc(rect, -3.141592653589793 / 2, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _StageInfo {
  const _StageInfo({
    required this.activeRangeIndex,
    required this.currentRangeIndex,
  });

  final int activeRangeIndex;
  final int currentRangeIndex;
}

_StageInfo _stageForAge(int age) {
  if (age < 0) {
    return const _StageInfo(activeRangeIndex: -1, currentRangeIndex: -1);
  }
  if (age <= 10) {
    return const _StageInfo(activeRangeIndex: 0, currentRangeIndex: 0);
  }
  if (age <= 20) {
    return const _StageInfo(activeRangeIndex: 1, currentRangeIndex: 1);
  }
  if (age <= 35) {
    return const _StageInfo(activeRangeIndex: 2, currentRangeIndex: 2);
  }
  if (age <= 60) {
    return const _StageInfo(activeRangeIndex: 3, currentRangeIndex: 3);
  }
  return const _StageInfo(activeRangeIndex: 4, currentRangeIndex: 4);
}

double _stageProgress(int age, int stageIndex) {
  if (age < 0) {
    return 0.0;
  }
  if (stageIndex == 0) {
    return (age / 10).clamp(0.0, 1.0);
  }
  if (stageIndex == 1) {
    return ((age - 11) / 10).clamp(0.0, 1.0);
  }
  if (stageIndex == 2) {
    return ((age - 21) / 15).clamp(0.0, 1.0);
  }
  if (stageIndex == 3) {
    return ((age - 36) / 25).clamp(0.0, 1.0);
  }
  if (stageIndex == 4) {
    return ((age - 61) / 19).clamp(0.0, 1.0);
  }
  return 0.0;
}

String _formatNumber(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final position = text.length - i;
    buffer.write(text[i]);
    if (position > 1 && position % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
        ),
      ],
    );
  }
}

class _CurrentAgeBadge extends StatelessWidget {
  const _CurrentAgeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE7D6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFFFF7A3D),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.emoji,
    required this.chipColor,
    required this.chipTextColor,
    required this.label,
    required this.range,
    required this.active,
    required this.highlight,
    required this.progress,
  });

  final String emoji;
  final Color chipColor;
  final Color chipTextColor;
  final String label;
  final String range;
  final bool active;
  final bool highlight;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final borderColor = highlight ? const Color(0xFFC8A6FF) : Colors.transparent;
    final progressGradient = highlight
        ? const LinearGradient(colors: [Color(0xFFB356FF), Color(0xFFFF4FA6)])
        : const LinearGradient(colors: [Color(0xFF9CA3AF), Color(0xFF9CA3AF)]);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFF7F0FF) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: chipColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: chipTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    range,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
                  ),
                ],
              ),
              const Spacer(),
              if (active)
                const Icon(Icons.check_circle, color: Color(0xFF27C068), size: 16)
              else if (highlight)
                const Icon(Icons.circle, color: Color(0xFFB356FF), size: 10),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5E5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: progressGradient,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeopleRow extends StatelessWidget {
  const _PeopleRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E6FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8E5BFF),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _MatchCounts {
  const _MatchCounts({
    this.total = 0,
    this.sameMemory = 0,
    this.sameSchool = 0,
    this.sameNeighborhood = 0,
    this.similarPlan = 0,
  });

  final int total;
  final int sameMemory;
  final int sameSchool;
  final int sameNeighborhood;
  final int similarPlan;
}

class _HomeBottomNav extends StatelessWidget {
  const _HomeBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, -8),
          ),
        ],
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            label: '홈',
            icon: Icons.home_rounded,
            active: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            label: '기록',
            icon: Icons.menu_book_rounded,
            active: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          _NavItem(
            label: '계획',
            icon: Icons.blur_circular_rounded,
            active: currentIndex == 2,
            onTap: () => onTap(2),
          ),
          _NavItem(
            label: '쪽지',
            icon: Icons.chat_bubble_outline_rounded,
            active: currentIndex == 3,
            onTap: () => onTap(3),
          ),
          _NavItem(
            label: '설정',
            icon: Icons.settings_rounded,
            active: currentIndex == 4,
            onTap: () => onTap(4),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    this.active = false,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFFFF7A3D) : const Color(0xFFB0B0B0);
    final bgColor = active ? const Color(0xFFFFF0E6) : Colors.transparent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
