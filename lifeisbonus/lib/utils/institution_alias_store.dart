import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class InstitutionAliasStore {
  InstitutionAliasStore._();

  static final InstitutionAliasStore instance = InstitutionAliasStore._();

  bool _loaded = false;
  final Map<String, String> _aliases = <String, String>{..._defaultAliases};

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    try {
      final raw =
          await rootBundle.loadString('assets/json/institution_aliases.json');
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
      debugPrint('[institution-alias] load failed: $e');
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
    'kt': 'kt',
    '케이티': 'kt',
    'koreatelecom': 'kt',
    '한국아이비엠': 'ibm',
    'ibm': 'ibm',
    'internationalbusinessmachines': 'ibm',
    '엘지전자': 'lg전자',
    'lg전자': 'lg전자',
    'lgelectronics': 'lg전자',
    '에스케이하이닉스': 'sk하이닉스',
    'sk하이닉스': 'sk하이닉스',
    'skhynix': 'sk하이닉스',
    '네이버': '네이버',
    'naver': '네이버',
    '카카오': '카카오',
    'kakao': '카카오',
    '한국전력공사': '한전',
    '한전': '한전',
    'kepco': '한전',
    '국민연금공단': '국민연금공단',
    '국민연금': '국민연금공단',
    'nps': '국민연금공단',
  };
}
