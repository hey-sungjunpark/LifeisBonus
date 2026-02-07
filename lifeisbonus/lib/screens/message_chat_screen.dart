import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/premium_service.dart';
import 'premium_connect_screen.dart';

class MessageChatScreen extends StatefulWidget {
  const MessageChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherNickname,
    this.otherPhotoUrl,
  });

  final String otherUserId;
  final String otherNickname;
  final String? otherPhotoUrl;

  @override
  State<MessageChatScreen> createState() => _MessageChatScreenState();
}

class _MessageChatScreenState extends State<MessageChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Future<String?> _userDocIdFuture = PremiumService.resolveUserDocId();
  DocumentReference<Map<String, dynamic>>? _threadRef;
  String? _userDocId;
  bool _blocked = false;

  @override
  void initState() {
    super.initState();
    _prepareThread();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _prepareThread() async {
    final userDocId = await _userDocIdFuture;
    if (!mounted || userDocId == null) {
      return;
    }
    _userDocId = userDocId;
    final blockDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('blocks')
        .doc(widget.otherUserId)
        .get();
    _blocked = blockDoc.exists;
    final threadId = _buildThreadId(userDocId, widget.otherUserId);
    final ref = FirebaseFirestore.instance.collection('threads').doc(threadId);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'participants': [userDocId, widget.otherUserId],
        'participantsKey': threadId,
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': userDocId,
        'unreadCounts': {
          userDocId: 0,
          widget.otherUserId: 0,
        },
        'lastReadAt': {
          userDocId: FieldValue.serverTimestamp(),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        'participants': FieldValue.arrayUnion([userDocId, widget.otherUserId]),
        'participantsKey': threadId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    setState(() {
      _threadRef = ref;
    });
  }

  String _buildThreadId(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('__');
  }

  Future<void> _restoreThreadVisibility() async {
    if (_userDocId == null) {
      return;
    }
    final threadId = _buildThreadId(_userDocId!, widget.otherUserId);
    await FirebaseFirestore.instance.collection('threads').doc(threadId).set({
      'hiddenBy.${_userDocId!}': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _markRead() async {
    if (_threadRef == null || _userDocId == null) {
      return;
    }
    await _threadRef!.set({
      'unreadCounts.${_userDocId!}': 0,
      'lastReadAt.${_userDocId!}': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _threadRef == null || _userDocId == null || _blocked) {
      return;
    }
    _controller.clear();
    final messageRef = _threadRef!.collection('messages').doc();
    await messageRef.set({
      'senderId': _userDocId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'clientSentAt': DateTime.now().toIso8601String(),
      'sentAt': Timestamp.now(),
    });
    await _threadRef!.set({
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': _userDocId,
      'unreadCounts.${widget.otherUserId}': FieldValue.increment(1),
      'unreadCounts.${_userDocId!}': 0,
      'lastReadAt.${_userDocId!}': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  DateTime? _parseMessageTime(Map<String, dynamic> data) {
    final createdAt = _parseTimestamp(data['createdAt']);
    if (createdAt != null) {
      return createdAt;
    }
    final sentAt = _parseTimestamp(data['sentAt']);
    if (sentAt != null) {
      return sentAt;
    }
    return _parseTimestamp(data['clientSentAt']);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PremiumStatus>(
      stream: PremiumService.watchStatus(),
      builder: (context, statusSnap) {
        final isPremium = statusSnap.data?.isPremium == true;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                _ProfileAvatar(photoUrl: widget.otherPhotoUrl),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.otherNickname,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              PopupMenuButton<_ChatAction>(
                onSelected: (action) async {
                  if (_userDocId == null) {
                    return;
                  }
                  switch (action) {
                    case _ChatAction.delete:
                      await _threadRef?.set({
                        'hiddenBy.${_userDocId!}': true,
                        'updatedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                      break;
                    case _ChatAction.block:
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(_userDocId)
                          .collection('blocks')
                          .doc(widget.otherUserId)
                          .set({
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      setState(() {
                        _blocked = true;
                      });
                      break;
                    case _ChatAction.report:
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(_userDocId)
                          .collection('reports')
                          .add({
                        'targetId': widget.otherUserId,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('신고가 접수되었습니다.')),
                        );
                      }
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ChatAction.delete,
                    child: Text('대화 삭제'),
                  ),
                  PopupMenuItem(
                    value: _ChatAction.block,
                    child: Text('차단'),
                  ),
                  PopupMenuItem(
                    value: _ChatAction.report,
                    child: Text('신고'),
                  ),
                ],
              ),
            ],
          ),
          body: _threadRef == null
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _threadRef!.snapshots(),
                  builder: (context, threadSnap) {
                    final threadData = threadSnap.data?.data() ?? {};
                    final lastReadAtMap =
                        (threadData['lastReadAt'] as Map?)?.cast<String, dynamic>();
                    final otherReadAt =
                        _parseTimestamp(lastReadAtMap?[widget.otherUserId]);
                    return Column(
                      children: [
                        Expanded(
                          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _threadRef!
                                .collection('messages')
                                .orderBy('createdAt', descending: true)
                                .limit(60)
                                .snapshots(),
                            builder: (context, snapshot) {
                              final docs = snapshot.data?.docs ?? [];
                              if (!isPremium) {
                                return _PremiumLockedMessages(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const PremiumConnectScreen(),
                                      ),
                                    );
                                  },
                                );
                              }
                              if (_blocked) {
                                return _BlockedHint(
                                  onUnblock: () async {
                                    if (_userDocId == null) {
                                      return;
                                    }
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(_userDocId)
                                        .collection('blocks')
                                        .doc(widget.otherUserId)
                                        .delete();
                                    await _restoreThreadVisibility();
                                    if (mounted) {
                                      setState(() {
                                        _blocked = false;
                                      });
                                    }
                                  },
                                );
                              }
                              if (docs.isNotEmpty) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  _markRead();
                                });
                              }
                              return ListView.builder(
                                reverse: true,
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 12),
                                controller: _scrollController,
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  final data = docs[index].data();
                                  final senderId = data['senderId']?.toString();
                                  final text = data['text']?.toString() ?? '';
                                  final createdAt = _parseMessageTime(data);
                                  final isMe = senderId == _userDocId;
                                  final showUnread = isMe &&
                                      (otherReadAt == null ||
                                          (createdAt != null &&
                                              createdAt.isAfter(otherReadAt)));
                                  return _MessageBubble(
                                    text: text,
                                    isMe: isMe,
                                    showUnread: showUnread,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        if (isPremium && !_blocked)
                          _ChatInput(
                            controller: _controller,
                            onSend: _sendMessage,
                          )
                        else
                          const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.isMe,
    required this.showUnread,
  });

  final String text;
  final bool isMe;
  final bool showUnread;

  @override
  Widget build(BuildContext context) {
    final alignment = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isMe ? const Color(0xFF8E5BFF) : const Color(0xFFF1E9FF);
    final textColor = isMe ? Colors.white : const Color(0xFF3A3A3A);
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (isMe && showUnread)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Text(
                  '1',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF4F6D),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: const BoxConstraints(maxWidth: 240),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                text,
                style: TextStyle(color: textColor, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  const _ChatInput({
    required this.controller,
    required this.onSend,
  });

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E5BFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('전송'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumLockedMessages extends StatelessWidget {
  const _PremiumLockedMessages({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 48, color: Color(0xFFBDBDBD)),
            const SizedBox(height: 12),
            const Text(
              '프리미엄 가입 후\n쪽지를 확인할 수 있어요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E5BFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('프리미엄 보기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedHint extends StatelessWidget {
  const _BlockedHint({required this.onUnblock});

  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.block, size: 48, color: Color(0xFFBDBDBD)),
          const SizedBox(height: 12),
          const Text(
            '차단된 사용자입니다.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onUnblock,
            child: const Text('차단 해제'),
          ),
        ],
      ),
    );
  }
}

enum _ChatAction { delete, block, report }

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
