import 'dart:convert';

import 'package:flutter/services.dart';

class InstitutionSuggestion {
  const InstitutionSuggestion({
    required this.name,
    required this.source,
  });

  final String name;
  final String source;
}

class InstitutionSearchService {
  InstitutionSearchService._();

  static List<String>? _companySeeds;
  static List<String>? _publicSeeds;
  static List<String>? _educationSeeds;
  static bool _loaded = false;

  static Future<List<InstitutionSuggestion>> search({
    required String query,
    required String organizationType,
  }) async {
    await _ensureLoaded();
    final trimmed = query.trim();
    return _localSuggestions(trimmed, organizationType);
  }

  static Future<void> _ensureLoaded() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    try {
      final companyRaw =
          await rootBundle.loadString('assets/json/institutions_companies_kr.json');
      final publicRaw =
          await rootBundle.loadString('assets/json/institutions_public_kr.json');
      final educationRaw =
          await rootBundle.loadString('assets/json/institutions_education_kr.json');
      _companySeeds = _parseAndDedupe(companyRaw);
      _publicSeeds = _parseAndDedupe(publicRaw);
      _educationSeeds = _parseAndDedupe(educationRaw);
    } catch (_) {
      _companySeeds = _fallbackCompanySeeds;
      _publicSeeds = _fallbackPublicSeeds;
      _educationSeeds = _fallbackEducationSeeds;
    }
  }

  static List<String> _parseAndDedupe(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      return const [];
    }
    final out = <String>[];
    final seen = <String>{};
    for (final item in decoded) {
      final name = item.toString().trim();
      if (name.isEmpty) {
        continue;
      }
      final key = _normalize(name);
      if (key.isEmpty || seen.contains(key)) {
        continue;
      }
      seen.add(key);
      out.add(name);
    }
    return out;
  }

  static List<InstitutionSuggestion> _localSuggestions(
    String query,
    String organizationType,
  ) {
    final q = _normalize(query);
    if (q.isEmpty) {
      return const [];
    }

    final company = _companySeeds ?? _fallbackCompanySeeds;
    final public = _publicSeeds ?? _fallbackPublicSeeds;
    final education = _educationSeeds ?? _fallbackEducationSeeds;
    final pool = switch (organizationType) {
      '회사' => company,
      '공공기관' => public,
      '교육/연구기관' => education,
      _ => [...company, ...public, ...education],
    };

    final queryKeys = _queryKeys(q, organizationType);
    final matched = pool
        .where((name) {
          final n = _normalize(name);
          for (final key in queryKeys) {
            if (n.contains(key)) {
              return true;
            }
          }
          return false;
        })
        .toList()
      ..sort((a, b) => _compareByRelevance(
            a,
            b,
            queryKeys,
            organizationType,
          ));

    final limited = matched.take(12).toList();
    return limited
        .map((name) => InstitutionSuggestion(name: name, source: 'local'))
        .toList();
  }

  static int _compareByRelevance(
    String a,
    String b,
    List<String> queryKeys,
    String organizationType,
  ) {
    int score(String name) {
      final n = _normalize(name);
      var s = 0;

      // 1) exact > startsWith > contains
      for (final key in queryKeys) {
        if (n == key) {
          s += 300;
        } else if (n.startsWith(key)) {
          s += 200;
        } else if (n.contains(key)) {
          s += 100;
        }
      }

      // 2) 교육/연구기관은 본교명 우선, 캠퍼스/분교는 하위
      if (organizationType == '교육/연구기관') {
        final isCampus =
            name.contains('캠퍼스') || name.contains('분교') || name.contains('대학원');
        if (isCampus) {
          s -= 30;
        } else {
          s += 20;
        }
      }

      // 3) 짧은 명칭 우선
      s -= n.length ~/ 10;
      return s;
    }

    final sa = score(a);
    final sb = score(b);
    if (sa != sb) {
      return sb.compareTo(sa);
    }
    return a.compareTo(b);
  }

  static List<String> _queryKeys(String q, String organizationType) {
    final keys = <String>{q};
    if (organizationType == '교육/연구기관') {
      // 약칭(연세대) -> 정식명(연세대학교) 매칭 강화
      if (q.endsWith('대') && !q.endsWith('대학교')) {
        keys.add('${q}학교');
        keys.add('${q}학');
      }
      if (q.contains('대학') && !q.contains('대학교')) {
        keys.add(q.replaceAll('대학', '대학교'));
      }
      // 공백/특수문자 입력 변형 대응
      keys.add(q.replaceAll('대학교', '대'));
      keys.add(q.replaceAll('캠퍼스', ''));
    }
    keys.removeWhere((e) => e.isEmpty);
    return keys.toList();
  }

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');

  static const List<String> _fallbackCompanySeeds = [
    '삼성전자',
    '네이버',
    '카카오',
    'LG전자',
    '현대자동차',
    '쿠팡',
    '토스',
    '라인',
    '배달의민족',
    '당근',
  ];

  static const List<String> _fallbackPublicSeeds = [
    '국민건강보험공단',
    '근로복지공단',
    '한국전력공사',
    '한국수자원공사',
    '한국도로공사',
    '국민연금공단',
    '한국철도공사',
    '한국토지주택공사',
    '한국은행',
    '한국가스공사',
  ];

  static const List<String> _fallbackEducationSeeds = [
    '서울대학교',
    '연세대학교',
    '고려대학교',
    '성균관대학교',
    '한양대학교',
    '서강대학교',
    '중앙대학교',
    '경희대학교',
    '한국외국어대학교',
    '이화여자대학교',
    'KAIST',
    '포항공과대학교',
    'UNIST',
    'DGIST',
    'GIST',
    '서울과학기술대학교',
    '한국연구재단',
    '한국교육개발원',
    '한국직업능력연구원',
    '한국과학기술연구원',
  ];
}
