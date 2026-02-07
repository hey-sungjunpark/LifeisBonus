import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/premium_service.dart';
import 'message_chat_screen.dart';

class MessageMatchDetailScreen extends StatefulWidget {
  const MessageMatchDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.matchKeys,
  });

  final String title;
  final String subtitle;
  final List<String> matchKeys;

  @override
  State<MessageMatchDetailScreen> createState() =>
      _MessageMatchDetailScreenState();
}

class _MessageMatchDetailScreenState extends State<MessageMatchDetailScreen> {
  late Future<List<_MatchedUser>> _usersFuture = _loadMatchedUsers();
  List<_MatchedUser> _cachedUsers = [];
  final TextEditingController _searchController = TextEditingController();
  _MatchSortOption _sortOption = _MatchSortOption.recentYear;
  String _yearFilter = '전체';
  int _visibleCount = 10;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<_MatchedUser>> _loadMatchedUsers() async {
    final userDocId = await PremiumService.resolveUserDocId();
    if (userDocId == null) {
      return [];
    }
    final uniqueUsers = <String, _MatchedUser>{};
    final keys = widget.matchKeys.where((key) => key.isNotEmpty).toList();
    for (var i = 0; i < keys.length; i += 10) {
      final batch = keys.sublist(
        i,
        i + 10 > keys.length ? keys.length : i + 10,
      );
      final snap = await FirebaseFirestore.instance
          .collectionGroup('schools')
          .where('matchKeys', arrayContainsAny: batch)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final ownerId = data['ownerId'] as String?;
        final parentId = doc.reference.parent.parent?.id;
        final resolvedId = ownerId ?? parentId;
        if (resolvedId == null || resolvedId == userDocId) {
          continue;
        }
        final matchedKey = _findMatchedKey(
          data['matchKeys'],
          widget.matchKeys,
        );
        if (matchedKey == null) {
          continue;
        }
        final info = _parseMatchKey(matchedKey);
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(resolvedId).get();
        final nickname = userDoc.data()?['displayName'] as String?;
        final photoUrl = userDoc.data()?['photoUrl'] as String?;
        final statusMessage = userDoc.data()?['statusMessage'] as String?;
        final lastActiveValue = userDoc.data()?['lastActiveAt'];
        DateTime? lastActiveAt;
        if (lastActiveValue is Timestamp) {
          lastActiveAt = lastActiveValue.toDate();
        } else if (lastActiveValue is String) {
          lastActiveAt = DateTime.tryParse(lastActiveValue);
        }
        uniqueUsers[resolvedId] = _MatchedUser(
          id: resolvedId,
          nickname: nickname?.trim().isNotEmpty == true ? nickname!.trim() : '알 수 없음',
          matchTitle: info.title,
          matchSubtitle: info.subtitle,
          photoUrl: photoUrl,
          statusMessage: statusMessage,
          lastActiveAt: lastActiveAt,
        );
      }
    }
    final users = uniqueUsers.values.toList()
      ..sort((a, b) => a.nickname.compareTo(b.nickname));
    _cachedUsers = users;
    return users;
  }

  String? _findMatchedKey(dynamic keysField, List<String> myKeys) {
    final mySet = myKeys.toSet();
    if (keysField is List) {
      for (final key in keysField) {
        final value = key?.toString();
        if (value != null && mySet.contains(value)) {
          return value;
        }
      }
    }
    return null;
  }

  _MatchKeyInfo _parseMatchKey(String key) {
    final parts = key.split('|');
    if (parts.length < 7) {
      return _MatchKeyInfo(title: widget.title, subtitle: widget.subtitle);
    }
    final schoolName = parts[1];
    final year = parts[5];
    final grade = parts[6];
    final classNumber = parts.length > 7 ? parts[7] : '';
    final title = classNumber.isNotEmpty
        ? '$schoolName ${grade}학년 ${classNumber}반'
        : '$schoolName ${grade}학년';
    final subtitle = '$year년';
    return _MatchKeyInfo(title: title, subtitle: subtitle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('매칭된 사람들'),
      ),
      body: FutureBuilder<List<_MatchedUser>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          final users = snapshot.data ?? [];
          final years = users
              .map((user) => user.matchYear)
              .whereType<int>()
              .toSet()
              .toList()
            ..sort((a, b) => b.compareTo(a));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (users.isEmpty) {
            return const Center(
              child: Text('매칭된 사용자가 없어요.'),
            );
          }
          final query = _searchController.text.trim();
          final filtered = users.where((user) {
            final matchesYear = _yearFilter == '전체' ||
                (user.matchYear?.toString() == _yearFilter);
            final matchesQuery = query.isEmpty ||
                user.nickname.toLowerCase().contains(query.toLowerCase());
            return matchesYear && matchesQuery;
          }).toList();
          _sortUsers(filtered);
          final visibleUsers = filtered.take(_visibleCount).toList();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: visibleUsers.length + 2,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _MatchFilterBar(
                  years: years,
                  selectedYear: _yearFilter,
                  sortOption: _sortOption,
                  searchController: _searchController,
                  onYearChanged: (value) {
                    setState(() {
                      _yearFilter = value;
                      _visibleCount = 10;
                    });
                  },
                  onSortChanged: (value) {
                    setState(() {
                      _sortOption = value;
                    });
                  },
                  onSearchChanged: (_) => setState(() {}),
                );
              }
              final listIndex = index - 1;
              if (listIndex < visibleUsers.length) {
                final user = visibleUsers[listIndex];
              return _MatchedUserCard(
                user: user,
                onSendMessage: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => MessageChatScreen(
                        otherUserId: user.id,
                        otherNickname: user.nickname,
                        otherPhotoUrl: user.photoUrl,
                      ),
                    ),
                  );
                },
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => MatchProfileDetailScreen(user: user),
                      ),
                    );
                  },
                );
              }
              final hasMore = filtered.length > visibleUsers.length;
              if (!hasMore) {
                return const SizedBox.shrink();
              }
              return _LoadMoreButton(
                remaining: filtered.length - visibleUsers.length,
                onTap: () {
                  setState(() {
                    _visibleCount += 10;
                  });
                },
              );
            },
          );
        },
      ),
    );
  }

  void _sortUsers(List<_MatchedUser> users) {
    switch (_sortOption) {
      case _MatchSortOption.recentYear:
        users.sort((a, b) => (b.matchYear ?? 0).compareTo(a.matchYear ?? 0));
        break;
      case _MatchSortOption.nickname:
        users.sort((a, b) => a.nickname.compareTo(b.nickname));
        break;
    }
  }
}

class _MatchedUser {
  const _MatchedUser({
    required this.id,
    required this.nickname,
    required this.matchTitle,
    required this.matchSubtitle,
    this.photoUrl,
    this.statusMessage,
    this.lastActiveAt,
  });

  final String id;
  final String nickname;
  final String matchTitle;
  final String matchSubtitle;
  final String? photoUrl;
  final String? statusMessage;
  final DateTime? lastActiveAt;

  int? get matchYear {
    final digits = matchSubtitle.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }
}

class _MatchKeyInfo {
  const _MatchKeyInfo({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;
}

class _MatchedUserCard extends StatelessWidget {
  const _MatchedUserCard({
    required this.user,
    this.onTap,
    this.onSendMessage,
  });

  final _MatchedUser user;
  final VoidCallback? onTap;
  final VoidCallback? onSendMessage;

  @override
  Widget build(BuildContext context) {
    final status = user.statusMessage?.trim();
    final lastActive = user.lastActiveAt;
    final activeLabel = lastActive == null
        ? null
        : '${lastActive.year}.${lastActive.month.toString().padLeft(2, '0')}.${lastActive.day.toString().padLeft(2, '0')} 활동';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ProfileAvatar(photoUrl: user.photoUrl),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    user.nickname,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              user.matchTitle,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              user.matchSubtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
            ),
            if (status != null && status.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                status,
                style: const TextStyle(fontSize: 11, color: Color(0xFF7A7A7A)),
              ),
            ],
            if (activeLabel != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    activeLabel,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF9B9B9B)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSendMessage,
                icon: const Icon(Icons.mail_outline),
                label: const Text('쪽지 보내기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8E5BFF),
                  side: const BorderSide(color: Color(0xFF8E5BFF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: const Color(0xFFF1E9FF),
        backgroundImage: NetworkImage(photoUrl!),
      );
    }
    return const CircleAvatar(
      radius: 18,
      backgroundColor: Color(0xFFF1E9FF),
      child: Icon(Icons.person, color: Color(0xFF8E5BFF)),
    );
  }
}

enum _MatchSortOption { recentYear, nickname }

class _MatchFilterBar extends StatelessWidget {
  const _MatchFilterBar({
    required this.years,
    required this.selectedYear,
    required this.sortOption,
    required this.searchController,
    required this.onYearChanged,
    required this.onSortChanged,
    required this.onSearchChanged,
  });

  final List<int> years;
  final String selectedYear;
  final _MatchSortOption sortOption;
  final TextEditingController searchController;
  final ValueChanged<String> onYearChanged;
  final ValueChanged<_MatchSortOption> onSortChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: '닉네임 검색',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            DropdownButton<_MatchSortOption>(
              value: sortOption,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: _MatchSortOption.recentYear,
                  child: Text('최근연도'),
                ),
                DropdownMenuItem(
                  value: _MatchSortOption.nickname,
                  child: Text('닉네임순'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  onSortChanged(value);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _YearChip(
                label: '전체',
                selected: selectedYear == '전체',
                onTap: () => onYearChanged('전체'),
              ),
              for (final year in years) ...[
                const SizedBox(width: 8),
                _YearChip(
                  label: year.toString(),
                  selected: selectedYear == year.toString(),
                  onTap: () => onYearChanged(year.toString()),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _YearChip extends StatelessWidget {
  const _YearChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF8E5BFF) : const Color(0xFFF3E6FF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF8E5BFF),
          ),
        ),
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.remaining, required this.onTap});

  final int remaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF3E6FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '더 보기 (+$remaining)',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8E5BFF),
          ),
        ),
      ),
    );
  }
}

class MatchProfileDetailScreen extends StatelessWidget {
  const MatchProfileDetailScreen({super.key, required this.user});

  final _MatchedUser user;

  @override
  Widget build(BuildContext context) {
    final status = user.statusMessage?.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('프로필 상세')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  _ProfileAvatar(photoUrl: user.photoUrl),
                  const SizedBox(height: 10),
                  Text(
                    user.nickname,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (status != null && status.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      status,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF7A7A7A)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '매칭 정보',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F7FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.matchTitle,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.matchSubtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MessageChatScreen(
                      otherUserId: user.id,
                      otherNickname: user.nickname,
                      otherPhotoUrl: user.photoUrl,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.mail_outline),
              label: const Text('쪽지 보내기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8E5BFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
