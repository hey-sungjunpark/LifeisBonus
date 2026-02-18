import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/match_count_service.dart';
import '../services/premium_service.dart';
import '../utils/institution_alias_store.dart';
import '../utils/plan_city_alias_store.dart';
import 'premium_connect_screen.dart';
import 'message_match_detail_screen.dart';
import 'message_chat_screen.dart';
import 'message_manage_screen.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({
    super.key,
    this.openLatestUnreadToken = 0,
  });

  final int openLatestUnreadToken;

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  late Future<String?> _userDocIdFuture = PremiumService.resolveUserDocId();
  final Map<String, Future<_UserProfile>> _profileFutures = {};
  late Future<Set<String>> _blockedFuture = _loadBlockedUsers();
  int _lastHandledAutoOpenToken = -1;
  bool _autoOpenLatestUnreadRequested = false;

  @override
  void initState() {
    super.initState();
    _syncAutoOpenRequest();
  }

  @override
  void didUpdateWidget(covariant MessageScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAutoOpenRequest();
  }

  void _syncAutoOpenRequest() {
    if (widget.openLatestUnreadToken == _lastHandledAutoOpenToken) {
      return;
    }
    _lastHandledAutoOpenToken = widget.openLatestUnreadToken;
    _autoOpenLatestUnreadRequested = true;
  }

  Future<Set<String>> _loadBlockedUsers() async {
    final userDocId = await _userDocIdFuture;
    if (userDocId == null) {
      return {};
    }
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('blocks')
        .get();
    return snap.docs.map((doc) => doc.id).toSet();
  }

  Future<_MatchSections> _loadMatchSections() async {
    final userDocId = await _userDocIdFuture;
    if (userDocId == null) {
      return const _MatchSections.empty();
    }
    final aggregate = await MatchCountService().loadForUser(userDocId);
    final school = aggregate.schoolBuckets
        .map(
          (b) => _MatchCardData(
            title: b.title,
            subtitle: b.subtitle,
            count: '${b.count}명',
            matchKeys: [b.key],
            icon: Icons.school_rounded,
            matchType: _MatchType.school,
            matchedUserIds: b.matchedUserIds,
          ),
        )
        .toList();
    final neighborhood = aggregate.neighborhoodBuckets
        .map(
          (b) => _MatchCardData(
            title: b.title,
            subtitle: b.subtitle,
            count: '${b.count}명',
            matchKeys: const [],
            icon: Icons.home_rounded,
            matchType: _MatchType.neighborhood,
            matchedUserIds: b.matchedUserIds,
          ),
        )
        .toList();
    final plan = aggregate.planBuckets
        .map(
          (b) => _MatchCardData(
            title: b.title,
            subtitle: b.subtitle,
            count: '${b.count}명',
            matchKeys: const [],
            icon: Icons.map_rounded,
            matchType: _MatchType.plan,
            matchedUserIds: b.matchedUserIds,
          ),
        )
        .toList();
    return _MatchSections(
      schoolCards: school,
      neighborhoodCards: neighborhood,
      planCards: plan,
    );
  }

  Future<List<_MatchCardData>> _loadSchoolMatchCards() async {
    final userDocId = await _userDocIdFuture;
    if (userDocId == null) {
      return [];
    }
    final cards = <_MatchCardData>[];

    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>?
    fallbackAllSchoolsFuture;
    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    loadFallbackAllSchools() {
      fallbackAllSchoolsFuture ??= (() async {
        final usersSnap = await FirebaseFirestore.instance
            .collection('users')
            .get();
        final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        for (final user in usersSnap.docs) {
          final schoolsSnap = await user.reference.collection('schools').get();
          docs.addAll(schoolsSnap.docs);
        }
        return docs;
      })();
      return fallbackAllSchoolsFuture!;
    }

    try {
      final schoolSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .collection('schools')
          .orderBy('updatedAt', descending: true)
          .get();
      final seenSchoolKeys = <String>{};
      for (final doc in schoolSnapshot.docs) {
        final data = doc.data();
        final matchKeys = data['matchKeys'] is List
            ? (data['matchKeys'] as List)
                  .map((key) => key.toString())
                  .where((key) => key.isNotEmpty)
                  .toSet()
                  .toList()
            : <String>[];
        if (matchKeys.isEmpty) {
          continue;
        }

        for (final matchKey in matchKeys) {
          if (!seenSchoolKeys.add(matchKey)) {
            continue;
          }
          List<QueryDocumentSnapshot<Map<String, dynamic>>> schoolDocs;
          try {
            final matchSnap = await FirebaseFirestore.instance
                .collectionGroup('schools')
                .where('matchKeys', arrayContains: matchKey)
                .get();
            schoolDocs = matchSnap.docs;
          } catch (_) {
            final fallbackDocs = await loadFallbackAllSchools();
            schoolDocs = fallbackDocs.where((d) {
              final keys = d.data()['matchKeys'];
              if (keys is! List) {
                return false;
              }
              return keys.map((k) => k.toString()).contains(matchKey);
            }).toList();
          }
          final matchedUserIds = <String>{};
          for (final otherDoc in schoolDocs) {
            final otherData = otherDoc.data();
            final ownerId = otherData['ownerId'] as String?;
            final parentId = otherDoc.reference.parent.parent?.id;
            final resolvedId = ownerId ?? parentId;
            if (resolvedId == null || resolvedId == userDocId) {
              continue;
            }
            matchedUserIds.add(resolvedId);
          }
          if (matchedUserIds.isEmpty) {
            continue;
          }
          final schoolLabel = _buildSchoolLabelFromMatchKey(
            matchKey,
            fallbackName: data['name']?.toString() ?? '학교',
          );
          cards.add(
            _MatchCardData(
              title: schoolLabel.$1,
              subtitle: schoolLabel.$2,
              count: '${matchedUserIds.length}명',
              matchKeys: [matchKey],
              icon: Icons.school_rounded,
              matchType: _MatchType.school,
              matchedUserIds: matchedUserIds.toList(),
            ),
          );
        }
      }
    } catch (_) {}

    return cards;
  }

  (String, String) _buildSchoolLabelFromMatchKey(
    String matchKey, {
    required String fallbackName,
  }) {
    final parts = matchKey.split('|');
    if (parts.length < 2) {
      return (fallbackName, '');
    }
    final level = parts[0];
    final name = parts[1].trim().isEmpty ? fallbackName : parts[1].trim();
    if (level == 'kindergarten') {
      final year = parts.length >= 5 ? parts[4] : '';
      return (name, year.isNotEmpty ? '$year년' : '');
    }
    if (level == 'university') {
      final major = parts.length >= 4 ? parts[3] : '';
      final year = parts.length >= 5 ? parts[4] : '';
      final subtitle = year.isNotEmpty ? '$year년' : '';
      if (major.isNotEmpty && subtitle.isNotEmpty) {
        return (name, '$major · $subtitle');
      }
      return (name, subtitle);
    }
    if (parts.length >= 7) {
      final year = parts[4];
      final grade = parts[5];
      final classNumber = parts[6];
      final title = classNumber.isNotEmpty
          ? '$name ${grade}학년 ${classNumber}반'
          : '$name ${grade}학년';
      return (title, year.isNotEmpty ? '$year년' : '');
    }
    return (name, '');
  }

  Future<List<_MatchCardData>> _loadNeighborhoodMatchCards() async {
    final userDocId = await _userDocIdFuture;
    if (userDocId == null) {
      return [];
    }
    final cards = <_MatchCardData>[];
    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>?
    fallbackAllNeighborhoodsFuture;
    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    loadFallbackAllNeighborhoods() {
      fallbackAllNeighborhoodsFuture ??= (() async {
        final usersSnap = await FirebaseFirestore.instance
            .collection('users')
            .get();
        final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        for (final user in usersSnap.docs) {
          final neighborhoodsSnap = await user.reference
              .collection('neighborhoods')
              .get();
          docs.addAll(neighborhoodsSnap.docs);
        }
        return docs;
      })();
      return fallbackAllNeighborhoodsFuture!;
    }

    try {
      final userNeighborhoods = await FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .collection('neighborhoods')
          .get();
      final recordsByKey = <String, List<Map<String, int>>>{};
      final keyLabelMap = <String, String>{};
      for (final myDoc in userNeighborhoods.docs) {
        final data = myDoc.data();
        final province = data['province']?.toString() ?? '';
        final district = data['district']?.toString() ?? '';
        final dong = data['dong']?.toString() ?? '';
        final startYear = _parseFlexibleInt(data['startYear']);
        final endYear = _parseFlexibleInt(data['endYear']);
        if (startYear == null || endYear == null) continue;
        final matchKey = (data['matchKey']?.toString() ?? '').trim().isNotEmpty
            ? data['matchKey'].toString().trim()
            : _buildNeighborhoodMatchKeyFromFields(province, district, dong);
        if (matchKey.isEmpty) continue;
        recordsByKey.putIfAbsent(matchKey, () => <Map<String, int>>[]);
        recordsByKey[matchKey]!.add({'start': startYear, 'end': endYear});
        keyLabelMap[matchKey] = [
          province,
          district,
          dong,
        ].where((v) => v.trim().isNotEmpty).join(' ');
      }
      for (final entry in recordsByKey.entries) {
        final matchKey = entry.key;
        final ranges = entry.value;
        var minYear = 9999;
        var maxYear = 0;
        for (final r in ranges) {
          final s = r['start']!;
          final e = r['end']!;
          final low = s <= e ? s : e;
          final high = s <= e ? e : s;
          if (low < minYear) minYear = low;
          if (high > maxYear) maxYear = high;
        }
        List<QueryDocumentSnapshot<Map<String, dynamic>>> neighborhoodDocs;
        try {
          final matchSnap = await FirebaseFirestore.instance
              .collectionGroup('neighborhoods')
              .where('matchKey', isEqualTo: matchKey)
              .get();
          neighborhoodDocs = matchSnap.docs;
        } catch (_) {
          final fallbackDocs = await loadFallbackAllNeighborhoods();
          neighborhoodDocs = fallbackDocs.where((d) {
            return (d.data()['matchKey']?.toString() ?? '') == matchKey;
          }).toList();
        }
        final matchedUserIds = <String>{};
        for (final d in neighborhoodDocs) {
          final other = d.data();
          final ownerId = other['ownerId'] as String?;
          final parentId = d.reference.parent.parent?.id;
          final resolvedId = ownerId ?? parentId;
          if (resolvedId == null || resolvedId == userDocId) continue;
          final otherStart = _parseFlexibleInt(other['startYear']);
          final otherEnd = _parseFlexibleInt(other['endYear']);
          if (otherStart == null || otherEnd == null) continue;
          var overlaps = false;
          for (final r in ranges) {
            if (_rangesOverlap(r['start']!, r['end']!, otherStart, otherEnd)) {
              overlaps = true;
              break;
            }
          }
          if (overlaps) matchedUserIds.add(resolvedId);
        }
        if (matchedUserIds.isEmpty) continue;
        final label = keyLabelMap[matchKey] ?? '동네';
        cards.add(
          _MatchCardData(
            title: label.trim().isEmpty ? '동네' : label,
            subtitle: '$minYear년 ~ $maxYear년',
            count: '${matchedUserIds.length}명',
            matchKeys: const [],
            icon: Icons.home_rounded,
            matchType: _MatchType.neighborhood,
            matchedUserIds: matchedUserIds.toList(),
          ),
        );
      }
    } catch (_) {}
    return cards;
  }

  Future<List<_MatchCardData>> _loadPlanMatchCards() async {
    final userDocId = await _userDocIdFuture;
    if (userDocId == null) {
      return [];
    }
    final cards = <_MatchCardData>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>?
    fallbackAllPlansFuture;
    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    loadFallbackAllPlans() {
      fallbackAllPlansFuture ??= (() async {
        final usersSnap = await FirebaseFirestore.instance
            .collection('users')
            .get();
        final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        for (final user in usersSnap.docs) {
          final plansSnap = await user.reference.collection('plans').get();
          docs.addAll(plansSnap.docs);
        }
        return docs;
      })();
      return fallbackAllPlansFuture!;
    }

    try {
      final plansSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .collection('plans')
          .get();
      final active = plansSnap.docs.where((doc) {
        final end = _parseDateValue(doc.data()['endDate']);
        return end != null && !end.isBefore(today);
      });
      for (final myDoc in active) {
        final data = myDoc.data();
        final myCategory = data['category']?.toString() ?? '';
        final myStart = _parseDateValue(data['startDate']);
        final myEnd = _parseDateValue(data['endDate']);
        if (myStart == null || myEnd == null) {
          continue;
        }
        final storedMatchKey = data['matchKey']?.toString();
        final computedMatchKey = _buildPlanMatchKeyFromData(data);
        final legacyTravelKey = _buildLegacyTravelPlanMatchKeyFromData(data);
        final queryKeys = <String>{
          if (storedMatchKey != null && storedMatchKey.trim().isNotEmpty)
            storedMatchKey.trim(),
          if (computedMatchKey != null && computedMatchKey.isNotEmpty)
            computedMatchKey,
          if (legacyTravelKey != null && legacyTravelKey.isNotEmpty)
            legacyTravelKey,
        };
        if (queryKeys.isEmpty) {
          continue;
        }
        final matchedUserIds = <String>{};
        for (final key in queryKeys) {
          List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
          try {
            final matchSnap = await FirebaseFirestore.instance
                .collectionGroup('plans')
                .where('matchKey', isEqualTo: key)
                .get();
            docs = matchSnap.docs;
          } catch (_) {
            final fallbackDocs = await loadFallbackAllPlans();
            docs = fallbackDocs.where((d) {
              return (d.data()['matchKey']?.toString() ?? '') == key;
            }).toList();
          }
          for (final doc in docs) {
            final other = doc.data();
            final ownerId = other['ownerId'] as String?;
            final parentId = doc.reference.parent.parent?.id;
            final resolvedId = ownerId ?? parentId;
            if (resolvedId == null || resolvedId == userDocId) {
              continue;
            }
            final otherStart = _parseDateValue(other['startDate']);
            final otherEnd = _parseDateValue(other['endDate']);
            if (otherStart == null ||
                otherEnd == null ||
                otherEnd.isBefore(today)) {
              continue;
            }
            if (_rangesOverlapDate(myStart, myEnd, otherStart, otherEnd)) {
              matchedUserIds.add(resolvedId);
            }
          }
        }
        var count = matchedUserIds.length;
        if (myCategory == '여행') {
          final myCountryNorm = _normalizeCountryForMatch(
            data['country']?.toString() ?? '',
          );
          final myCityNorm = _normalizeCityForMatch(
            data['city']?.toString() ?? '',
          );
          if (myCountryNorm.isNotEmpty && myCityNorm.isNotEmpty) {
            List<QueryDocumentSnapshot<Map<String, dynamic>>> travelPool;
            try {
              travelPool =
                  (await FirebaseFirestore.instance
                          .collectionGroup('plans')
                          .where('category', isEqualTo: '여행')
                          .get())
                      .docs;
            } catch (_) {
              final fallbackDocs = await loadFallbackAllPlans();
              travelPool = fallbackDocs.where((d) {
                return (d.data()['category']?.toString() ?? '') == '여행';
              }).toList();
            }
            for (final doc in travelPool) {
              final other = doc.data();
              final ownerId = other['ownerId'] as String?;
              final parentId = doc.reference.parent.parent?.id;
              final resolvedId = ownerId ?? parentId;
              if (resolvedId == null || resolvedId == userDocId) {
                continue;
              }
              final otherCountryNorm = _normalizeCountryForMatch(
                other['country']?.toString() ?? '',
              );
              final otherCityNorm = _normalizeCityForMatch(
                other['city']?.toString() ?? '',
              );
              if (otherCountryNorm != myCountryNorm ||
                  otherCityNorm != myCityNorm) {
                continue;
              }
              final otherStart = _parseDateValue(other['startDate']);
              final otherEnd = _parseDateValue(other['endDate']);
              if (otherStart == null ||
                  otherEnd == null ||
                  otherEnd.isBefore(today)) {
                continue;
              }
              if (_rangesOverlapDate(myStart, myEnd, otherStart, otherEnd)) {
                matchedUserIds.add(resolvedId);
              }
            }
            count = matchedUserIds.length;
          }
        }
        if (count > 0) {
          cards.add(
            _MatchCardData(
              title: _buildPlanTitle(data),
              subtitle: _buildPlanSubtitle(data, myStart, myEnd),
              count: '$count명',
              matchKeys: const [],
              icon: Icons.map_rounded,
              matchType: _MatchType.plan,
              matchedUserIds: matchedUserIds.toList(),
            ),
          );
        }
      }
    } catch (_) {}
    return cards;
  }

  String? _buildLegacyTravelPlanMatchKeyFromData(Map<String, dynamic> data) {
    final category = data['category']?.toString() ?? '';
    if (category != '여행') {
      return null;
    }
    final start = _parseDateValue(data['startDate']);
    if (start == null) {
      return null;
    }
    final countryNorm = _normalizeCountryForMatch(
      data['country']?.toString() ?? '',
    );
    final cityNorm = _normalizeCityForMatch(data['city']?.toString() ?? '');
    if (countryNorm.isEmpty || cityNorm.isEmpty) {
      return null;
    }
    return '${start.year}|travel|$countryNorm|$cityNorm';
  }

  int? _parseFlexibleInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toInt();
    }
    final text = value.toString().trim();
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }
    return int.tryParse(digits);
  }

  bool _rangesOverlap(int startA, int endA, int startB, int endB) {
    final aStart = startA <= endA ? startA : endA;
    final aEnd = startA <= endA ? endA : startA;
    final bStart = startB <= endB ? startB : endB;
    final bEnd = startB <= endB ? endB : startB;
    return aStart <= bEnd && bStart <= aEnd;
  }

  bool _rangesOverlapDate(
    DateTime startA,
    DateTime endA,
    DateTime startB,
    DateTime endB,
  ) {
    return !endA.isBefore(startB) && !endB.isBefore(startA);
  }

  DateTime? _parseDateValue(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate().toLocal();
      return DateTime(d.year, d.month, d.day);
    }
    if (value is DateTime) {
      final d = value.toLocal();
      return DateTime(d.year, d.month, d.day);
    }
    if (value is String) {
      final d = DateTime.tryParse(value);
      if (d != null) {
        final local = d.toLocal();
        return DateTime(local.year, local.month, local.day);
      }
    }
    return null;
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');

  String _normalizeProvince(String value) {
    var normalized = _normalize(value);
    const suffixes = ['특별자치시', '특별자치도', '광역시', '특별시', '자치시', '자치도', '도', '시'];
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
    const suffixes = ['읍', '면', '동', '리'];
    for (final suffix in suffixes) {
      if (normalized.endsWith(suffix)) {
        normalized = normalized.substring(0, normalized.length - suffix.length);
        break;
      }
    }
    return normalized;
  }

  String _buildNeighborhoodMatchKeyFromFields(
    String province,
    String district,
    String dong,
  ) {
    final p = _normalizeProvince(province);
    final d = _normalizeDistrict(district);
    final n = _normalizeDong(dong);
    return '$p|$d|$n';
  }

  String? _buildPlanMatchKeyFromData(Map<String, dynamic> data) {
    final category = data['category']?.toString() ?? '';
    final country = data['country']?.toString() ?? '';
    final city = data['city']?.toString() ?? '';
    final location = _normalize(data['location']?.toString() ?? '');
    if (category == '여행') {
      final countryNorm = _normalizeCountryForMatch(country);
      final cityNorm = _normalizeCityForMatch(city);
      if (countryNorm.isNotEmpty && cityNorm.isNotEmpty) {
        return 'travel|$countryNorm|$cityNorm';
      }
    }
    if (category == '이직') {
      final typeNorm = _normalize(data['organizationType']?.toString() ?? '');
      final orgNorm = InstitutionAliasStore.instance.normalize(
        data['targetOrganization']?.toString() ?? '',
      );
      if (typeNorm.isNotEmpty && orgNorm.isNotEmpty) {
        return 'careerchange|$typeNorm|$orgNorm';
      }
    }
    if (category == '건강') {
      final typeNorm = _normalize(data['healthType']?.toString() ?? '');
      if (typeNorm.isNotEmpty) {
        return 'health|$typeNorm';
      }
    }
    if (category == '인생목표') {
      final lifeGoalNorm = _normalize(data['lifeGoalType']?.toString() ?? '');
      if (lifeGoalNorm.isNotEmpty) {
        return 'lifegoal|$lifeGoalNorm';
      }
    }
    if (location.isEmpty) {
      return null;
    }
    final start = _parseDateValue(data['startDate']);
    if (start == null) {
      return null;
    }
    return '${start.year}|$category|$location';
  }

  String _normalizeCountryForMatch(String value) {
    final normalized = _normalize(value);
    const aliases = {
      '한국': 'southkorea',
      '대한민국': 'southkorea',
      '대한민국국내': 'southkorea',
      'southkorea': 'southkorea',
      '일본': 'japan',
      'japan': 'japan',
      '미국': 'usa',
      'usa': 'usa',
      '중국': 'china',
      'china': 'china',
    };
    return aliases[normalized] ?? normalized;
  }

  String _normalizeCityForMatch(String value) {
    return PlanCityAliasStore.instance.normalize(value);
  }

  String _buildPlanTitle(Map<String, dynamic> data) {
    final category = data['category']?.toString() ?? '';
    if (category == '여행') {
      final country = data['country']?.toString() ?? '';
      final city = data['city']?.toString() ?? '';
      final label = [
        country,
        city,
      ].where((v) => v.trim().isNotEmpty).join(' / ');
      if (label.isNotEmpty) {
        return label;
      }
    }
    final title = data['title']?.toString() ?? '';
    if (title.trim().isNotEmpty) {
      return title;
    }
    return category.isEmpty ? '계획' : category;
  }

  String _buildPlanSubtitle(
    Map<String, dynamic> data,
    DateTime start,
    DateTime end,
  ) {
    final category = data['category']?.toString() ?? '';
    final dateText =
        '${start.year}.${start.month.toString().padLeft(2, '0')}.${start.day.toString().padLeft(2, '0')} ~ ${end.year}.${end.month.toString().padLeft(2, '0')}.${end.day.toString().padLeft(2, '0')}';
    if (category.isEmpty) {
      return dateText;
    }
    return '$category · $dateText';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PremiumStatus>(
      stream: PremiumService.watchStatus(),
      builder: (context, snapshot) {
        final isPremium = snapshot.data?.isPremium == true;
        return FutureBuilder<String?>(
          future: _userDocIdFuture,
          builder: (context, idSnapshot) {
            final userDocId = idSnapshot.data;
            return FutureBuilder<_MatchSections>(
              future: _loadMatchSections(),
              builder: (context, matchSnapshot) {
                final matchSections =
                    matchSnapshot.data ?? _MatchSections.empty();
                final hasMatchCards =
                    matchSections.schoolCards.isNotEmpty ||
                    matchSections.neighborhoodCards.isNotEmpty ||
                    matchSections.planCards.isNotEmpty;
                return FutureBuilder<Set<String>>(
                  future: _blockedFuture,
                  builder: (context, blockedSnap) {
                    final blocked = blockedSnap.data ?? {};
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      child: Column(
                        children: [
                          Text(
                            '나의 인연',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF7A3D),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '같은 추억과 계획을 가진 사람들과 연결되어 보세요',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9B9B9B),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!isPremium)
                            _PremiumCtaCard(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const PremiumConnectScreen(),
                                  ),
                                );
                              },
                            )
                          else
                            const _PremiumActiveInfo(),
                          const SizedBox(height: 16),
                          _ThreadSection(
                            userDocId: userDocId,
                            isPremium: isPremium,
                            autoOpenLatestUnread:
                                _autoOpenLatestUnreadRequested,
                            onAutoOpenHandled: () {
                              _autoOpenLatestUnreadRequested = false;
                            },
                            profileLoader: _loadProfile,
                            blocked: blocked,
                            onOpenThread: (thread) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => MessageChatScreen(
                                    otherUserId: thread.otherUserId,
                                    otherNickname: thread.otherNickname,
                                    otherPhotoUrl: thread.otherPhotoUrl,
                                  ),
                                ),
                              );
                            },
                            onBlock: (otherId) async {
                              if (userDocId == null) {
                                return;
                              }
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userDocId)
                                  .collection('blocks')
                                  .doc(otherId)
                                  .set({
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });
                              setState(() {
                                _blockedFuture = _loadBlockedUsers();
                              });
                            },
                            onReport: (otherId) async {
                              if (userDocId == null) {
                                return;
                              }
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userDocId)
                                  .collection('reports')
                                  .add({
                                    'targetId': otherId,
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });
                            },
                            onDeleteThread: (threadId) async {
                              if (userDocId == null) {
                                return;
                              }
                              await FirebaseFirestore.instance
                                  .collection('threads')
                                  .doc(threadId)
                                  .set({
                                    'hiddenBy.$userDocId': true,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));
                            },
                            onTogglePin: (threadId, pinned) async {
                              if (userDocId == null) {
                                return;
                              }
                              await FirebaseFirestore.instance
                                  .collection('threads')
                                  .doc(threadId)
                                  .set({
                                    'pinnedBy.$userDocId': pinned,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));
                            },
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: const [
                              Icon(
                                Icons.group_rounded,
                                color: Color(0xFFB356FF),
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                '나와 매칭되는 사람들',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (!hasMatchCards)
                            const _EmptyHint(
                              icon: Icons.search_off_rounded,
                              title: '아직 매칭된 사람이 없어요',
                              subtitle: '학교/동네/계획 기록을 더 추가해보세요',
                            )
                          else ...[
                            if (matchSections.schoolCards.isNotEmpty) ...[
                              const _MatchSectionTitle(title: '학교 매칭 상세'),
                              const SizedBox(height: 8),
                              ..._buildMatchCards(
                                context,
                                cards: matchSections.schoolCards,
                                isPremium: isPremium,
                              ),
                              const SizedBox(height: 6),
                            ],
                            if (matchSections.neighborhoodCards.isNotEmpty) ...[
                              const _MatchSectionTitle(title: '동네 매칭 상세'),
                              const SizedBox(height: 8),
                              ..._buildMatchCards(
                                context,
                                cards: matchSections.neighborhoodCards,
                                isPremium: isPremium,
                              ),
                              const SizedBox(height: 6),
                            ],
                            if (matchSections.planCards.isNotEmpty) ...[
                              const _MatchSectionTitle(title: '계획 매칭 상세'),
                              const SizedBox(height: 8),
                              ..._buildMatchCards(
                                context,
                                cards: matchSections.planCards,
                                isPremium: isPremium,
                              ),
                            ],
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  List<Widget> _buildMatchCards(
    BuildContext context, {
    required List<_MatchCardData> cards,
    required bool isPremium,
  }) {
    return cards.map((card) {
      Future<void> onTap() async {
        if (!isPremium) {
          if (!context.mounted) {
            return;
          }
          final goPremium = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('프리미엄 필요'),
              content: const Text('매칭된 사람 목록을 보려면 프리미엄이 필요해요.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('닫기'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('프리미엄 보기'),
                ),
              ],
            ),
          );
          if (goPremium == true && context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const PremiumConnectScreen(),
              ),
            );
          }
          return;
        }

        if (!context.mounted) {
          return;
        }
        if (card.matchType == _MatchType.school && card.matchKeys.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MessageMatchDetailScreen(
                title: card.title,
                subtitle: card.subtitle,
                matchKeys: card.matchKeys,
              ),
            ),
          );
          return;
        }
        if (card.matchedUserIds.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MessageMatchDetailScreen(
                title: card.title,
                subtitle: card.subtitle,
                matchKeys: const [],
                presetUserIds: card.matchedUserIds,
              ),
            ),
          );
        }
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _MatchCard(
          title: card.title,
          subtitle: card.subtitle,
          count: card.count,
          icon: card.icon,
          blur: !isPremium,
          showPremiumRow: !isPremium,
          onTapCount: onTap,
          onTapTitle: onTap,
        ),
      );
    }).toList();
  }

  Future<_UserProfile> _loadProfile(String userId) {
    return _profileFutures.putIfAbsent(userId, () async {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final data = doc.data();
      return _UserProfile(
        id: userId,
        nickname: (data?['displayName'] as String?)?.trim().isNotEmpty == true
            ? (data?['displayName'] as String).trim()
            : '알 수 없음',
        photoUrl: data?['photoUrl'] as String?,
        statusMessage: data?['statusMessage'] as String?,
      );
    });
  }
}

class _MatchCardData {
  const _MatchCardData({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.matchKeys,
    required this.icon,
    required this.matchType,
    required this.matchedUserIds,
  });

  final String title;
  final String subtitle;
  final String count;
  final List<String> matchKeys;
  final IconData icon;
  final _MatchType matchType;
  final List<String> matchedUserIds;
}

class _MatchSections {
  const _MatchSections({
    required this.schoolCards,
    required this.neighborhoodCards,
    required this.planCards,
  });

  const _MatchSections.empty()
    : schoolCards = const [],
      neighborhoodCards = const [],
      planCards = const [];

  final List<_MatchCardData> schoolCards;
  final List<_MatchCardData> neighborhoodCards;
  final List<_MatchCardData> planCards;
}

enum _MatchType { school, neighborhood, plan }

class _UserProfile {
  const _UserProfile({
    required this.id,
    required this.nickname,
    this.photoUrl,
    this.statusMessage,
  });

  final String id;
  final String nickname;
  final String? photoUrl;
  final String? statusMessage;
}

class _ThreadSection extends StatefulWidget {
  const _ThreadSection({
    required this.userDocId,
    required this.isPremium,
    required this.autoOpenLatestUnread,
    this.onAutoOpenHandled,
    required this.profileLoader,
    required this.blocked,
    required this.onOpenThread,
    required this.onDeleteThread,
    required this.onTogglePin,
    required this.onBlock,
    required this.onReport,
  });

  final String? userDocId;
  final bool isPremium;
  final bool autoOpenLatestUnread;
  final VoidCallback? onAutoOpenHandled;
  final Future<_UserProfile> Function(String userId) profileLoader;
  final Set<String> blocked;
  final ValueChanged<_ThreadItem> onOpenThread;
  final ValueChanged<String> onDeleteThread;
  final void Function(String threadId, bool pinned) onTogglePin;
  final ValueChanged<String> onBlock;
  final ValueChanged<String> onReport;

  @override
  State<_ThreadSection> createState() => _ThreadSectionState();
}

class _ThreadSectionState extends State<_ThreadSection> {
  bool _showAllOtherThreads = false;
  bool _autoOpenedUnread = false;

  @override
  void didUpdateWidget(covariant _ThreadSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.autoOpenLatestUnread && widget.autoOpenLatestUnread) {
      _autoOpenedUnread = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.userDocId == null)
          const _EmptyHint(
            icon: Icons.lock_outline,
            title: '로그인이 필요해요',
            subtitle: '로그인 후 쪽지를 확인할 수 있어요',
          )
        else
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('threads')
                .where('participants', arrayContains: widget.userDocId)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final threads =
                  docs
                      .map((doc) {
                        final data = doc.data();
                        final participants =
                            (data['participants'] as List?)
                                ?.map((id) => id.toString())
                                .toList() ??
                            <String>[];
                        final otherId = participants.firstWhere(
                          (id) => id != widget.userDocId,
                          orElse: () => '',
                        );
                        if (otherId.isEmpty ||
                            widget.blocked.contains(otherId)) {
                          return null;
                        }
                        final hiddenBy = (data['hiddenBy'] as Map?)
                            ?.cast<String, dynamic>();
                        if (hiddenBy != null &&
                            hiddenBy[widget.userDocId] == true) {
                          return null;
                        }
                        final lastMessage =
                            data['lastMessage']?.toString() ?? '';
                        final lastMessageAt = data['lastMessageAt'];
                        final lastMessageAtClient = data['lastMessageAtClient'];
                        DateTime? lastAt;
                        if (lastMessageAt is Timestamp) {
                          lastAt = lastMessageAt.toDate();
                        } else if (lastMessageAt is String) {
                          lastAt = DateTime.tryParse(lastMessageAt);
                        } else if (lastMessageAtClient is Timestamp) {
                          lastAt = lastMessageAtClient.toDate();
                        } else if (lastMessageAtClient is String) {
                          lastAt = DateTime.tryParse(lastMessageAtClient);
                        }
                        final pinnedBy = (data['pinnedBy'] as Map?)
                            ?.cast<String, dynamic>();
                        final isPinned =
                            pinnedBy != null &&
                            pinnedBy[widget.userDocId] == true;
                        final unread = _resolveUnreadCount(
                          data,
                          widget.userDocId ?? '',
                        );
                        return _ThreadItem(
                          threadId: doc.id,
                          otherUserId: otherId,
                          lastMessage: lastMessage,
                          lastMessageAt: lastAt,
                          unreadCount: unread is num ? unread.toInt() : 0,
                          isPinned: isPinned,
                        );
                      })
                      .whereType<_ThreadItem>()
                      .toList()
                    ..sort((a, b) {
                      if (a.isPinned != b.isPinned) {
                        return a.isPinned ? -1 : 1;
                      }
                      return (b.lastMessageAt ?? DateTime(0)).compareTo(
                        a.lastMessageAt ?? DateTime(0),
                      );
                    });
              if (widget.autoOpenLatestUnread &&
                  !_autoOpenedUnread &&
                  widget.isPremium) {
                _autoOpenedUnread = true;
                final targetThread = threads
                    .where((thread) => thread.unreadCount > 0)
                    .fold<_ThreadItem?>(
                      null,
                      (best, current) {
                        if (best == null) {
                          return current;
                        }
                        final bestAt = best.lastMessageAt ?? DateTime(0);
                        final currentAt = current.lastMessageAt ?? DateTime(0);
                        return currentAt.isAfter(bestAt) ? current : best;
                      },
                    );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) {
                    return;
                  }
                  widget.onAutoOpenHandled?.call();
                  if (targetThread != null) {
                    widget.onOpenThread(targetThread);
                  }
                });
              }
              if (threads.isEmpty) {
                return const _EmptyHint(
                  icon: Icons.mail_outline,
                  title: '아직 쪽지가 없어요',
                  subtitle: '매칭된 사람에게 쪽지를 보내보세요',
                );
              }
              final pinnedThreads = threads
                  .where((thread) => thread.isPinned)
                  .toList();
              final otherThreads = threads
                  .where((thread) => !thread.isPinned)
                  .toList();
              final visibleOtherThreads = _showAllOtherThreads
                  ? otherThreads
                  : otherThreads.take(2).toList();
              return Column(
                children: [
                  if (pinnedThreads.isNotEmpty)
                    _ThreadSectionHeader(
                      title: '고정된 대화',
                      onManage: widget.userDocId == null
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => MessageManageScreen(
                                    userDocId: widget.userDocId!,
                                  ),
                                ),
                              );
                            },
                    ),
                  if (pinnedThreads.isNotEmpty)
                    ..._buildThreadTiles(
                      context,
                      pinnedThreads,
                      widget.isPremium,
                      widget.profileLoader,
                      widget.onOpenThread,
                      widget.onTogglePin,
                      widget.onDeleteThread,
                      widget.onBlock,
                      widget.onReport,
                    ),
                  if (pinnedThreads.isNotEmpty && otherThreads.isNotEmpty)
                    const SizedBox(height: 6),
                  _ThreadSectionHeader(
                    title: pinnedThreads.isNotEmpty ? '모든 대화' : '대화 목록',
                    onManage: widget.userDocId == null
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => MessageManageScreen(
                                  userDocId: widget.userDocId!,
                                ),
                              ),
                            );
                          },
                  ),
                  ..._buildThreadTiles(
                    context,
                    visibleOtherThreads,
                    widget.isPremium,
                    widget.profileLoader,
                    widget.onOpenThread,
                    widget.onTogglePin,
                    widget.onDeleteThread,
                    widget.onBlock,
                    widget.onReport,
                  ),
                  if (otherThreads.length > 2)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _showAllOtherThreads = !_showAllOtherThreads;
                          });
                        },
                        child: Text(_showAllOtherThreads ? '접기' : '펼쳐서 보기'),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

List<Widget> _buildThreadTiles(
  BuildContext context,
  List<_ThreadItem> threads,
  bool isPremium,
  Future<_UserProfile> Function(String userId) profileLoader,
  ValueChanged<_ThreadItem> onOpenThread,
  void Function(String threadId, bool pinned) onTogglePin,
  ValueChanged<String> onDeleteThread,
  ValueChanged<String> onBlock,
  ValueChanged<String> onReport,
) {
  return threads.map((thread) {
    return FutureBuilder<_UserProfile>(
      future: profileLoader(thread.otherUserId),
      builder: (context, profileSnap) {
        final profile = profileSnap.data;
        final item = thread.copyWith(
          otherNickname: profile?.nickname ?? '알 수 없음',
          otherPhotoUrl: profile?.photoUrl,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ThreadTile(
            item: item,
            isPremium: isPremium,
            onTap: () {
              if (!isPremium) {
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('프리미엄 가입 필요'),
                    content: const Text('쪽지 내용을 보려면 프리미엄 가입이 필요해요'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PremiumConnectScreen(),
                            ),
                          );
                        },
                        child: const Text('프리미엄 가입'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('닫기'),
                      ),
                    ],
                  ),
                );
                return;
              }
              onOpenThread(item);
            },
            onLongPress: () async {
              await showModalBottomSheet<void>(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (sheetContext) {
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: Icon(
                            item.isPinned
                                ? Icons.push_pin_outlined
                                : Icons.push_pin,
                          ),
                          title: Text(item.isPinned ? '고정 해제' : '상단 고정'),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            onTogglePin(item.threadId, !item.isPinned);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete_outline),
                          title: const Text('대화 삭제'),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            onDeleteThread(item.threadId);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.block_outlined),
                          title: const Text('차단'),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            onBlock(item.otherUserId);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.report_gmailerrorred),
                          title: const Text('신고'),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            onReport(item.otherUserId);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }).toList();
}

class _ThreadItem {
  const _ThreadItem({
    required this.threadId,
    required this.otherUserId,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    this.isPinned = false,
    this.otherNickname = '알 수 없음',
    this.otherPhotoUrl,
  });

  final String threadId;
  final String otherUserId;
  final String otherNickname;
  final String? otherPhotoUrl;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isPinned;

  _ThreadItem copyWith({
    String? otherNickname,
    String? otherPhotoUrl,
    bool? isPinned,
  }) {
    return _ThreadItem(
      threadId: threadId,
      otherUserId: otherUserId,
      otherNickname: otherNickname ?? this.otherNickname,
      otherPhotoUrl: otherPhotoUrl ?? this.otherPhotoUrl,
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt,
      unreadCount: unreadCount,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.item,
    required this.isPremium,
    required this.onTap,
    required this.onLongPress,
  });

  final _ThreadItem item;
  final bool isPremium;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final unread = item.unreadCount;
    final badgeLabel = _formatCount(unread);
    final showBadge = unread > 0;
    final timeLabel = _formatThreadTime(item.lastMessageAt);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
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
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFF1E9FF),
              backgroundImage:
                  item.otherPhotoUrl == null || item.otherPhotoUrl!.isEmpty
                  ? null
                  : NetworkImage(item.otherPhotoUrl!),
              child: item.otherPhotoUrl == null || item.otherPhotoUrl!.isEmpty
                  ? const Icon(Icons.person, color: Color(0xFF8E5BFF))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.otherNickname,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _ThreadLastMessage(
                    threadId: item.threadId,
                    isPremium: isPremium,
                    fallbackText: item.lastMessage,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (timeLabel.isNotEmpty)
                  Text(
                    timeLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9B9B9B),
                    ),
                  ),
                if (showBadge) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadLastMessage extends StatelessWidget {
  const _ThreadLastMessage({
    required this.threadId,
    required this.isPremium,
    required this.fallbackText,
  });

  final String threadId;
  final bool isPremium;
  final String fallbackText;

  Future<String?> _loadLatestMessage() async {
    final snap = await FirebaseFirestore.instance
        .collection('threads')
        .doc(threadId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      return null;
    }
    final data = snap.docs.first.data();
    final text = data['text']?.toString();
    if (text != null && text.trim().isNotEmpty) {
      return text.trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final baseText = isPremium ? fallbackText : '프리미엄 가입 후 확인할 수 있어요';
    if (!isPremium || fallbackText.trim().isNotEmpty) {
      return Text(
        baseText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
      );
    }
    return FutureBuilder<String?>(
      future: _loadLatestMessage(),
      builder: (context, snapshot) {
        final text = snapshot.data?.trim();
        return Text(
          text?.isNotEmpty == true ? text! : baseText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
        );
      },
    );
  }
}

String _formatThreadTime(DateTime? time) {
  if (time == null) {
    return '';
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(time.year, time.month, time.day);
  if (date == today) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? '오전' : '오후';
    var displayHour = hour % 12;
    if (displayHour == 0) {
      displayHour = 12;
    }
    return '$period $displayHour:$minute';
  }
  return '${time.month}월 ${time.day}일';
}

String _formatCount(int count) {
  if (count <= 0) {
    return '';
  }
  if (count >= 100) {
    return '99+';
  }
  return count.toString();
}

int _resolveUnreadCount(Map<String, dynamic> data, String userId) {
  int _asInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  final unreadCounts = (data['unreadCounts'] as Map?)?.cast<String, dynamic>();
  final directCount = _asInt(unreadCounts?[userId]);
  if (directCount > 0) {
    return directCount;
  }
  final fallbackCount = _asInt(data['unreadCounts.$userId']);
  if (fallbackCount > 0) {
    return fallbackCount;
  }
  final lastSenderId = data['lastSenderId']?.toString();
  final lastMessageAtValue = data['lastMessageAt'];
  final lastMessageAtClientValue = data['lastMessageAtClient'];
  DateTime? lastMessageAt;
  if (lastMessageAtValue is Timestamp) {
    lastMessageAt = lastMessageAtValue.toDate();
  } else if (lastMessageAtValue is String) {
    lastMessageAt = DateTime.tryParse(lastMessageAtValue);
  } else if (lastMessageAtClientValue is Timestamp) {
    lastMessageAt = lastMessageAtClientValue.toDate();
  } else if (lastMessageAtClientValue is String) {
    lastMessageAt = DateTime.tryParse(lastMessageAtClientValue);
  }
  final lastReadAtMap = (data['lastReadAt'] as Map?)?.cast<String, dynamic>();
  DateTime? lastReadAt;
  final lastReadValue = lastReadAtMap?[userId] ?? data['lastReadAt.$userId'];
  if (lastReadValue is Timestamp) {
    lastReadAt = lastReadValue.toDate();
  } else if (lastReadValue is String) {
    lastReadAt = DateTime.tryParse(lastReadValue);
  }
  if (lastSenderId != null &&
      lastSenderId != userId &&
      lastMessageAt != null &&
      (lastReadAt == null || lastMessageAt.isAfter(lastReadAt))) {
    return 1;
  }
  return directCount > 0 ? directCount : fallbackCount;
}

class _ThreadSectionHeader extends StatelessWidget {
  const _ThreadSectionHeader({required this.title, this.onManage});

  final String title;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const Spacer(),
          if (onManage != null)
            TextButton(
              onPressed: onManage,
              child: const Text(
                '관리',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _MatchSectionTitle extends StatelessWidget {
  const _MatchSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4A4A4A),
        ),
      ),
    );
  }
}

class _PremiumCtaCard extends StatelessWidget {
  const _PremiumCtaCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E6FF),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFFF4B740),
            size: 36,
          ),
          const SizedBox(height: 10),
          const Text(
            '프리미엄으로 업그레이드',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            '같은 추억을 가진 사람들과 연결되고 쪽지를 주고받아보세요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF7A7A7A)),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB356FF), Color(0xFFFF4FA6)],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '월 9,900원으로 시작하기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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

class _PremiumActiveInfo extends StatelessWidget {
  const _PremiumActiveInfo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              '프리미엄 구독 중입니다. 매칭 결과를 확인해보세요.',
              style: TextStyle(fontSize: 12, color: Color(0xFF3A3A3A)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    this.blur = false,
    this.showPremiumRow = true,
    this.onTapCount,
    this.onTapTitle,
  });

  final String title;
  final String subtitle;
  final String count;
  final IconData icon;
  final bool blur;
  final bool showPremiumRow;
  final VoidCallback? onTapCount;
  final VoidCallback? onTapTitle;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1E9FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Color(0xFF8E5BFF), size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: onTapTitle,
                      borderRadius: BorderRadius.circular(6),
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
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
              if (!blur) _CountBadge(count: count, onTap: onTapCount),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          if (showPremiumRow) ...[
            Row(
              children: const [
                Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFF4B740),
                  size: 18,
                ),
                SizedBox(width: 6),
                Text(
                  '프리미엄으로 확인하기',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: const [
              Icon(Icons.person_outline, color: Color(0xFFB8B8B8), size: 18),
              SizedBox(width: 6),
              Text(
                '추억연결: 우리 반이었나요',
                style: TextStyle(fontSize: 12, color: Color(0xFFB8B8B8)),
              ),
            ],
          ),
        ],
      ),
    );

    if (!blur) {
      return card;
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: card,
          ),
        ),
        Positioned(
          right: 16,
          top: 16,
          child: _CountBadge(count: count, onTap: onTapCount),
        ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, this.onTap});

  final String count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF1FF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          count,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF3A8DFF),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFBDBDBD)),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
          ),
        ],
      ),
    );
  }
}
