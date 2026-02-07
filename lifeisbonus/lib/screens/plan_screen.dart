import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final List<_PlanRecord> _plans = [];
  bool _loading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcomingCount =
        _plans.where((plan) => !plan.endDate.isBefore(today)).length.toString();
    final pastCount =
        _plans.where((plan) => plan.endDate.isBefore(today)).length.toString();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          Text(
            '나의 계획',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFF7A3D),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '남은 보너스 시간을 어떻게 보낼지 계획해보세요',
            style: TextStyle(fontSize: 12, color: Color(0xFF9B9B9B)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FF),
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
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0D9FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFF8E5BFF),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '새로운 계획 세우기',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '52년의 보너스 시간이 남았습니다',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7A7A7A),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _openAddPlan,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          ),
          const SizedBox(height: 14),
          if (_loading)
            const _EmptyHint(
              icon: Icons.hourglass_bottom_rounded,
              title: '계획을 불러오는 중이에요',
              subtitle: '잠시만 기다려주세요',
            )
          else if (_loadError != null)
            _EmptyHint(
              icon: Icons.error_outline_rounded,
              title: '계획을 불러오지 못했어요',
              subtitle: _loadError!,
            )
          else if (_plans.isEmpty)
            const _EmptyHint(
              icon: Icons.flag_rounded,
              title: '아직 추가한 계획이 없어요',
              subtitle: '새로운 계획을 추가해보세요',
            )
          else
            ..._plans
                .map(
                  (plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _PlanCard(
                      category: plan.category,
                      year: plan.yearLabel,
                      title: plan.title,
                      location: plan.location,
                      description: plan.description,
                      dday: plan.ddayLabel,
                      accent: plan.accent,
                      highlight: plan.highlight,
                      onDetail: () => _openPlanDetail(plan),
                      onEdit: () => _openEditPlan(plan),
                    ),
                  ),
                )
                .toList(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDFF7E8), Color(0xFFDCEEFF)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatBadge(
                  label: '미래 계획',
                  value: upcomingCount,
                  color: const Color(0xFF3DBA6E),
                ),
                _StatBadge(
                  label: '지난 계획',
                  value: pastCount,
                  color: const Color(0xFF7C6CFF),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final userDocId = await _resolveUserDocId();
      if (userDocId == null) {
        setState(() {
          _plans.clear();
          _loadError = '로그인 정보가 없어 계획을 불러올 수 없어요.';
        });
        return;
      }
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .collection('plans')
          .orderBy('endDate', descending: false)
          .get();
      final records = snapshot.docs
          .map((doc) => _PlanRecord.fromFirestore(doc.id, doc.data()))
          .whereType<_PlanRecord>()
          .toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _plans
          ..clear()
          ..addAll(records);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError =
            '계획을 불러오지 못했어요. (${e.toString().replaceAll('Exception: ', '')})';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openAddPlan() async {
    final record = await showModalBottomSheet<_PlanRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => const _AddPlanSheet(),
    );
    if (record == null) {
      return;
    }
    final saved = await _persistPlan(record);
    if (saved == null) {
      return;
    }
    setState(() {
      _plans.add(saved);
      _plans.sort((a, b) => a.endDate.compareTo(b.endDate));
    });
  }

  Future<void> _openEditPlan(_PlanRecord record) async {
    final updated = await showModalBottomSheet<_PlanRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _AddPlanSheet(initialRecord: record),
    );
    if (updated == null) {
      return;
    }
    final saved = await _persistPlan(updated);
    if (saved == null) {
      return;
    }
    setState(() {
      final index = _plans.indexWhere((plan) => plan.id == saved.id);
      if (index >= 0) {
        _plans[index] = saved;
      }
      _plans.sort((a, b) => a.endDate.compareTo(b.endDate));
    });
  }

  Future<void> _openPlanDetail(_PlanRecord record) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => _PlanDetailSheet(record: record),
    );
  }

  Future<_PlanRecord?> _persistPlan(_PlanRecord record) async {
    try {
      final userDocId = await _resolveUserDocId();
      if (userDocId == null) {
        _showSnack('로그인 정보가 없어 저장할 수 없어요.');
        return null;
      }
      final matchKey = _buildPlanMatchKey(record);
      final data = {
        'category': record.category,
        'startDate': record.startDate,
        'endDate': record.endDate,
        'title': record.title,
        'location': record.location,
        'description': record.description,
        'highlight': record.highlight,
        'matchKey': matchKey,
        'ownerId': userDocId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (record.id.isEmpty) {
        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDocId)
            .collection('plans')
            .add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return record.copyWith(id: docRef.id);
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .collection('plans')
          .doc(record.id)
          .set(data, SetOptions(merge: true));
      return record;
    } catch (e) {
      _showSnack('계획 저장에 실패했어요. (${e.toString().replaceAll('Exception: ', '')})');
      return null;
    }
  }

  String _buildPlanMatchKey(_PlanRecord record) {
    String normalize(String value) =>
        value.trim().toLowerCase().replaceAll(' ', '');
    final location = normalize(record.location);
    return '${record.startDate.year}|$location';
  }

  Future<String?> _resolveUserDocId() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString('lastProvider');
    final providerId = prefs.getString('lastProviderId');
    if (provider != null && providerId != null) {
      if (provider == 'kakao' || provider == 'naver') {
        return '$provider:$providerId';
      }
    }
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      return authUser.uid;
    }
    if (provider == null || providerId == null) {
      return null;
    }
    return providerId;
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.category,
    required this.year,
    required this.title,
    required this.location,
    required this.description,
    required this.dday,
    required this.accent,
    required this.onDetail,
    required this.onEdit,
    this.highlight = false,
  });

  final String category;
  final String year;
  final String title;
  final String location;
  final String description;
  final String dday;
  final Color accent;
  final VoidCallback onDetail;
  final VoidCallback onEdit;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEFEAFB),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.place_rounded, color: accent, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                category,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                year,
                style: const TextStyle(fontSize: 11, color: Color(0xFF8A8A8A)),
              ),
              const Spacer(),
                if (highlight)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A87),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '중요',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              if (highlight) const SizedBox(width: 8),
              GestureDetector(
                onTap: onEdit,
                child: const Icon(Icons.edit_rounded, color: Color(0xFFBDBDBD)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: Color(0xFF8A8A8A)),
              const SizedBox(width: 4),
              Text(
                location,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF7A7A7A),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                dday,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
              ),
              const Spacer(),
              _OutlineButton(label: '상세보기', accent: accent, onTap: onDetail),
              const SizedBox(width: 8),
              _FilledButton(label: '수정하기', accent: accent, onTap: onEdit),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _FilledButton extends StatelessWidget {
  const _FilledButton({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: accent,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
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
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF8A8A8A)),
        ),
      ],
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
          Icon(icon, color: const Color(0xFFBDBDBD)),
          const SizedBox(width: 10),
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
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanRecord {
  _PlanRecord({
    required this.id,
    required this.category,
    required this.startDate,
    required this.endDate,
    required this.title,
    required this.location,
    required this.description,
    required this.highlight,
  });

  final String id;
  final String category;
  final DateTime startDate;
  final DateTime endDate;
  final String title;
  final String location;
  final String description;
  final bool highlight;

  String get yearLabel =>
      '${startDate.year}년 ~ ${endDate.year}년';

  String get ddayLabel {
    final now = DateTime.now();
    final days =
        endDate.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days >= 0) {
      return 'D-$days일';
    }
    return 'D+${days.abs()}일';
  }

  Color get accent {
    switch (category) {
      case '여행':
        return const Color(0xFF7C6CFF);
      case '인생목표':
        return const Color(0xFFB356FF);
      case '커리어':
        return const Color(0xFF3A8DFF);
      case '건강':
        return const Color(0xFF3DBA6E);
      default:
        return const Color(0xFF7C6CFF);
    }
  }

  _PlanRecord copyWith({
    String? id,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    String? title,
    String? location,
    String? description,
    bool? highlight,
  }) {
    return _PlanRecord(
      id: id ?? this.id,
      category: category ?? this.category,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      title: title ?? this.title,
      location: location ?? this.location,
      description: description ?? this.description,
      highlight: highlight ?? this.highlight,
    );
  }

  static _PlanRecord? fromFirestore(String id, Map<String, dynamic> data) {
    final category = data['category'] as String?;
    final title = data['title'] as String?;
    final location = data['location'] as String?;
    final description = data['description'] as String?;
    DateTime? targetDate;
    final rawDate = data['targetDate'];
    final rawStart = data['startDate'];
    final rawEnd = data['endDate'];
    if (rawDate is Timestamp) {
      targetDate = rawDate.toDate();
    } else if (rawDate is String) {
      targetDate = DateTime.tryParse(rawDate);
    }
    DateTime? startDate;
    DateTime? endDate;
    if (rawStart is Timestamp) {
      startDate = rawStart.toDate();
    } else if (rawStart is String) {
      startDate = DateTime.tryParse(rawStart);
    }
    if (rawEnd is Timestamp) {
      endDate = rawEnd.toDate();
    } else if (rawEnd is String) {
      endDate = DateTime.tryParse(rawEnd);
    }
    if (category == null ||
        title == null ||
        location == null ||
        description == null ||
        (startDate == null && targetDate == null) ||
        (endDate == null && targetDate == null)) {
      return null;
    }
    return _PlanRecord(
      id: id,
      category: category,
      startDate: startDate ?? targetDate!,
      endDate: endDate ?? targetDate!,
      title: title,
      location: location,
      description: description,
      highlight: data['highlight'] == true,
    );
  }
}

class _AddPlanSheet extends StatefulWidget {
  const _AddPlanSheet({this.initialRecord});

  final _PlanRecord? initialRecord;

  @override
  State<_AddPlanSheet> createState() => _AddPlanSheetState();
}

class _AddPlanSheetState extends State<_AddPlanSheet> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = '여행';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _highlight = false;

  @override
  void initState() {
    super.initState();
    final record = widget.initialRecord;
    if (record != null) {
      _titleController.text = record.title;
      _locationController.text = record.location;
      _descriptionController.text = record.description;
      _category = record.category;
      _startDate = record.startDate;
      _endDate = record.endDate;
      _highlight = record.highlight;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                    '계획 추가',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  _PlanSection(
                    title: '카테고리',
                    child: DropdownButtonFormField<String>(
                      value: _category,
                      items: const [
                        DropdownMenuItem(value: '여행', child: Text('여행')),
                        DropdownMenuItem(value: '인생목표', child: Text('인생목표')),
                        DropdownMenuItem(value: '커리어', child: Text('커리어')),
                        DropdownMenuItem(value: '건강', child: Text('건강')),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _category = value;
                        });
                      },
                      decoration: _fieldDecoration('카테고리 선택'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PlanSection(
                    title: '기간',
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickDate(isStart: true),
                            child: InputDecorator(
                              decoration: _fieldDecoration('시작일자'),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(_formatDate(_startDate)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickDate(isStart: false),
                            child: InputDecorator(
                              decoration: _fieldDecoration('종료일자'),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(_formatDate(_endDate)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PlanSection(
                    title: '제목',
                    child: TextField(
                      controller: _titleController,
                      decoration: _fieldDecoration('예: 첫 번째 해외여행'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PlanSection(
                    title: '장소',
                    child: TextField(
                      controller: _locationController,
                      decoration: _fieldDecoration('예: 일본 교토'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PlanSection(
                    title: '설명',
                    child: TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: _fieldDecoration('계획에 대한 설명을 적어주세요'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PlanSection(
                    title: '강조 표시',
                    child: SwitchListTile(
                      value: _highlight,
                      onChanged: (value) {
                        setState(() {
                          _highlight = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF7C6CFF),
                      title: const Text('중요 계획으로 표시'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3A8DFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '저장하기',
                        style:
                            TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime(DateTime.now().year + 50),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  void _save() {
    if (_titleController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목, 장소, 설명을 입력해주세요.')),
      );
      return;
    }
    Navigator.of(context).pop(
      _PlanRecord(
        id: widget.initialRecord?.id ?? '',
        category: _category,
        startDate: _startDate,
        endDate: _endDate,
        title: _titleController.text.trim(),
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim(),
        highlight: _highlight,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
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
        borderSide: const BorderSide(color: Color(0xFF3A8DFF), width: 1.2),
      ),
    );
  }
}

class _PlanDetailSheet extends StatelessWidget {
  const _PlanDetailSheet({required this.record});

  final _PlanRecord record;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Text(
              record.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(record.yearLabel, style: const TextStyle(color: Color(0xFF8A8A8A))),
            const SizedBox(height: 12),
            Text(record.description),
            const SizedBox(height: 12),
            Text('장소: ${record.location}'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                record.ddayLabel,
                style: TextStyle(color: record.accent, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanSection extends StatelessWidget {
  const _PlanSection({required this.title, required this.child});

  final String title;
  final Widget child;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
