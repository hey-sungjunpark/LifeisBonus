import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/institution_alias_store.dart';
import '../utils/plan_city_alias_store.dart';

class MatchBucket {
  const MatchBucket({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.matchedUserIds,
    required this.type,
  });

  final String key;
  final String title;
  final String subtitle;
  final int count;
  final List<String> matchedUserIds;
  final MatchBucketType type;
}

enum MatchBucketType { school, neighborhood, plan }

class MatchAggregate {
  const MatchAggregate({
    required this.schoolBuckets,
    required this.neighborhoodBuckets,
    required this.planBuckets,
  });

  final List<MatchBucket> schoolBuckets;
  final List<MatchBucket> neighborhoodBuckets;
  final List<MatchBucket> planBuckets;

  int get schoolCount => schoolBuckets.fold(0, (sum, b) => sum + b.count);
  int get neighborhoodCount =>
      neighborhoodBuckets.fold(0, (sum, b) => sum + b.count);
  int get planCount => planBuckets.fold(0, (sum, b) => sum + b.count);
}

class MatchCountService {
  Future<MatchAggregate> loadForUser(String userDocId) async {
    final schoolBuckets = await _loadSchoolBuckets(userDocId);
    final neighborhoodBuckets = await _loadNeighborhoodBuckets(userDocId);
    final planBuckets = await _loadPlanBuckets(userDocId);
    return MatchAggregate(
      schoolBuckets: schoolBuckets,
      neighborhoodBuckets: neighborhoodBuckets,
      planBuckets: planBuckets,
    );
  }

  Future<List<MatchBucket>> _loadSchoolBuckets(String userDocId) async {
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

    final buckets = <MatchBucket>[];
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
            if (keys is! List) return false;
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
        buckets.add(
          MatchBucket(
            key: matchKey,
            title: schoolLabel.$1,
            subtitle: schoolLabel.$2,
            count: matchedUserIds.length,
            matchedUserIds: matchedUserIds.toList(),
            type: MatchBucketType.school,
          ),
        );
      }
    }
    return buckets;
  }

  Future<List<MatchBucket>> _loadNeighborhoodBuckets(String userDocId) async {
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

    final buckets = <MatchBucket>[];
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
      buckets.add(
        MatchBucket(
          key: matchKey,
          title: label.trim().isEmpty ? '동네' : label,
          subtitle: '$minYear년 ~ $maxYear년',
          count: matchedUserIds.length,
          matchedUserIds: matchedUserIds.toList(),
          type: MatchBucketType.neighborhood,
        ),
      );
    }
    return buckets;
  }

  Future<List<MatchBucket>> _loadPlanBuckets(String userDocId) async {
    final buckets = <MatchBucket>[];
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
      if (myStart == null || myEnd == null) continue;

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
      if (queryKeys.isEmpty) continue;

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
          if (resolvedId == null || resolvedId == userDocId) continue;
          final otherStart = _parseDateValue(other['startDate']);
          final otherEnd = _parseDateValue(other['endDate']);
          if (otherStart == null || otherEnd == null || otherEnd.isBefore(today)) {
            continue;
          }
          if (_rangesOverlapDate(myStart, myEnd, otherStart, otherEnd)) {
            matchedUserIds.add(resolvedId);
          }
        }
      }
      if (myCategory == '여행') {
        final myCountryNorm = _normalizeCountryForMatch(
          data['country']?.toString() ?? '',
        );
        final myCityNorm = _normalizeCityForMatch(data['city']?.toString() ?? '');
        if (myCountryNorm.isNotEmpty && myCityNorm.isNotEmpty) {
          List<QueryDocumentSnapshot<Map<String, dynamic>>> travelPool;
          try {
            travelPool = (await FirebaseFirestore.instance
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
            if (resolvedId == null || resolvedId == userDocId) continue;
            final otherCountryNorm = _normalizeCountryForMatch(
              other['country']?.toString() ?? '',
            );
            final otherCityNorm = _normalizeCityForMatch(
              other['city']?.toString() ?? '',
            );
            if (otherCountryNorm != myCountryNorm || otherCityNorm != myCityNorm) {
              continue;
            }
            final otherStart = _parseDateValue(other['startDate']);
            final otherEnd = _parseDateValue(other['endDate']);
            if (otherStart == null || otherEnd == null || otherEnd.isBefore(today)) {
              continue;
            }
            if (_rangesOverlapDate(myStart, myEnd, otherStart, otherEnd)) {
              matchedUserIds.add(resolvedId);
            }
          }
        }
      }
      if (matchedUserIds.isEmpty) continue;
      buckets.add(
        MatchBucket(
          key: myDoc.id,
          title: _buildPlanTitle(data),
          subtitle: _buildPlanSubtitle(data, myStart, myEnd),
          count: matchedUserIds.length,
          matchedUserIds: matchedUserIds.toList(),
          type: MatchBucketType.plan,
        ),
      );
    }
    return buckets;
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

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');

  int? _parseFlexibleInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    final text = value.toString().trim();
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
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

  String _normalizeProvince(String value) {
    var normalized = _normalize(value);
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
    if (location.isEmpty) return null;
    final start = _parseDateValue(data['startDate']);
    if (start == null) return null;
    return '${start.year}|$category|$location';
  }

  String? _buildLegacyTravelPlanMatchKeyFromData(Map<String, dynamic> data) {
    final category = data['category']?.toString() ?? '';
    if (category != '여행') return null;
    final start = _parseDateValue(data['startDate']);
    if (start == null) return null;
    final countryNorm = _normalizeCountryForMatch(
      data['country']?.toString() ?? '',
    );
    final cityNorm = _normalizeCityForMatch(data['city']?.toString() ?? '');
    if (countryNorm.isEmpty || cityNorm.isEmpty) return null;
    return '${start.year}|travel|$countryNorm|$cityNorm';
  }

  String _buildPlanTitle(Map<String, dynamic> data) {
    final category = data['category']?.toString() ?? '';
    if (category == '여행') {
      final country = data['country']?.toString() ?? '';
      final city = data['city']?.toString() ?? '';
      final label = [country, city].where((v) => v.trim().isNotEmpty).join(' / ');
      if (label.isNotEmpty) return label;
    }
    final title = data['title']?.toString() ?? '';
    if (title.trim().isNotEmpty) return title;
    return category.isEmpty ? '계획' : category;
  }

  String _buildPlanSubtitle(
    Map<String, dynamic> data,
    DateTime start,
    DateTime end,
  ) {
    final category = data['category']?.toString() ?? '';
    final startLabel =
        '${start.year}.${start.month.toString().padLeft(2, '0')}.${start.day.toString().padLeft(2, '0')}';
    final endLabel =
        '${end.year}.${end.month.toString().padLeft(2, '0')}.${end.day.toString().padLeft(2, '0')}';
    if (category == '이직') {
      final type = data['organizationType']?.toString() ?? '';
      if (type.trim().isNotEmpty) return '$type · $startLabel ~ $endLabel';
    }
    if (category == '건강') {
      final type = data['healthType']?.toString() ?? '';
      if (type.trim().isNotEmpty) return '$type · $startLabel ~ $endLabel';
    }
    if (category == '인생목표') {
      final type = data['lifeGoalType']?.toString() ?? '';
      if (type.trim().isNotEmpty) return '$type · $startLabel ~ $endLabel';
    }
    return '$startLabel ~ $endLabel';
  }
}
