import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/match_count_service.dart';
import '../services/premium_service.dart';
import '../utils/institution_alias_store.dart';
import '../utils/plan_city_alias_store.dart';

class PremiumConnectScreen extends StatefulWidget {
  const PremiumConnectScreen({super.key});

  @override
  State<PremiumConnectScreen> createState() => _PremiumConnectScreenState();
}

class _PremiumConnectScreenState extends State<PremiumConnectScreen> {
  final ScrollController _scrollController = ScrollController();
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    final aggregate = await MatchCountService().loadForUser(userDocId);
    _schoolMatchCount = aggregate.schoolCount;
    _neighborhoodMatchCount = aggregate.neighborhoodCount;
    _planMatchCount = aggregate.planCount;
    for (final b in aggregate.schoolBuckets) {
      _schoolDetailItems.add(
        _PremiumDetailItem(
          title: b.title,
          subtitle: b.subtitle,
          count: b.count,
          icon: Icons.school_rounded,
        ),
      );
    }
    for (final b in aggregate.neighborhoodBuckets) {
      _neighborhoodDetailItems.add(
        _PremiumDetailItem(
          title: b.title,
          subtitle: b.subtitle,
          count: b.count,
          icon: Icons.home_rounded,
        ),
      );
    }
    for (final b in aggregate.planBuckets) {
      _planDetailItems.add(
        _PremiumDetailItem(
          title: b.title,
          subtitle: b.subtitle,
          count: b.count,
          icon: Icons.map_rounded,
        ),
      );
    }
  }

  (String, String) _buildSchoolDetailLabelFromMatchKey(
    String matchKey, {
    required String fallbackName,
  }) {
    final parts = matchKey.split('|');
    if (parts.length < 2) {
      return (fallbackName, '');
    }
    final level = parts[0];
    final schoolName = parts[1].trim().isEmpty ? fallbackName : parts[1].trim();
    if (level == 'kindergarten') {
      final year = parts.length >= 5 ? parts[4] : '';
      return (schoolName, year.isNotEmpty ? '$year년' : '');
    }
    if (level == 'university') {
      final major = parts.length >= 4 ? parts[3] : '';
      final year = parts.length >= 5 ? parts[4] : '';
      final subtitle = year.isNotEmpty ? '$year년' : '';
      if (major.isNotEmpty && subtitle.isNotEmpty) {
        return (schoolName, '$major · $subtitle');
      }
      return (schoolName, subtitle);
    }
    if (parts.length >= 7) {
      final year = parts[4];
      final grade = parts[5];
      final classNumber = parts[6];
      final title = classNumber.isNotEmpty
          ? '$schoolName ${grade}학년 ${classNumber}반'
          : '$schoolName ${grade}학년';
      return (title, year.isNotEmpty ? '$year년' : '');
    }
    return (schoolName, '');
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

  Future<void> _scrollToTopForSubscribe() async {
    if (!_scrollController.hasClients) {
      return;
    }
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
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
              controller: _scrollController,
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
                    onPremiumTap: () {
                      _scrollToTopForSubscribe();
                    },
                  ),
                  const SizedBox(height: 12),
                  _DetailSection(
                    title: '동네 매칭 상세',
                    items: _neighborhoodDetailItems,
                    onPremiumTap: () {
                      _scrollToTopForSubscribe();
                    },
                  ),
                  const SizedBox(height: 12),
                  _DetailSection(
                    title: '계획 매칭 상세',
                    items: _planDetailItems,
                    onPremiumTap: () {
                      _scrollToTopForSubscribe();
                    },
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
              fontSize: 24,
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
    required this.onPremiumTap,
  });

  final String title;
  final List<_PremiumDetailItem> items;
  final VoidCallback onPremiumTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
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
          if (items.isNotEmpty)
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DetailItemCard(item: item, onPremiumTap: onPremiumTap),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailItemCard extends StatelessWidget {
  const _DetailItemCard({required this.item, required this.onPremiumTap});

  final _PremiumDetailItem item;
  final VoidCallback onPremiumTap;

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
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Row(
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
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _DetailCountBadge(count: item.count),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              InkWell(
                onTap: onPremiumTap,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFF4B740),
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        '프리미엄으로 확인하기',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailCountBadge extends StatelessWidget {
  const _DetailCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
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
