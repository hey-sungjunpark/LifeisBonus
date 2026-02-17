import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlanCityAliasStore {
  PlanCityAliasStore._();

  static final PlanCityAliasStore instance = PlanCityAliasStore._();

  bool _loaded = false;
  final Map<String, String> _aliases = <String, String>{..._defaultAliases};

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    try {
      final raw = await rootBundle.loadString('assets/json/plan_city_aliases.json');
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        for (final entry in decoded.entries) {
          final key = _normalize(entry.key);
          final value = _normalize(entry.value.toString());
          if (key.isNotEmpty && value.isNotEmpty) {
            _aliases[key] = value;
          }
        }
      }
    } catch (e) {
      debugPrint('[plan-city-alias] load failed: $e');
    } finally {
      _loaded = true;
    }
  }

  String normalize(String value) {
    var normalized = _normalize(value);
    const suffixes = ['특별시', '광역시', '자치시', '자치구', '시', '군', '구'];
    for (final suffix in suffixes) {
      if (normalized.endsWith(suffix) && normalized.length > suffix.length) {
        normalized = normalized.substring(0, normalized.length - suffix.length);
        break;
      }
    }
    return _aliases[normalized] ?? normalized;
  }

  String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');

  static const Map<String, String> _defaultAliases = {
    '서울': 'seoul',
    '서울시': 'seoul',
    'seoul': 'seoul',
    '부산': 'busan',
    '부산시': 'busan',
    'busan': 'busan',
    '도쿄': 'tokyo',
    '동경': 'tokyo',
    'tokyo': 'tokyo',
    '오사카': 'osaka',
    'osaka': 'osaka',
    '방콕': 'bangkok',
    'bangkok': 'bangkok',
    '파리': 'paris',
    'paris': 'paris',
    '로마': 'rome',
    'rome': 'rome',
    '뉴욕': 'newyork',
    'newyork': 'newyork',
    'newyorkcity': 'newyork',
    'losangeles': 'losangeles',
    '엘에이': 'losangeles',
    'la': 'losangeles',
    '런던': 'london',
    'london': 'london',
    '마드리드': 'madrid',
    'madrid': 'madrid',
    '하노이': 'hanoi',
    'hanoi': 'hanoi',
    '호치민': 'hochiminh',
    'hochiminh': 'hochiminh',
    '마닐라': 'manila',
    'manila': 'manila',
    '샌디에고': 'sandiego',
    'sandiago': 'sandiego',
    'sandiego': 'sandiego',
  };
}
