import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  int _tabIndex = 0;
  final List<_SchoolRecord> _schools = [];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          const Text(
            '나의 기록',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFF7A3D),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '지나온 소중한 순간들을 기록해보세요',
            style: TextStyle(fontSize: 12, color: Color(0xFF9B9B9B)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                _RecordTab(
                  label: '학교',
                  active: _tabIndex == 0,
                  onTap: () => _setTab(0),
                ),
                _RecordTab(
                  label: '동네',
                  active: _tabIndex == 1,
                  onTap: () => _setTab(1),
                ),
                _RecordTab(
                  label: '추억',
                  active: _tabIndex == 2,
                  onTap: () => _setTab(2),
                ),
                _RecordTab(
                  label: '사진',
                  active: _tabIndex == 3,
                  onTap: () => _setTab(3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_tabIndex == 0) ...[
            _SchoolHeader(onAdd: _openAddSchool),
            const SizedBox(height: 12),
            if (_schools.isEmpty)
              const _EmptyHint(
                icon: Icons.school_rounded,
                title: '아직 추가한 학교가 없어요',
                subtitle: '다닌 학교를 추가해보세요',
              )
            else
              ..._schools
                  .map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SchoolCard(record: record),
                    ),
                  )
                  .toList(),
          ] else
            const _EmptyHint(
              icon: Icons.hourglass_empty_rounded,
              title: '준비 중인 탭입니다',
              subtitle: '곧 새로운 기록 기능을 제공할게요',
            ),
        ],
      ),
    );
  }

  void _setTab(int index) {
    setState(() {
      _tabIndex = index;
    });
  }

  Future<void> _openAddSchool() async {
    final record = await showModalBottomSheet<_SchoolRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => const _AddSchoolSheet(),
    );
    if (record == null) {
      return;
    }
    setState(() {
      _schools.insert(0, record);
    });
  }
}

class _SchoolHeader extends StatelessWidget {
  const _SchoolHeader({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          const Icon(Icons.school_rounded, color: Color(0xFF3A8DFF)),
          const SizedBox(width: 8),
          const Text(
            '다닌 학교들',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF3A8DFF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: const [
                  Icon(Icons.add, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    '추가',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordTab extends StatelessWidget {
  const _RecordTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFFFF7A3D) : const Color(0xFF8A8A8A);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFFF0E6) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
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
      padding: const EdgeInsets.all(18),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFFF7A3D)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddSchoolSheet extends StatefulWidget {
  const _AddSchoolSheet();

  @override
  State<_AddSchoolSheet> createState() => _AddSchoolSheetState();
}

class _AddSchoolSheetState extends State<_AddSchoolSheet> {
  _SchoolLevel _level = _SchoolLevel.elementary;
  _ProvinceOption? _province;
  String? _districtSelected;
  String? _dongSelected;
  bool _loadingDistricts = false;
  bool _loadingDongs = false;
  List<String> _districtOptions = [];
  List<String> _dongOptions = [];
  String? _regionError;
  List<Map<String, dynamic>>? _allRegionRowsCache;
  final _schoolController = TextEditingController();
  final _majorController = TextEditingController();
  int _grade = 1;
  int _classNumber = 1;

  static const String _dataGoServiceKey = String.fromEnvironment(
    'DATA_GO_SERVICE_KEY',
    defaultValue:
        '47b77db0f3002b862acb7482d8e2853e94d0e7df70e9fe11ef5cb37c7a36ccd6',
  );

  static const _provinces = [
    _ProvinceOption('서울', '서울특별시'),
    _ProvinceOption('경기도', '경기도'),
    _ProvinceOption('강원도', '강원특별자치도'),
    _ProvinceOption('충청북도', '충청북도'),
    _ProvinceOption('충청남도', '충청남도'),
    _ProvinceOption('전라북도', '전북특별자치도'),
    _ProvinceOption('전라남도', '전라남도'),
    _ProvinceOption('경상북도', '경상북도'),
    _ProvinceOption('경상남도', '경상남도'),
    _ProvinceOption('부산', '부산광역시'),
    _ProvinceOption('대구', '대구광역시'),
    _ProvinceOption('인천', '인천광역시'),
    _ProvinceOption('광주', '광주광역시'),
    _ProvinceOption('대전', '대전광역시'),
    _ProvinceOption('울산', '울산광역시'),
    _ProvinceOption('세종', '세종특별자치시'),
    _ProvinceOption('제주', '제주특별자치도'),
  ];

  @override
  void dispose() {
    _schoolController.dispose();
    _majorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isElementary = _level == _SchoolLevel.elementary;
    final isMiddle = _level == _SchoolLevel.middle;
    final isUniversity = _level == _SchoolLevel.university;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '학교 추가',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: '학교 종류',
              child: DropdownButtonFormField<_SchoolLevel>(
                value: _level,
                items: _SchoolLevel.values
                    .map(
                      (level) => DropdownMenuItem(
                        value: level,
                        child: Text(level.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _level = value;
                  });
                },
                decoration: _fieldDecoration('학교 종류 선택'),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '지역',
              child: Column(
                children: [
                  DropdownButtonFormField<_ProvinceOption>(
                    value: _province,
                    items: _provinces
                        .map(
                          (province) => DropdownMenuItem(
                            value: province,
                            child: Text(province.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _province = value;
                        _districtSelected = null;
                        _dongSelected = null;
                        _districtOptions = [];
                        _dongOptions = [];
                        _regionError = null;
                      });
                      if (value != null) {
                        _loadDistricts(value.apiName);
                      }
                    },
                    decoration: _fieldDecoration('시/도 선택'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _districtSelected,
                    items: _districtOptions
                        .map(
                          (district) => DropdownMenuItem(
                            value: district,
                            child: Text(district),
                          ),
                        )
                        .toList(),
                    onChanged: _loadingDistricts
                        ? null
                        : (value) {
                            setState(() {
                              _districtSelected = value;
                              _dongSelected = null;
                              _dongOptions = [];
                              _regionError = null;
                            });
                            final province = _province;
                            if (province != null && value != null) {
                              _loadDongs(province.apiName, value);
                            }
                          },
                    decoration: _fieldDecoration(
                      _loadingDistricts ? '시/군/구 불러오는 중...' : '시/군/구 선택',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: _dongSelected,
                    items: _dongOptions
                        .map(
                          (dong) => DropdownMenuItem(
                            value: dong,
                            child: Text(dong),
                          ),
                        )
                        .toList(),
                    onChanged: _loadingDongs
                        ? null
                        : (value) {
                            setState(() {
                              _dongSelected = value;
                              _regionError = null;
                            });
                          },
                    decoration: _fieldDecoration(
                      _loadingDongs ? '동/읍/면 불러오는 중...' : '동/읍/면 선택',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _RegionStatus(
                    districts: _districtOptions.length,
                    dongs: _dongOptions.length,
                    loadingDistricts: _loadingDistricts,
                    loadingDongs: _loadingDongs,
                    error: _regionError,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: _schoolInfoTitle,
              child: Column(
                children: [
                  TextField(
                    controller: _schoolController,
                    decoration: _fieldDecoration(_schoolNameHint),
                  ),
                  if (isElementary || isMiddle) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _NumberPickerField(
                            label: '학년',
                            value: _grade,
                            max: isElementary ? 6 : 3,
                            onChanged: (value) {
                              setState(() {
                                _grade = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _NumberPickerField(
                            label: '반',
                            value: _classNumber,
                            max: 20,
                            onChanged: (value) {
                              setState(() {
                                _classNumber = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (isUniversity) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _majorController,
                      decoration: _fieldDecoration('학과 입력'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6A3D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '저장하기',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_province == null ||
        _districtSelected == null ||
        _dongSelected == null ||
        _schoolController.text.trim().isEmpty) {
      _showError('학교 종류와 지역, 학교 이름을 입력해주세요.');
      return;
    }
    if ((_level == _SchoolLevel.elementary || _level == _SchoolLevel.middle) &&
        (_grade <= 0 || _classNumber <= 0)) {
      _showError('학년과 반을 선택해주세요.');
      return;
    }
    if (_level == _SchoolLevel.university &&
        _majorController.text.trim().isEmpty) {
      _showError('학과를 입력해주세요.');
      return;
    }

    Navigator.of(context).pop(
      _SchoolRecord(
        level: _level,
        province: _province!.label,
        district: _districtSelected ?? '',
        dong: _dongSelected ?? '',
        name: _schoolController.text.trim(),
        grade: _level == _SchoolLevel.elementary || _level == _SchoolLevel.middle
            ? _grade
            : null,
        classNumber:
            _level == _SchoolLevel.elementary || _level == _SchoolLevel.middle
                ? _classNumber
                : null,
        major: _level == _SchoolLevel.university
            ? _majorController.text.trim()
            : null,
      ),
    );
  }

  Future<void> _loadDistricts(String province) async {
    setState(() {
      _loadingDistricts = true;
    });
    try {
      var rows = await _fetchRegionRows(province);
      if (rows.isEmpty) {
        rows = await _fetchAllRows();
      }
      final districts = rows
          .map((row) => _extractDistrict(row, province))
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();
      if (!mounted) {
        return;
      }
      setState(() {
        _districtOptions = districts;
        if (districts.isEmpty) {
          _regionError = '시/군/구 결과가 없습니다. ($province)';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _regionError = '시/군/구 목록을 불러오지 못했습니다. (${e.toString().replaceAll('Exception: ', '')})';
        });
        _showError(_regionError!);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingDistricts = false;
        });
      }
    }
  }

  Future<void> _loadDongs(String province, String district) async {
    setState(() {
      _loadingDongs = true;
    });
    try {
      final query = '$province $district';
      var rows = await _fetchRegionRows(query);
      if (rows.isEmpty) {
        rows = await _fetchAllRows();
      }
      final dongs = rows
          .map((row) => _extractDong(row, query))
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();
      if (!mounted) {
        return;
      }
      setState(() {
        _dongOptions = dongs;
        if (dongs.isEmpty) {
          _regionError = '동/읍/면 결과가 없습니다. ($query)';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _regionError = '동/읍/면 목록을 불러오지 못했습니다. (${e.toString().replaceAll('Exception: ', '')})';
        });
        _showError(_regionError!);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingDongs = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRegionRows(String query) async {
    if (_dataGoServiceKey.isEmpty) {
      throw Exception('ServiceKey missing');
    }
    final uri = Uri.parse(
      'https://apis.data.go.kr/1741000/StanReginCd/getStanReginCdList',
    ).replace(
      queryParameters: {
        'ServiceKey': _dataGoServiceKey,
        'serviceKey': _dataGoServiceKey,
        'pageNo': '1',
        'numOfRows': '10000',
        'type': 'json',
        'locatadd_nm': query,
      },
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final apiError = _extractApiError(decoded);
    if (apiError != null) {
      throw Exception(apiError);
    }
    return _extractRows(decoded);
  }

  Future<List<Map<String, dynamic>>> _fetchAllRows() async {
    final cached = _allRegionRowsCache;
    if (cached != null) {
      return cached;
    }
    final allRows = <Map<String, dynamic>>[];
    var page = 1;
    const pageSize = 1000;
    while (page <= 60) {
      final uri = Uri.parse(
        'https://apis.data.go.kr/1741000/StanReginCd/getStanReginCdList',
      ).replace(
        queryParameters: {
          'ServiceKey': _dataGoServiceKey,
          'serviceKey': _dataGoServiceKey,
          'pageNo': '$page',
          'numOfRows': '$pageSize',
          'type': 'json',
        },
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        break;
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final apiError = _extractApiError(decoded);
      if (apiError != null) {
        throw Exception(apiError);
      }
      final rows = _extractRows(decoded);
      if (rows.isEmpty) {
        break;
      }
      allRows.addAll(rows);
      if (rows.length < pageSize) {
        break;
      }
      page += 1;
    }
    _allRegionRowsCache = allRows;
    return allRows;
  }

  List<Map<String, dynamic>> _extractRows(dynamic decoded) {
    if (decoded is! Map) {
      return [];
    }
    final root = decoded['StanReginCd'];
    if (root is List) {
      for (final item in root) {
        if (item is Map && item['row'] is List) {
          return (item['row'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      return [];
    }
    if (root is Map && root['row'] is List) {
      return (root['row'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  String? _extractApiError(dynamic decoded) {
    if (decoded is! Map) {
      return null;
    }
    final root = decoded['StanReginCd'];
    if (root is List) {
      for (final item in root) {
        final error = _extractApiErrorFromItem(item);
        if (error != null) {
          return error;
        }
      }
      return null;
    }
    if (root is Map) {
      return _extractApiErrorFromItem(root);
    }
    return null;
  }

  String? _extractApiErrorFromItem(Map item) {
    if (item['head'] is! List) {
      return null;
    }
    final head = item['head'] as List;
    if (head.isEmpty || head.first is! Map) {
      return null;
    }
    final map = head.first as Map;
    final resultCode = map['RESULT']?['CODE'] ?? map['resultCode'];
    final resultMsg = map['RESULT']?['MESSAGE'] ?? map['resultMsg'];
    if (resultCode != null && resultCode.toString() != '00') {
      return 'API 오류: $resultMsg ($resultCode)';
    }
    return null;
  }

  String? _extractDistrict(Map<String, dynamic> row, String province) {
    final full = row['locatadd_nm'];
    if (full is! String) {
      return null;
    }
    if (!full.startsWith(province)) {
      return null;
    }
    final parts = full.split(' ');
    if (parts.length < 2) {
      return null;
    }
    return parts[1].trim().isEmpty ? null : parts[1].trim();
  }

  String? _extractDong(Map<String, dynamic> row, String prefix) {
    final full = row['locatadd_nm'];
    if (full is! String) {
      return null;
    }
    if (!full.startsWith(prefix)) {
      return null;
    }
    final parts = full.split(' ');
    if (parts.length < 3) {
      return null;
    }
    return parts[2].trim().isEmpty ? null : parts[2].trim();
  }

  String get _schoolInfoTitle {
    switch (_level) {
      case _SchoolLevel.kindergarten:
        return '유치원 정보';
      case _SchoolLevel.elementary:
        return '초등학교 정보';
      case _SchoolLevel.middle:
        return '중학교 정보';
      case _SchoolLevel.university:
        return '대학교 정보';
    }
  }

  String get _schoolNameHint {
    switch (_level) {
      case _SchoolLevel.kindergarten:
        return '유치원 이름 입력';
      case _SchoolLevel.elementary:
        return '초등학교 이름 입력';
      case _SchoolLevel.middle:
        return '중학교 이름 입력';
      case _SchoolLevel.university:
        return '대학교 이름 입력';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE7E2F5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE7E2F5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFBFA7FF), width: 1.2),
      ),
    );
  }
}

class _NumberPickerField extends StatelessWidget {
  const _NumberPickerField({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE7E2F5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE7E2F5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBFA7FF), width: 1.2),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isDense: true,
          isExpanded: true,
          items: List.generate(
            max,
            (index) => DropdownMenuItem(
              value: index + 1,
              child: Text('${index + 1}'),
            ),
          ),
          onChanged: (next) {
            if (next == null) {
              return;
            }
            onChanged(next);
          },
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0EAFB)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F1650).withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6D5F9B),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _RegionStatus extends StatelessWidget {
  const _RegionStatus({
    required this.districts,
    required this.dongs,
    required this.loadingDistricts,
    required this.loadingDongs,
    required this.error,
  });

  final int districts;
  final int dongs;
  final bool loadingDistricts;
  final bool loadingDongs;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final status = error ??
        '시/군/구 $districts개, 동/읍/면 $dongs개'
            '${loadingDistricts ? ' · 시/군/구 로딩중' : ''}'
            '${loadingDongs ? ' · 동/읍/면 로딩중' : ''}';
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          color: error == null ? const Color(0xFF9B9B9B) : const Color(0xFFE53935),
          fontWeight: error == null ? FontWeight.w500 : FontWeight.w700,
        ),
      ),
    );
  }
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({required this.record});

  final _SchoolRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: record.level.tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(record.level.icon, color: record.level.iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A8A8A),
                  ),
                ),
                if (record.footer.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    record.footer,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF3A8DFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.edit_rounded, color: Color(0xFFBDBDBD)),
        ],
      ),
    );
  }
}

enum _SchoolLevel {
  kindergarten('유치원', Icons.emoji_people_rounded, Color(0xFFE8F7FF), Color(0xFF2C6BFF)),
  elementary('초등학교', Icons.school_rounded, Color(0xFFEFF7FF), Color(0xFF3A8DFF)),
  middle('중학교', Icons.menu_book_rounded, Color(0xFFEAFBF1), Color(0xFF22C55E)),
  university('대학교', Icons.workspace_premium_rounded, Color(0xFFFFF3E9), Color(0xFFFF7A3D));

  const _SchoolLevel(this.label, this.icon, this.tint, this.iconColor);

  final String label;
  final IconData icon;
  final Color tint;
  final Color iconColor;
}

class _SchoolRecord {
  _SchoolRecord({
    required this.level,
    required this.province,
    required this.district,
    required this.dong,
    required this.name,
    this.grade,
    this.classNumber,
    this.major,
  });

  final _SchoolLevel level;
  final String province;
  final String district;
  final String dong;
  final String name;
  final int? grade;
  final int? classNumber;
  final String? major;

  String get locationLabel {
    final parts = [province, district, dong].where((value) => value.isNotEmpty);
    return parts.join(' ');
  }

  String get subtitle {
    final location = locationLabel;
    if (location.isEmpty) {
      return level.label;
    }
    return '$location · ${level.label}';
  }

  String get footer {
    if (level == _SchoolLevel.university) {
      return major ?? '';
    }
    if (grade != null && classNumber != null) {
      return '$grade학년 $classNumber반';
    }
    return '';
  }
}

class _ProvinceOption {
  const _ProvinceOption(this.label, this.apiName);

  final String label;
  final String apiName;
}
