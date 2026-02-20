enum ChatModerationStatus { ok, sanitized, blocked }

class ChatModerationResult {
  const ChatModerationResult({
    required this.status,
    required this.text,
    this.reason,
    this.userMessage,
  });

  final ChatModerationStatus status;
  final String text;
  final String? reason;
  final String? userMessage;
}

class ChatModerationService {
  static const int maxLength = 300;
  static const String blockedPlaceholder = '운영 정책에 의해 숨겨진 메시지입니다.';

  static final RegExp _repeatSpamPattern = RegExp(r'(.)\1{8,}');
  static final List<String> _blockedKeywords = [
    '개새끼',
    '병신',
    '섹스',
    '자살',
    '죽여',
    '성폭행',
    '강간',
    '마약',
  ];

  static ChatModerationResult evaluateOutgoing(String raw) {
    final normalized = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return const ChatModerationResult(
        status: ChatModerationStatus.blocked,
        text: '',
        reason: 'empty',
        userMessage: '메시지를 입력해 주세요.',
      );
    }
    if (normalized.length > maxLength) {
      return const ChatModerationResult(
        status: ChatModerationStatus.blocked,
        text: '',
        reason: 'too_long',
        userMessage: '메시지는 300자 이하로 입력해 주세요.',
      );
    }
    if (_repeatSpamPattern.hasMatch(normalized)) {
      return const ChatModerationResult(
        status: ChatModerationStatus.blocked,
        text: '',
        reason: 'spam_repeat',
        userMessage: '반복 문자가 많은 메시지는 보낼 수 없어요.',
      );
    }
    final lower = normalized.toLowerCase();
    for (final keyword in _blockedKeywords) {
      if (lower.contains(keyword.toLowerCase())) {
        return const ChatModerationResult(
          status: ChatModerationStatus.blocked,
          text: blockedPlaceholder,
          reason: 'policy_keyword',
          userMessage: '운영 정책에 맞지 않는 메시지는 보낼 수 없어요.',
        );
      }
    }

    return ChatModerationResult(
      status: ChatModerationStatus.ok,
      text: normalized,
    );
  }
}
