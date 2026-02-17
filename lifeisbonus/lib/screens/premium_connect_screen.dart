import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/premium_service.dart';
import '../utils/institution_alias_store.dart';
import '../utils/plan_city_alias_store.dart';

class PremiumConnectScreen extends StatefulWidget {
  const PremiumConnectScreen({super.key});

  @override
  State<PremiumConnectScreen> createState() => _PremiumConnectScreenState();
}

class _PremiumConnectScreenState extends State<PremiumConnectScreen> {
  bool _loading = true;
  PremiumStatus? _status;
  int _schoolMatchCount = 0;
  int _neighborhoodMatchCount = 0;
  int _planMatchCount = 0;
  String? _planMatchLabel;
  final Map<String, int> _neighborhoodMatchDetailCounts = {};
  final Map<String, String> _neighborhoodPeriodByLabel = {};
  final Map<String, int> _planCategoryMatchCounts = {};
  final List<_PremiumDetailItem> _schoolDetailItems = [];
  final List<_PremiumDetailItem> _neighborhoodDetailItems = [];
  final List<_PremiumDetailItem> _planDetailItems = [];
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
      try {
        await _loadMatches();
      } catch (e, st) {
        debugPrint('[premium-connect] loadMatches error: $e');
        debugPrint('[premium-connect] stack: $st');
        _error = '매칭 정보를 불러오지 못했어요.';
      }
    } catch (e) {
      debugPrint('[premium-connect] fetchStatus error: $e');
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
      debugPrint('[premium-connect] resolveUserDocId=null');
      return;
    }
    _schoolMatchCount = 0;
    _neighborhoodMatchCount = 0;
    _planMatchCount = 0;
    _planMatchLabel = null;
    _neighborhoodMatchDetailCounts.clear();
    _neighborhoodPeriodByLabel.clear();
    _planCategoryMatchCounts.clear();
    _schoolDetailItems.clear();
    _neighborhoodDetailItems.clear();
    _planDetailItems.clear();
    debugPrint('[premium-connect] userDocId=$userDocId');
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

    final schoolSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('schools')
        .orderBy('updatedAt', descending: true)
        .get();
    if (schoolSnapshot.docs.isNotEmpty) {
      var schoolTotal = 0;
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
        var recordMatchCount = 0;
        final allKeys = computedKeys
            .where((key) => key.isNotEmpty)
            .toSet()
            .toList();
        for (var i = 0; i < allKeys.length; i += 10) {
          final batch = allKeys.sublist(
            i,
            i + 10 > allKeys.length ? allKeys.length : i + 10,
          );
          List<QueryDocumentSnapshot<Map<String, dynamic>>> schoolDocs;
          try {
            final matchSnap = await FirebaseFirestore.instance
                .collectionGroup('schools')
                .where('matchKeys', arrayContainsAny: batch)
                .get();
            schoolDocs = matchSnap.docs;
          } catch (e) {
            final fallbackDocs = await loadFallbackAllSchools();
            schoolDocs = fallbackDocs.where((d) {
              final keys = d.data()['matchKeys'];
              if (keys is! List) {
                return false;
              }
              final keySet = keys.map((k) => k.toString()).toSet();
              return batch.any(keySet.contains);
            }).toList();
            debugPrint(
              '[premium-connect] school batch fallback docs=${schoolDocs.length} error=$e',
            );
          }
          for (final doc in schoolDocs) {
            final data = doc.data();
            final ownerId = data['ownerId'] as String?;
            final parentUserId = doc.reference.parent.parent?.id;
            final resolvedId = ownerId ?? parentUserId;
            if (resolvedId == null || resolvedId == userDocId) {
              continue;
            }
            final docKeys = data['matchKeys'];
            final hitCount = docKeys is List
                ? docKeys.map((k) => k.toString()).where(batch.contains).length
                : 0;
            if (hitCount == 0) {
              continue;
            }
            recordMatchCount += hitCount;
          }
        }
        if (recordMatchCount > 0) {
          final label = _buildSchoolDetailLabel(data);
          _schoolDetailItems.add(
            _PremiumDetailItem(
              title: label.$1,
              subtitle: label.$2,
              count: recordMatchCount,
              icon: Icons.school_rounded,
            ),
          );
          schoolTotal += recordMatchCount;
        }
      }
      _schoolDetailItems.sort((a, b) => b.count.compareTo(a.count));
      _schoolMatchCount = schoolTotal;
    }

    try {
      final userNeighborhoods = await FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .collection('neighborhoods')
          .get();
      if (userNeighborhoods.docs.isNotEmpty) {
        final recordsByKey = <String, List<Map<String, int>>>{};
        final keyLabelMap = <String, String>{};
        for (final doc in userNeighborhoods.docs) {
          final data = doc.data();
          final province = data['province']?.toString() ?? '';
          final district = data['district']?.toString() ?? '';
          final dong = data['dong']?.toString() ?? '';
          final startYear = _parseFlexibleInt(data['startYear']);
          final endYear = _parseFlexibleInt(data['endYear']);
          if (startYear == null || endYear == null) {
            continue;
          }
          var matchKey = data['matchKey'] as String?;
          if (matchKey == null || matchKey.trim().isEmpty) {
            matchKey = _buildNeighborhoodMatchKeyFromFields(
              province,
              district,
              dong,
            );
          }
          if (matchKey.isEmpty) {
            continue;
          }
          recordsByKey.putIfAbsent(matchKey, () => <Map<String, int>>[]);
          recordsByKey[matchKey]!.add({'start': startYear, 'end': endYear});
          keyLabelMap[matchKey] = [
            province,
            district,
            dong,
          ].where((v) => v.trim().isNotEmpty).join(' ');
        }
        for (final entry in recordsByKey.entries) {
          final ranges = entry.value;
          if (ranges.isEmpty) {
            continue;
          }
          var minYear = ranges.first['start']!;
          var maxYear = ranges.first['end']!;
          for (final range in ranges) {
            final start = range['start']!;
            final end = range['end']!;
            final low = start <= end ? start : end;
            final high = start <= end ? end : start;
            if (low < minYear) {
              minYear = low;
            }
            if (high > maxYear) {
              maxYear = high;
            }
          }
          final label = keyLabelMap[entry.key] ?? entry.key;
          _neighborhoodPeriodByLabel[label] = '$minYear년 ~ $maxYear년';
        }
        if (recordsByKey.isNotEmpty) {
          var matchCount = 0;
          for (final entry in recordsByKey.entries) {
            final matchKey = entry.key;
            final ranges = entry.value;
            final snap = await FirebaseFirestore.instance
                .collectionGroup('neighborhoods')
                .where('matchKey', isEqualTo: matchKey)
                .get();
            for (final doc in snap.docs) {
              final data = doc.data();
              final ownerId = data['ownerId'] as String?;
              final parentId = doc.reference.parent.parent?.id;
              final resolvedId = ownerId ?? parentId;
              if (resolvedId == null || resolvedId == userDocId) {
                continue;
              }
              final startYear = _parseFlexibleInt(data['startYear']);
              final endYear = _parseFlexibleInt(data['endYear']);
              if (startYear == null || endYear == null) {
                continue;
              }
              var overlaps = false;
              for (final range in ranges) {
                final rangeStart = range['start']!;
                final rangeEnd = range['end']!;
                if (_rangesOverlap(rangeStart, rangeEnd, startYear, endYear)) {
                  overlaps = true;
                  break;
                }
              }
              if (overlaps) {
                matchCount += 1;
                final label = keyLabelMap[matchKey] ?? matchKey;
                _neighborhoodMatchDetailCounts[label] =
                    (_neighborhoodMatchDetailCounts[label] ?? 0) + 1;
              }
            }
          }
          _neighborhoodMatchCount = matchCount;
          final sortedDetails = _neighborhoodMatchDetailCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          for (final entry in sortedDetails) {
            _neighborhoodDetailItems.add(
              _PremiumDetailItem(
                title: entry.key,
                subtitle: _neighborhoodPeriodByLabel[entry.key] ?? '',
                count: entry.value,
                icon: Icons.home_rounded,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[premium-connect] neighborhood error: $e');
    }

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final allPlanSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('plans')
        .get();
    final activePlanDocs = allPlanSnapshot.docs.where((doc) {
      final end = _parseDateValue(doc.data()['endDate']);
      return end != null && !end.isBefore(today);
    }).toList();
    if (activePlanDocs.isNotEmpty) {
      final allPlanMatches = <String>{};
      List<QueryDocumentSnapshot<Map<String, dynamic>>>? travelPool;
      for (final doc in activePlanDocs) {
        final myPlanId = doc.id;
        final data = doc.data();
        _planMatchLabel ??= data['title'] as String?;
        final myStart = _parseDateValue(data['startDate']);
        final myEnd = _parseDateValue(data['endDate']);
        final myCategory = data['category']?.toString() ?? '';
        final localMatchTokens = <String>{};
        final myCountryNorm = _normalizeCountryForMatch(
          data['country']?.toString() ?? '',
        );
        final myCityNorm = _normalizeCityForMatch(
          data['city']?.toString() ?? '',
        );
        final computedMatchKey = _buildPlanMatchKeyFromData(data);
        final storedMatchKey = data['matchKey'] as String?;
        final legacyMatchKey = _buildLegacyTravelPlanMatchKeyFromData(data);
        final queryKeys = <String>{
          if (computedMatchKey != null && computedMatchKey.isNotEmpty)
            computedMatchKey,
          if (storedMatchKey != null && storedMatchKey.isNotEmpty)
            storedMatchKey,
          if (legacyMatchKey != null && legacyMatchKey.isNotEmpty)
            legacyMatchKey,
        };
        if (computedMatchKey != null &&
            computedMatchKey.isNotEmpty &&
            data['matchKey'] != computedMatchKey) {
          await doc.reference.set({
            'matchKey': computedMatchKey,
            'countryNorm': _normalizeCountryForMatch(
              data['country']?.toString() ?? '',
            ),
            'cityNorm': _normalizeCityForMatch(data['city']?.toString() ?? ''),
            'ownerId': userDocId,
          }, SetOptions(merge: true));
        }
        for (final key in queryKeys) {
          List<QueryDocumentSnapshot<Map<String, dynamic>>> planDocs;
          try {
            final matchSnap = await FirebaseFirestore.instance
                .collectionGroup('plans')
                .where('matchKey', isEqualTo: key)
                .get();
            planDocs = matchSnap.docs;
          } catch (e) {
            final fallbackDocs = await loadFallbackAllPlans();
            planDocs = fallbackDocs.where((d) {
              return (d.data()['matchKey']?.toString() ?? '') == key;
            }).toList();
            debugPrint(
              '[premium-connect] plan key=$key fallback docs=${planDocs.length} error=$e',
            );
          }
          for (final matchDoc in planDocs) {
            final ownerId = matchDoc.data()['ownerId'] as String?;
            final parentUserId = matchDoc.reference.parent.parent?.id;
            final resolvedId = ownerId ?? parentUserId;
            if (resolvedId == null || resolvedId == userDocId) {
              continue;
            }
            final otherEnd = _parseDateValue(matchDoc.data()['endDate']);
            if (otherEnd == null || otherEnd.isBefore(today)) {
              continue;
            }
            if (myStart != null && myEnd != null) {
              final otherStart = _parseDateValue(matchDoc.data()['startDate']);
              if (otherStart == null ||
                  !_dateRangesOverlap(myStart, myEnd, otherStart, otherEnd)) {
                continue;
              }
            }
            final matchToken = '$myPlanId|$resolvedId|${matchDoc.id}';
            allPlanMatches.add(matchToken);
            localMatchTokens.add(matchToken);
          }
        }
        if (myCategory == '여행' &&
            myCountryNorm.isNotEmpty &&
            myCityNorm.isNotEmpty &&
            myStart != null &&
            myEnd != null) {
          if (travelPool == null) {
            try {
              travelPool =
                  (await FirebaseFirestore.instance
                          .collectionGroup('plans')
                          .where('category', isEqualTo: '여행')
                          .get())
                      .docs;
            } catch (e) {
              final fallbackDocs = await loadFallbackAllPlans();
              travelPool = fallbackDocs.where((d) {
                return (d.data()['category']?.toString() ?? '') == '여행';
              }).toList();
              debugPrint(
                '[premium-connect] travel fallback docs=${travelPool.length} error=$e',
              );
            }
          }
          final travelDocs = travelPool;
          for (final matchDoc in travelDocs) {
            final ownerId = matchDoc.data()['ownerId'] as String?;
            final parentUserId = matchDoc.reference.parent.parent?.id;
            final resolvedId = ownerId ?? parentUserId;
            if (resolvedId == null || resolvedId == userDocId) {
              continue;
            }
            final otherCountryNorm = _normalizeCountryForMatch(
              matchDoc.data()['country']?.toString() ?? '',
            );
            final otherCityNorm = _normalizeCityForMatch(
              matchDoc.data()['city']?.toString() ?? '',
            );
            if (otherCountryNorm != myCountryNorm ||
                otherCityNorm != myCityNorm) {
              continue;
            }
            final otherStart = _parseDateValue(matchDoc.data()['startDate']);
            final otherEnd = _parseDateValue(matchDoc.data()['endDate']);
            if (otherStart == null ||
                otherEnd == null ||
                otherEnd.isBefore(today)) {
              continue;
            }
            if (_dateRangesOverlap(myStart, myEnd, otherStart, otherEnd)) {
              final matchToken = '$myPlanId|$resolvedId|${matchDoc.id}';
              allPlanMatches.add(matchToken);
              localMatchTokens.add(matchToken);
            }
          }
        }
        if (localMatchTokens.isNotEmpty) {
          final localCount = localMatchTokens.length;
          _planCategoryMatchCounts[myCategory] =
              (_planCategoryMatchCounts[myCategory] ?? 0) + localCount;
          _planDetailItems.add(
            _PremiumDetailItem(
              title: _buildPlanDetailTitle(data),
              subtitle: _buildPlanDetailSubtitle(
                data,
                myStart,
                myEnd,
                myCategory,
              ),
              count: localCount,
              icon: Icons.map_rounded,
            ),
          );
        }
      }
      _planDetailItems.sort((a, b) => b.count.compareTo(a.count));
      _planMatchCount = allPlanMatches.length;
    }
  }

  (String, String) _buildSchoolDetailLabel(Map<String, dynamic> data) {
    final schoolName = data['name']?.toString() ?? '학교';
    var title = schoolName;
    var subtitle = '';
    final level = data['level']?.toString() ?? '';
    final gradeEntries = data['gradeEntries'];
    if (gradeEntries is List && gradeEntries.isNotEmpty) {
      final sorted = gradeEntries.whereType<Map>().toList()
        ..sort(
          (a, b) => (b['year'] as num? ?? 0).compareTo(a['year'] as num? ?? 0),
        );
      final entry = sorted.first;
      final grade = entry['grade'];
      final classNumber = entry['classNumber'];
      final year = entry['year'];
      if (grade != null && classNumber != null) {
        title = '$schoolName $grade학년 $classNumber반';
      }
      if (year != null) {
        subtitle = '$year년';
      }
    } else {
      if (level == 'kindergarten') {
        final gradYear = _parseFlexibleInt(data['kindergartenGradYear']);
        if (gradYear != null) {
          subtitle = '$gradYear년';
        }
      }
      final grade = data['grade'];
      final classNumber = data['classNumber'];
      final year = data['year'];
      if (grade != null && classNumber != null) {
        title = '$schoolName $grade학년 $classNumber반';
      }
      if (year != null) {
        subtitle = '$year년';
      }
    }
    return (title, subtitle);
  }

  String _buildPlanDetailTitle(Map<String, dynamic> data) {
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
    if (category == '이직') {
      final org = data['targetOrganization']?.toString() ?? '';
      if (org.trim().isNotEmpty) {
        return org;
      }
    }
    if (category == '건강') {
      final type = data['healthType']?.toString() ?? '';
      if (type.trim().isNotEmpty) {
        return type;
      }
    }
    if (category == '인생목표') {
      final type = data['lifeGoalType']?.toString() ?? '';
      if (type.trim().isNotEmpty) {
        return type;
      }
    }
    final title = data['title']?.toString() ?? '';
    return title.trim().isNotEmpty ? title : '계획';
  }

  String _buildPlanDetailSubtitle(
    Map<String, dynamic> data,
    DateTime? start,
    DateTime? end,
    String category,
  ) {
    final range = _formatDateRangeCompact(start, end);
    if (range.isEmpty) {
      return category;
    }
    if (category.isEmpty) {
      return range;
    }
    return '$category · $range';
  }

  String _formatDateRangeCompact(DateTime? start, DateTime? end) {
    if (start == null || end == null) {
      return '';
    }
    String fmt(DateTime d) {
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '$y.$m.$day';
    }

    return '${fmt(start)} ~ ${fmt(end)}';
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');

  String _normalizeProvince(String value) {
    var normalized = _normalize(value);
    if (normalized.isEmpty) {
      return normalized;
    }
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

  String _buildNeighborhoodMatchKeyFromFields(
    String province,
    String district,
    String dong,
  ) {
    final normalizedProvince = _normalizeProvince(province);
    final normalizedDistrict = _normalizeDistrict(district);
    final normalizedDong = _normalizeDong(dong);
    return '$normalizedProvince|$normalizedDistrict|$normalizedDong';
  }

  bool _rangesOverlap(int startA, int endA, int startB, int endB) {
    final aStart = startA <= endA ? startA : endA;
    final aEnd = startA <= endA ? endA : startA;
    final bStart = startB <= endB ? startB : endB;
    final bEnd = startB <= endB ? endB : startB;
    return aStart <= bEnd && bStart <= aEnd;
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
    if (level == 'university') {
      final code = _normalize(data['schoolCode']?.toString() ?? '');
      if (code.isNotEmpty) {
        return '$level|$code';
      }
      final campus = _normalize(data['campusType']?.toString() ?? '');
      return [level, name, campus].join('|');
    }
    final province = _normalizeProvince(data['province']?.toString() ?? '');
    final district = _normalizeDistrict(data['district']?.toString() ?? '');
    return [level, name, province, district].join('|');
  }

  List<String> _buildMatchKeysFromData(
    Map<String, dynamic> data,
    String schoolKey,
  ) {
    final keys = <String>[];
    final level = data['level']?.toString() ?? '';
    if (level == 'kindergarten') {
      final gradYear = _parseFlexibleInt(data['kindergartenGradYear']);
      if (gradYear != null) {
        keys.add('$schoolKey|$gradYear');
      }
      return keys;
    }
    if (level == 'university') {
      final major = _normalize(data['major']?.toString() ?? '');
      final entryYear = _parseFlexibleInt(data['universityEntryYear']);
      if (major.isNotEmpty && entryYear != null) {
        keys.add('$schoolKey|$major|$entryYear');
      }
      return keys;
    }
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
    final category = data['category']?.toString() ?? '';
    final country = data['country']?.toString() ?? '';
    final city = data['city']?.toString() ?? '';
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
    if (startDate == null) {
      return null;
    }
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
    return '${startDate.year}|$category|$location';
  }

  String? _buildLegacyTravelPlanMatchKeyFromData(Map<String, dynamic> data) {
    final category = data['category']?.toString() ?? '';
    if (category != '여행') {
      return null;
    }
    final startDate = _parseDateValue(data['startDate']);
    if (startDate == null) {
      return null;
    }
    final countryNorm = _normalizeCountryForMatch(
      data['country']?.toString() ?? '',
    );
    final cityNorm = _normalizeCityForMatch(data['city']?.toString() ?? '');
    if (countryNorm.isEmpty || cityNorm.isEmpty) {
      return null;
    }
    return '${startDate.year}|travel|$countryNorm|$cityNorm';
  }

  String _normalizeCountryForMatch(String value) {
    final normalized = _normalize(value);
    const aliases = {
      '한국': 'southkorea',
      '대한민국': 'southkorea',
      '대한민국국내': 'southkorea',
      'southkorea': 'southkorea',
      'korearepublicof': 'southkorea',
      'republicofkorea': 'southkorea',
      '일본': 'japan',
      '일본국': 'japan',
      'japan': 'japan',
      '미국': 'usa',
      '미합중국': 'usa',
      'unitedstates': 'usa',
      'usa': 'usa',
      '중국': 'china',
      '중화인민공화국': 'china',
      'china': 'china',
    };
    return aliases[normalized] ?? normalized;
  }

  DateTime? _parseDateValue(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate().toLocal();
      return DateTime(date.year, date.month, date.day);
    }
    if (value is DateTime) {
      final date = value.toLocal();
      return DateTime(date.year, date.month, date.day);
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        final date = parsed.toLocal();
        return DateTime(date.year, date.month, date.day);
      }
    }
    return null;
  }

  bool _dateRangesOverlap(
    DateTime startA,
    DateTime endA,
    DateTime startB,
    DateTime endB,
  ) {
    final aStart = startA.isBefore(endA) || startA.isAtSameMomentAs(endA)
        ? startA
        : endA;
    final aEnd = startA.isBefore(endA) || startA.isAtSameMomentAs(endA)
        ? endA
        : startA;
    final bStart = startB.isBefore(endB) || startB.isAtSameMomentAs(endB)
        ? startB
        : endB;
    final bEnd = startB.isBefore(endB) || startB.isAtSameMomentAs(endB)
        ? endB
        : startB;
    return !aEnd.isBefore(bStart) && !bEnd.isBefore(aStart);
  }

  String _normalizeCityForMatch(String value) {
    return PlanCityAliasStore.instance.normalize(value);
  }

  Future<void> _subscribe() async {
    await PremiumService.activateMonthly();
    await _loadPremium();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = _status?.isPremium == true;
    final totalCount =
        _schoolMatchCount + _neighborhoodMatchCount + _planMatchCount;
    return Scaffold(
      appBar: AppBar(title: const Text('프리미엄 연결')),
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
                  if (!isPremium) ...[
                    _SubscribeCard(onSubscribe: _subscribe),
                    const SizedBox(height: 16),
                  ] else ...[
                    _TotalMatchCard(totalCount: totalCount),
                    const SizedBox(height: 12),
                  ],
                  if (!isPremium) ...[
                    _TotalMatchCard(totalCount: totalCount),
                    const SizedBox(height: 12),
                  ],
                  _MatchSummaryCard(
                    title: '같은 학교였던 친구들',
                    subtitle: '동일 학교/반/년도 기반 매칭',
                    count: _schoolMatchCount,
                    icon: Icons.school_rounded,
                  ),
                  const SizedBox(height: 12),
                  _MatchSummaryCard(
                    title: '같은 동네였던 이웃들',
                    subtitle: '동일 동네/거주기간 기반 매칭',
                    count: _neighborhoodMatchCount,
                    icon: Icons.home_rounded,
                  ),
                  const SizedBox(height: 12),
                  _MatchSummaryCard(
                    title: '비슷한 계획을 가진 사람들',
                    subtitle: '동일 카테고리/세부조건/기간 기반 매칭',
                    count: _planMatchCount,
                    icon: Icons.map_rounded,
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: '학교 매칭 상세',
                    items: _schoolDetailItems,
                    emptyLabel: '학교 매칭 상세가 없습니다.',
                  ),
                  const SizedBox(height: 12),
                  _DetailSection(
                    title: '동네 매칭 상세',
                    items: _neighborhoodDetailItems,
                    emptyLabel: '동네 매칭 상세가 없습니다.',
                  ),
                  const SizedBox(height: 12),
                  _DetailSection(
                    title: '계획 매칭 상세',
                    items: _planDetailItems,
                    emptyLabel: '계획 매칭 상세가 없습니다.',
                  ),
                  const SizedBox(height: 16),
                  if (isPremium) const _PremiumActiveCard(),
                ],
              ),
            ),
    );
  }
}

class _TotalMatchCard extends StatelessWidget {
  const _TotalMatchCard({required this.totalCount});

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EEFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '총 매칭',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF707070),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '$totalCount명',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF8E5BFF),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.items,
    required this.emptyLabel,
  });

  final String title;
  final List<_PremiumDetailItem> items;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4A4A4A),
          ),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Text(
            emptyLabel,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
          )
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DetailItemCard(item: item),
            ),
          ),
      ],
    );
  }
}

class _DetailItemCard extends StatelessWidget {
  const _DetailItemCard({required this.item});

  final _PremiumDetailItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                child: Icon(
                  item.icon,
                  size: 16,
                  color: const Color(0xFF8E5BFF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (item.subtitle.isNotEmpty)
                      Text(
                        item.subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9B9B9B),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${item.count}명',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF3A8DFF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
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
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB356FF), Color(0xFFFF4FA6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPremium ? '프리미엄 활성화됨' : '프리미엄으로 연결하기',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
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
              '$count명',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF3A8DFF),
                fontWeight: FontWeight.w700,
              ),
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
            '월 9,900원으로 소중한 인연 만들기',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            '매칭된 사용자와 쪽지 탭에서 대화를 시작할 수 있어요.',
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

class _PremiumDetailItem {
  const _PremiumDetailItem({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
}
