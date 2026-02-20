import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/chat_moderation_service.dart';
import '../services/premium_service.dart';
import 'premium_connect_screen.dart';

class MessageChatScreen extends StatefulWidget {
  const MessageChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherNickname,
    this.otherPhotoUrl,
    this.otherAvatarEmoji,
  });

  final String otherUserId;
  final String otherNickname;
  final String? otherPhotoUrl;
  final String? otherAvatarEmoji;

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
  final Map<String, _PendingMessage> _pendingMessages = {};
  bool _loading = true;
  String? _loadError;
  Timer? _loadTimer;

  @override
  void initState() {
    super.initState();
    _prepareThread();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _loadTimer?.cancel();
    super.dispose();
  }

  Future<void> _prepareThread() async {
    _loadTimer?.cancel();
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    _loadTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted || !_loading) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = '네트워크가 느려서 채팅을 불러오지 못했어요.';
      });
    });
    try {
      final userDocId = await _userDocIdFuture.timeout(
        const Duration(seconds: 8),
        onTimeout: () => null,
      );
      if (!mounted) {
        return;
      }
      if (userDocId == null) {
        setState(() {
          _loading = false;
          _loadError = '로그인이 필요하거나 네트워크가 지연되고 있어요.';
        });
        return;
      }
      _userDocId = userDocId;
      final threadId = _buildThreadId(userDocId, widget.otherUserId);
      final ref = FirebaseFirestore.instance.collection('threads').doc(threadId);
      _loadTimer?.cancel();
      setState(() {
        _threadRef = ref;
        _loading = false;
        _loadError = null;
      });
      // Fire-and-forget: avoid blocking UI on slow Firestore calls.
      FirebaseFirestore.instance
          .collection('users')
          .doc(userDocId)
          .collection('blocks')
          .doc(widget.otherUserId)
          .get()
          .then((blockDoc) {
        if (!mounted) {
          return;
        }
        setState(() {
          _blocked = blockDoc.exists;
        });
      });
      ref.get().then((snap) {
        if (!snap.exists) {
          return ref.set({
            'participants': [userDocId, widget.otherUserId],
            'participantsKey': threadId,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        return ref.set({
          'participants': FieldValue.arrayUnion([userDocId, widget.otherUserId]),
          'participantsKey': threadId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      _loadTimer?.cancel();
      setState(() {
        _loading = false;
        _loadError = '채팅을 불러오지 못했어요.\n${e.runtimeType}: $e';
      });
    }
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
    final nowIso = DateTime.now().toIso8601String();
    await _threadRef!.set({
      'unreadCounts.${_userDocId!}': 0,
      'lastReadAt.${_userDocId!}': FieldValue.serverTimestamp(),
      'lastReadAtClient.${_userDocId!}': nowIso,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _sendMessage() async {
    if (_threadRef == null || _userDocId == null || _blocked) {
      return;
    }
    final moderation = ChatModerationService.evaluateOutgoing(_controller.text);
    if (moderation.status == ChatModerationStatus.blocked) {
      final message = moderation.userMessage ?? '메시지를 보낼 수 없어요.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      return;
    }
    final text = moderation.text;
    if (text.isEmpty) {
      return;
    }
    _controller.clear();
    final messageRef = _threadRef!.collection('messages').doc();
    final now = DateTime.now();
    final sentAt = Timestamp.fromDate(now);
    setState(() {
      _pendingMessages[messageRef.id] = _PendingMessage(
        id: messageRef.id,
        text: text,
        sentAt: now,
      );
    });
    try {
      await messageRef.set({
        'senderId': _userDocId,
        'text': text,
        'moderationStatus': moderation.status.name,
        if (moderation.reason != null) 'moderationReason': moderation.reason,
        // Use client timestamp for immediate local rendering in chat stream.
        'createdAt': sentAt,
        'createdAtServer': FieldValue.serverTimestamp(),
        'clientSentAt': now.toIso8601String(),
        'sentAt': sentAt,
      });
      await _threadRef!.set({
        'participants': FieldValue.arrayUnion([_userDocId!, widget.otherUserId]),
        'participantsKey': _buildThreadId(_userDocId!, widget.otherUserId),
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageAtClient': sentAt,
        'lastSenderId': _userDocId,
        'unreadCounts.${widget.otherUserId}': FieldValue.increment(1),
        'unreadCounts.${_userDocId!}': 0,
        'lastReadAt.${_userDocId!}': FieldValue.serverTimestamp(),
        'lastReadAtClient.${_userDocId!}': now.toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (moderation.status == ChatModerationStatus.sanitized &&
          mounted &&
          moderation.userMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(moderation.userMessage!)),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pendingMessages.remove(messageRef.id);
        });
      }
      rethrow;
    }
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

  void _openFullImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenProfileImageScreen(imageUrl: imageUrl),
      ),
    );
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
                GestureDetector(
                  onTap: () {
                    final url = widget.otherPhotoUrl?.trim();
                    if (url == null || url.isEmpty) {
                      return;
                    }
                    _openFullImage(context, url);
                  },
                  child: _ProfileAvatar(
                    photoUrl: widget.otherPhotoUrl,
                    avatarEmoji: widget.otherAvatarEmoji,
                  ),
                ),
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
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFFF6B6B), size: 42),
                            const SizedBox(height: 12),
                            Text(
                              _loadError!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _loading = true;
                                  _loadError = null;
                                });
                                _prepareThread();
                              },
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _threadRef == null
                      ? const SizedBox.shrink()
                : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _threadRef!.snapshots(),
                    builder: (context, threadSnap) {
                      final threadData = threadSnap.data?.data() ?? {};
                      final lastReadAtMap =
                          (threadData['lastReadAt'] as Map?)?.cast<String, dynamic>();
                      final lastReadAtClientMap =
                          (threadData['lastReadAtClient'] as Map?)
                              ?.cast<String, dynamic>();
                      final otherLastReadAt = _parseTimestamp(
                        lastReadAtMap?[widget.otherUserId] ??
                            threadData['lastReadAt.${widget.otherUserId}'],
                      );
                      final otherLastReadAtClient = _parseTimestamp(
                        lastReadAtClientMap?[widget.otherUserId] ??
                            threadData['lastReadAtClient.${widget.otherUserId}'],
                      );
                      final effectiveOtherLastReadAt =
                          (otherLastReadAtClient != null &&
                                  (otherLastReadAt == null ||
                                      otherLastReadAtClient.isAfter(otherLastReadAt)))
                              ? otherLastReadAtClient
                              : otherLastReadAt;
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
                              if (_pendingMessages.isNotEmpty) {
                                final persistedIds = docs.map((d) => d.id).toSet();
                                final toRemove = _pendingMessages.keys
                                    .where(persistedIds.contains)
                                    .toList();
                                if (toRemove.isNotEmpty) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (!mounted) return;
                                    setState(() {
                                      for (final id in toRemove) {
                                        _pendingMessages.remove(id);
                                      }
                                    });
                                  });
                                }
                              }
                              return ListView.builder(
                                reverse: true,
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 12),
                                controller: _scrollController,
                                itemCount: docs.length + _pendingMessages.length,
                                itemBuilder: (context, index) {
                                  final pendingList = _pendingMessages.values.toList()
                                    ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
                                  if (index < pendingList.length) {
                                    final pending = pendingList[index];
                                    return _MessageBubble(
                                      text: pending.text,
                                      isMe: true,
                                      showUnread: true,
                                    );
                                  }
                                  final docIndex = index - pendingList.length;
                                  final data = docs[docIndex].data();
                                  final senderId = data['senderId']?.toString();
                                  final text = data['text']?.toString() ?? '';
                                  final moderationStatus =
                                      data['moderationStatus']?.toString() ?? '';
                                  final displayText = moderationStatus == 'blocked'
                                      ? ChatModerationService.blockedPlaceholder
                                      : text;
                                  final isMe = senderId == _userDocId;
                                  final messageAt = _parseMessageTime(data);
                                  final showUnread =
                                      isMe &&
                                      messageAt != null &&
                                      (effectiveOtherLastReadAt == null ||
                                          messageAt.isAfter(effectiveOtherLastReadAt));
                                  return _MessageBubble(
                                    text: displayText,
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
                backgroundColor: const Color(0xFFFFC83D),
                foregroundColor: const Color(0xFF4A3700),
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
  const _ProfileAvatar({required this.photoUrl, this.avatarEmoji});

  final String? photoUrl;
  final String? avatarEmoji;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: const Color(0xFFF1E9FF),
        backgroundImage: NetworkImage(photoUrl!),
      );
    }
    if (avatarEmoji != null && avatarEmoji!.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: const Color(0xFFFFE3D3),
        child: Text(
          avatarEmoji!.trim(),
          style: const TextStyle(fontSize: 17),
        ),
      );
    }
    return const CircleAvatar(
      radius: 18,
      backgroundColor: Color(0xFFF1E9FF),
      child: Icon(Icons.person, color: Color(0xFF8E5BFF)),
    );
  }
}

class _FullScreenProfileImageScreen extends StatelessWidget {
  const _FullScreenProfileImageScreen({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image, color: Colors.white70, size: 56),
          ),
        ),
      ),
    );
  }
}

class _PendingMessage {
  const _PendingMessage({
    required this.id,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String text;
  final DateTime sentAt;
}
