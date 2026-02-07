import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/premium_service.dart';
import 'premium_connect_screen.dart';
import 'message_match_detail_screen.dart';
import 'message_chat_screen.dart';
import 'message_manage_screen.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  late Future<String?> _userDocIdFuture = PremiumService.resolveUserDocId();
  late Future<List<_MatchCardData>> _matchCardsFuture = _loadMatchCards();
  final Map<String, Future<_UserProfile>> _profileFutures = {};
  late Future<Set<String>> _blockedFuture = _loadBlockedUsers();

  Future<Set<String>> _loadBlockedUsers() async {
    final userDocId = await _userDocIdFuture;
    if (userDocId == null) {
      return {};
    }
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('blocks')
        .get();
    return snap.docs.map((doc) => doc.id).toSet();
  }

  Future<List<_MatchCardData>> _loadMatchCards() async {
    final userDocId = await _userDocIdFuture;
    if (userDocId == null) {
      return [];
    }
    final cards = <_MatchCardData>[];

    Future<int> countMatchesForKeys(List<String> keys, String ownerId) async {
      if (keys.isEmpty) {
        return 0;
      }
      final uniqueUsers = <String>{};
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
          final ownerIdValue = data['ownerId'] as String?;
          final parentId = doc.reference.parent.parent?.id;
          final resolvedId = ownerIdValue ?? parentId;
          if (resolvedId == null || resolvedId == ownerId) {
            continue;
          }
          uniqueUsers.add(resolvedId);
        }
      }
      return uniqueUsers.length;
    }

    try {
      final schoolSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .collection('schools')
          .orderBy('updatedAt', descending: true)
          .get();
      for (final doc in schoolSnapshot.docs) {
        final data = doc.data();
        final matchKeys = data['matchKeys'] is List
            ? (data['matchKeys'] as List)
                .map((key) => key.toString())
                .where((key) => key.isNotEmpty)
                .toList()
            : <String>[];
        if (matchKeys.isEmpty) {
          continue;
        }
        final gradeEntries = data['gradeEntries'];
        String title = data['name']?.toString() ?? '학교';
        String subtitle = '';
        if (gradeEntries is List && gradeEntries.isNotEmpty) {
          final sorted = gradeEntries
              .whereType<Map>()
              .toList()
            ..sort((a, b) =>
                (b['year'] as num? ?? 0).compareTo(a['year'] as num? ?? 0));
          final entry = sorted.first;
          final grade = entry['grade'];
          final classNumber = entry['classNumber'];
          final year = entry['year'];
          if (grade != null && classNumber != null) {
            title = '${data['name']} ${grade}학년 ${classNumber}반';
          }
          if (year != null) {
            subtitle = '$year년';
          }
        } else {
          final grade = data['grade'];
          final classNumber = data['classNumber'];
          final year = data['year'];
          if (grade != null && classNumber != null) {
            title = '${data['name']} ${grade}학년 ${classNumber}반';
          }
          if (year != null) {
            subtitle = '$year년';
          }
        }
        final count = await countMatchesForKeys(matchKeys, userDocId);
        if (count > 0) {
          cards.add(
            _MatchCardData(
              title: title,
              subtitle: subtitle,
              count: '${count}명',
              matchKeys: matchKeys,
            ),
          );
        }
      }
    } catch (_) {}

    if (cards.length > 6) {
      return cards.sublist(0, 6);
    }
    return cards;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PremiumStatus>(
      stream: PremiumService.watchStatus(),
      builder: (context, snapshot) {
        final isPremium = snapshot.data?.isPremium == true;
        return FutureBuilder<String?>(
          future: _userDocIdFuture,
          builder: (context, idSnapshot) {
            final userDocId = idSnapshot.data;
            return FutureBuilder<List<_MatchCardData>>(
              future: _matchCardsFuture,
              builder: (context, matchSnapshot) {
                final matchCards = matchSnapshot.data ?? [];
                return FutureBuilder<Set<String>>(
                  future: _blockedFuture,
                  builder: (context, blockedSnap) {
                    final blocked = blockedSnap.data ?? {};
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      child: Column(
                        children: [
                          Text(
                            '추억 연결',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF7A3D),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '같은 추억을 가진 사람들과 연결되어 보세요',
                            style:
                                TextStyle(fontSize: 12, color: Color(0xFF9B9B9B)),
                          ),
                          const SizedBox(height: 16),
                          if (!isPremium)
                            _PremiumCtaCard(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const PremiumConnectScreen(),
                                  ),
                                );
                              },
                            )
                          else
                            const _PremiumActiveInfo(),
                          const SizedBox(height: 16),
                          _ThreadSection(
                            userDocId: userDocId,
                            isPremium: isPremium,
                            profileLoader: _loadProfile,
                            blocked: blocked,
                            onOpenThread: (thread) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => MessageChatScreen(
                                    otherUserId: thread.otherUserId,
                                    otherNickname: thread.otherNickname,
                                    otherPhotoUrl: thread.otherPhotoUrl,
                                  ),
                                ),
                              );
                            },
                            onBlock: (otherId) async {
                              if (userDocId == null) {
                                return;
                              }
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userDocId)
                                  .collection('blocks')
                                  .doc(otherId)
                                  .set({
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              setState(() {
                                _blockedFuture = _loadBlockedUsers();
                              });
                            },
                            onReport: (otherId) async {
                              if (userDocId == null) {
                                return;
                              }
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userDocId)
                                  .collection('reports')
                                  .add({
                                'targetId': otherId,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                            },
                            onDeleteThread: (threadId) async {
                              if (userDocId == null) {
                                return;
                              }
                              await FirebaseFirestore.instance
                                  .collection('threads')
                                  .doc(threadId)
                                  .set({
                                'hiddenBy.$userDocId': true,
                                'updatedAt': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));
                            },
                            onTogglePin: (threadId, pinned) async {
                              if (userDocId == null) {
                                return;
                              }
                              await FirebaseFirestore.instance
                                  .collection('threads')
                                  .doc(threadId)
                                  .set({
                                'pinnedBy.$userDocId': pinned,
                                'updatedAt': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));
                            },
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: const [
                              Icon(Icons.group_rounded,
                                  color: Color(0xFFB356FF), size: 18),
                              SizedBox(width: 6),
                              Text(
                                '나와 매칭되는 사람들',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (matchCards.isEmpty)
                            const _EmptyHint(
                              icon: Icons.search_off_rounded,
                              title: '아직 매칭된 사람이 없어요',
                              subtitle: '학교/동네/계획 기록을 더 추가해보세요',
                            )
                          else
                            ...matchCards
                                .map(
                                  (card) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _MatchCard(
                                      title: card.title,
                                      subtitle: card.subtitle,
                                      count: card.count,
                                      blur: !isPremium,
                                      onTapCount: () async {
                                        if (!isPremium) {
                                          if (!context.mounted) {
                                            return;
                                          }
                                          final goPremium =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('프리미엄 필요'),
                                              content: const Text(
                                                  '매칭된 사람 목록을 보려면 프리미엄이 필요해요.'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(false),
                                                  child: const Text('닫기'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(true),
                                                  child: const Text('프리미엄 보기'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (goPremium == true &&
                                              context.mounted) {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const PremiumConnectScreen(),
                                              ),
                                            );
                                          }
                                          return;
                                        }
                                        if (!context.mounted) {
                                          return;
                                        }
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                MessageMatchDetailScreen(
                                              title: card.title,
                                              subtitle: card.subtitle,
                                              matchKeys: card.matchKeys,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                )
                                .toList(),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<_UserProfile> _loadProfile(String userId) {
    return _profileFutures.putIfAbsent(userId, () async {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final data = doc.data();
      return _UserProfile(
        id: userId,
        nickname: (data?['displayName'] as String?)?.trim().isNotEmpty == true
            ? (data?['displayName'] as String).trim()
            : '알 수 없음',
        photoUrl: data?['photoUrl'] as String?,
        statusMessage: data?['statusMessage'] as String?,
      );
    });
  }
}

class _MatchCardData {
  const _MatchCardData({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.matchKeys,
  });

  final String title;
  final String subtitle;
  final String count;
  final List<String> matchKeys;
}

class _UserProfile {
  const _UserProfile({
    required this.id,
    required this.nickname,
    this.photoUrl,
    this.statusMessage,
  });

  final String id;
  final String nickname;
  final String? photoUrl;
  final String? statusMessage;
}

class _ThreadSection extends StatelessWidget {
  const _ThreadSection({
    required this.userDocId,
    required this.isPremium,
    required this.profileLoader,
    required this.blocked,
    required this.onOpenThread,
    required this.onDeleteThread,
    required this.onTogglePin,
    required this.onBlock,
    required this.onReport,
  });

  final String? userDocId;
  final bool isPremium;
  final Future<_UserProfile> Function(String userId) profileLoader;
  final Set<String> blocked;
  final ValueChanged<_ThreadItem> onOpenThread;
  final ValueChanged<String> onDeleteThread;
  final void Function(String threadId, bool pinned) onTogglePin;
  final ValueChanged<String> onBlock;
  final ValueChanged<String> onReport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.mail_outline,
                color: Color(0xFFFF7A3D), size: 18),
            const SizedBox(width: 6),
            const Text(
              '쪽지',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            if (userDocId != null)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('threads')
                    .where('participants', arrayContains: userDocId)
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  int totalUnread = 0;
                  for (final doc in docs) {
                    final data = doc.data();
                    totalUnread += _resolveUnreadCount(data, userDocId ?? '');
                  }
                  if (totalUnread <= 0) {
                    return const SizedBox.shrink();
                  }
                  final label = _formatCount(isPremium ? totalUnread : 1);
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (userDocId == null)
          const _EmptyHint(
            icon: Icons.lock_outline,
            title: '로그인이 필요해요',
            subtitle: '로그인 후 쪽지를 확인할 수 있어요',
          )
        else
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('threads')
                .where('participants', arrayContains: userDocId)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final threads = docs.map((doc) {
                final data = doc.data();
                final participants = (data['participants'] as List?)
                        ?.map((id) => id.toString())
                        .toList() ??
                    <String>[];
                final otherId =
                    participants.firstWhere((id) => id != userDocId, orElse: () => '');
                if (otherId.isEmpty || blocked.contains(otherId)) {
                  return null;
                }
                final hiddenBy = (data['hiddenBy'] as Map?)?.cast<String, dynamic>();
                if (hiddenBy != null && hiddenBy[userDocId] == true) {
                  return null;
                }
                final lastMessage = data['lastMessage']?.toString() ?? '';
                final lastMessageAt = data['lastMessageAt'];
                DateTime? lastAt;
                if (lastMessageAt is Timestamp) {
                  lastAt = lastMessageAt.toDate();
                } else if (lastMessageAt is String) {
                  lastAt = DateTime.tryParse(lastMessageAt);
                }
                final pinnedBy = (data['pinnedBy'] as Map?)?.cast<String, dynamic>();
                final isPinned = pinnedBy != null && pinnedBy[userDocId] == true;
                final unreadCounts = (data['unreadCounts'] as Map?)
                    ?.cast<String, dynamic>();
                final unread = unreadCounts?[userDocId];
                return _ThreadItem(
                  threadId: doc.id,
                  otherUserId: otherId,
                  lastMessage: lastMessage,
                  lastMessageAt: lastAt,
                  unreadCount: unread is num ? unread.toInt() : 0,
                  isPinned: isPinned,
                );
              }).whereType<_ThreadItem>().toList()
                ..sort((a, b) {
                  if (a.isPinned != b.isPinned) {
                    return a.isPinned ? -1 : 1;
                  }
                  return (b.lastMessageAt ?? DateTime(0))
                      .compareTo(a.lastMessageAt ?? DateTime(0));
                });
              if (threads.isEmpty) {
                return const _EmptyHint(
                  icon: Icons.mail_outline,
                  title: '아직 쪽지가 없어요',
                  subtitle: '매칭된 사람에게 쪽지를 보내보세요',
                );
              }
              final pinnedThreads =
                  threads.where((thread) => thread.isPinned).toList();
              final otherThreads =
                  threads.where((thread) => !thread.isPinned).toList();
              return Column(
                children: [
                  if (pinnedThreads.isNotEmpty)
                    _ThreadSectionHeader(
                      title: '고정된 대화',
                      onManage: userDocId == null
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => MessageManageScreen(
                                    userDocId: userDocId!,
                                  ),
                                ),
                              );
                            },
                    ),
                  if (pinnedThreads.isNotEmpty)
                    ..._buildThreadTiles(
                      context,
                      pinnedThreads,
                      isPremium,
                      profileLoader,
                      onOpenThread,
                      onTogglePin,
                      onDeleteThread,
                      onBlock,
                      onReport,
                    ),
                  if (pinnedThreads.isNotEmpty && otherThreads.isNotEmpty)
                    const SizedBox(height: 6),
                  _ThreadSectionHeader(
                    title: pinnedThreads.isNotEmpty ? '모든 대화' : '대화 목록',
                    onManage: userDocId == null
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => MessageManageScreen(
                                  userDocId: userDocId!,
                                ),
                              ),
                            );
                          },
                  ),
                  ..._buildThreadTiles(
                    context,
                    otherThreads,
                    isPremium,
                    profileLoader,
                    onOpenThread,
                    onTogglePin,
                    onDeleteThread,
                    onBlock,
                    onReport,
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

List<Widget> _buildThreadTiles(
  BuildContext context,
  List<_ThreadItem> threads,
  bool isPremium,
  Future<_UserProfile> Function(String userId) profileLoader,
  ValueChanged<_ThreadItem> onOpenThread,
  void Function(String threadId, bool pinned) onTogglePin,
  ValueChanged<String> onDeleteThread,
  ValueChanged<String> onBlock,
  ValueChanged<String> onReport,
) {
  return threads.map((thread) {
    return FutureBuilder<_UserProfile>(
      future: profileLoader(thread.otherUserId),
      builder: (context, profileSnap) {
        final profile = profileSnap.data;
        final item = thread.copyWith(
          otherNickname: profile?.nickname ?? '알 수 없음',
          otherPhotoUrl: profile?.photoUrl,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ThreadTile(
            item: item,
            isPremium: isPremium,
            onTap: () {
              if (!isPremium) {
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('프리미엄 필요'),
                    content: const Text('쪽지 내용을 보려면 프리미엄이 필요해요.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('닫기'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PremiumConnectScreen(),
                            ),
                          );
                        },
                        child: const Text('프리미엄 보기'),
                      ),
                    ],
                  ),
                );
                return;
              }
              onOpenThread(item);
            },
            onTogglePin: () => onTogglePin(item.threadId, !item.isPinned),
            onDelete: () => onDeleteThread(item.threadId),
            onBlock: () => onBlock(item.otherUserId),
            onReport: () => onReport(item.otherUserId),
          ),
        );
      },
    );
  }).toList();
}

class _ThreadItem {
  const _ThreadItem({
    required this.threadId,
    required this.otherUserId,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    this.isPinned = false,
    this.otherNickname = '알 수 없음',
    this.otherPhotoUrl,
  });

  final String threadId;
  final String otherUserId;
  final String otherNickname;
  final String? otherPhotoUrl;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isPinned;

  _ThreadItem copyWith({
    String? otherNickname,
    String? otherPhotoUrl,
    bool? isPinned,
  }) {
    return _ThreadItem(
      threadId: threadId,
      otherUserId: otherUserId,
      otherNickname: otherNickname ?? this.otherNickname,
      otherPhotoUrl: otherPhotoUrl ?? this.otherPhotoUrl,
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt,
      unreadCount: unreadCount,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.item,
    required this.isPremium,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
    required this.onBlock,
    required this.onReport,
  });

  final _ThreadItem item;
  final bool isPremium;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;
  final VoidCallback onBlock;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final unread = item.unreadCount;
    final badgeLabel = _formatCount(isPremium ? unread : 1);
    final showBadge = unread > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFF1E9FF),
              backgroundImage:
                  item.otherPhotoUrl == null || item.otherPhotoUrl!.isEmpty
                      ? null
                      : NetworkImage(item.otherPhotoUrl!),
              child: item.otherPhotoUrl == null || item.otherPhotoUrl!.isEmpty
                  ? const Icon(Icons.person, color: Color(0xFF8E5BFF))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.otherNickname,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPremium ? item.lastMessage : '프리미엄 가입 후 확인할 수 있어요',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
                  ),
                ],
              ),
            ),
            if (showBadge)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            PopupMenuButton<_ThreadAction>(
              onSelected: (action) {
                switch (action) {
                  case _ThreadAction.pin:
                    onTogglePin();
                    break;
                  case _ThreadAction.delete:
                    onDelete();
                    break;
                  case _ThreadAction.block:
                    onBlock();
                    break;
                  case _ThreadAction.report:
                    onReport();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _ThreadAction.pin,
                  child: Text(item.isPinned ? '고정 해제' : '상단 고정'),
                ),
                const PopupMenuItem(
                  value: _ThreadAction.delete,
                  child: Text('대화 삭제'),
                ),
                const PopupMenuItem(
                  value: _ThreadAction.block,
                  child: Text('차단'),
                ),
                const PopupMenuItem(
                  value: _ThreadAction.report,
                  child: Text('신고'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ThreadAction { pin, delete, block, report }

String _formatCount(int count) {
  if (count <= 0) {
    return '';
  }
  if (count >= 100) {
    return '99+';
  }
  return count.toString();
}

int _resolveUnreadCount(Map<String, dynamic> data, String userId) {
  final unreadCounts =
      (data['unreadCounts'] as Map?)?.cast<String, dynamic>();
  final direct = unreadCounts?[userId];
  if (direct is num) {
    return direct.toInt();
  }
  final fallback = data['unreadCounts.$userId'];
  if (fallback is num) {
    return fallback.toInt();
  }
  return 0;
}

class _ThreadSectionHeader extends StatelessWidget {
  const _ThreadSectionHeader({required this.title, this.onManage});

  final String title;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const Spacer(),
          if (onManage != null)
            TextButton(
              onPressed: onManage,
              child: const Text(
                '관리',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _PremiumCtaCard extends StatelessWidget {
  const _PremiumCtaCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E6FF),
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
          const Icon(Icons.emoji_events_rounded,
              color: Color(0xFFF4B740), size: 36),
          const SizedBox(height: 10),
          const Text(
            '프리미엄으로 업그레이드',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '같은 추억을 가진 사람들과 연결되고 쪽지를 주고받아보세요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF7A7A7A)),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB356FF), Color(0xFFFF4FA6)],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '월 9,900원으로 시작하기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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

class _PremiumActiveInfo extends StatelessWidget {
  const _PremiumActiveInfo();

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

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.title,
    required this.subtitle,
    required this.count,
    this.blur = false,
    this.onTapCount,
  });

  final String title;
  final String subtitle;
  final String count;
  final bool blur;
  final VoidCallback? onTapCount;

  @override
  Widget build(BuildContext context) {
    final card = Container(
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
                child: const Icon(Icons.school_rounded,
                    color: Color(0xFF8E5BFF), size: 16),
              ),
              const SizedBox(width: 8),
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
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9B9B9B),
                      ),
                    ),
                  ],
                ),
              ),
              if (!blur)
                _CountBadge(
                  count: count,
                  onTap: onTapCount,
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: const [
              Icon(Icons.emoji_events_rounded,
                  color: Color(0xFFF4B740), size: 18),
              SizedBox(width: 6),
              Text(
                '프리미엄으로 확인하기',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(Icons.person_outline, size: 16, color: Color(0xFFBDBDBD)),
              SizedBox(width: 6),
              Text(
                '추억연결: 우리 반이었나요',
                style: TextStyle(fontSize: 12, color: Color(0xFFBDBDBD)),
              ),
            ],
          ),
        ],
      ),
    );

    if (!blur) {
      return card;
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: card,
          ),
        ),
        Positioned(
          right: 16,
          top: 16,
          child: _CountBadge(
            count: count,
            onTap: onTapCount,
          ),
        ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, this.onTap});

  final String count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF1FF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          count,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF3A8DFF),
            fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFBDBDBD)),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
          ),
        ],
      ),
    );
  }
}
