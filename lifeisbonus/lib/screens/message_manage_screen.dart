import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MessageManageScreen extends StatelessWidget {
  const MessageManageScreen({super.key, required this.userDocId});

  final String userDocId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('차단/신고 관리'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '차단'),
              Tab(text: '신고'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _BlockList(userDocId: userDocId),
            _ReportList(userDocId: userDocId),
          ],
        ),
      ),
    );
  }
}

class _BlockList extends StatelessWidget {
  const _BlockList({required this.userDocId});

  final String userDocId;

  String _buildThreadId(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('__');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .collection('blocks')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.block,
            title: '차단한 사용자가 없어요',
            subtitle: '차단하면 여기에서 관리할 수 있어요',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final targetId = doc.id;
            return _ManageCard(
              title: targetId,
              subtitle: '차단됨',
              actionLabel: '차단 해제',
              onAction: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userDocId)
                    .collection('blocks')
                    .doc(targetId)
                    .delete();
                final threadId = _buildThreadId(userDocId, targetId);
                await FirebaseFirestore.instance
                    .collection('threads')
                    .doc(threadId)
                    .set({
                  'hiddenBy.$userDocId': false,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
              },
            );
          },
        );
      },
    );
  }
}

class _ReportList extends StatelessWidget {
  const _ReportList({required this.userDocId});

  final String userDocId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .collection('reports')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.report_outlined,
            title: '신고한 사용자가 없어요',
            subtitle: '신고 내역을 여기에서 확인할 수 있어요',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final targetId = doc.data()['targetId']?.toString() ?? '알 수 없음';
            return _ManageCard(
              title: targetId,
              subtitle: '신고됨',
              actionLabel: '삭제',
              onAction: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userDocId)
                    .collection('reports')
                    .doc(doc.id)
                    .delete();
              },
            );
          },
        );
      },
    );
  }
}

class _ManageCard extends StatelessWidget {
  const _ManageCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          const Icon(Icons.person_off, color: Color(0xFF8E5BFF)),
          const SizedBox(width: 10),
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
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: const Color(0xFFBDBDBD)),
            const SizedBox(height: 10),
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
      ),
    );
  }
}
