import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HealthActivityAliasStore {
  HealthActivityAliasStore._();

  static final HealthActivityAliasStore instance = HealthActivityAliasStore._();

  bool _loaded = false;
  final Map<String, String> _aliases = <String, String>{..._defaultAliases};

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    try {
      final raw =
          await rootBundle.loadString('assets/json/health_activity_aliases.json');
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
      debugPrint('[health-alias] load failed: $e');
    } finally {
      _loaded = true;
    }
  }

  String normalize(String value) {
    final key = _normalize(value);
    return _aliases[key] ?? key;
  }

  String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');

  static const Map<String, String> _defaultAliases = {
    '달리기': 'running',
    '러닝': 'running',
    '조깅': 'running',
    'running': 'running',
    '걷기': 'walking',
    '워킹': 'walking',
    'walking': 'walking',
    '근력운동': 'strength',
    '웨이트': 'strength',
    '헬스': 'strength',
    'strength': 'strength',
    '수영': 'swimming',
    'swimming': 'swimming',
    '자전거': 'cycling',
    '사이클': 'cycling',
    'cycling': 'cycling',
    '요가': 'yoga',
    'yoga': 'yoga',
    '필라테스': 'pilates',
    'pilates': 'pilates',
    '다이어트': 'weightloss',
    '체중감량': 'weightloss',
    '감량': 'weightloss',
    'weightloss': 'weightloss',
    '수면관리': 'sleep',
    '수면': 'sleep',
    'sleep': 'sleep',
  };
}
