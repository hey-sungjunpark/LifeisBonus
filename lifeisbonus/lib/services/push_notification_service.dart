import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_settings_service.dart';
import 'premium_service.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _chatChannel =
      AndroidNotificationChannel(
        'chat_messages',
        '채팅 알림',
        description: '새 쪽지 알림 채널',
        importance: Importance.max,
      );
  static bool _initialized = false;
  static final StreamController<ChatOpenPayload> _openChatController =
      StreamController<ChatOpenPayload>.broadcast();
  static ChatOpenPayload? _pendingInitialOpen;

  static Stream<ChatOpenPayload> get onOpenChat => _openChatController.stream;

  static ChatOpenPayload? consumeInitialOpenChat() {
    final payload = _pendingInitialOpen;
    _pendingInitialOpen = null;
    return payload;
  }

  static Future<void> initialize() async {
    if (_initialized) {
      await _registerCurrentToken();
      return;
    }
    _initialized = true;

    await AppSettingsService.ensureLoaded();
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_chatChannel);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    await _registerCurrentToken();
    final initialMessage = await _messaging.getInitialMessage();
    final initialPayload = _parseOpenPayload(initialMessage);
    if (initialPayload != null) {
      _pendingInitialOpen = initialPayload;
    }

    _messaging.onTokenRefresh.listen((token) async {
      if (token.isEmpty) {
        return;
      }
      await _upsertToken(token);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final payload = _parseOpenPayload(message);
      if (payload == null) {
        return;
      }
      _openChatController.add(payload);
    });
  }

  static Future<void> _registerCurrentToken() async {
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    await _upsertToken(token);
  }

  static Future<void> syncNotificationPreference(bool enabled) async {
    final userDocId = await PremiumService.resolveUserDocId();
    if (userDocId == null) {
      return;
    }
    await FirebaseFirestore.instance.collection('users').doc(userDocId).set({
      'notificationsEnabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> _upsertToken(String token) async {
    final userDocId = await PremiumService.resolveUserDocId();
    if (userDocId == null) {
      return;
    }
    await FirebaseFirestore.instance.collection('users').doc(userDocId).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'notificationsEnabled': AppSettingsService.alertsEnabled.value,
      'lastFcmTokenAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static ChatOpenPayload? _parseOpenPayload(RemoteMessage? message) {
    if (message == null) {
      return null;
    }
    final data = message.data;
    if (data.isEmpty) {
      return null;
    }
    final type = data['type']?.toString().trim();
    if (type != 'chat_message') {
      return null;
    }
    final threadId = data['threadId']?.toString().trim() ?? '';
    final senderId = data['senderId']?.toString().trim() ?? '';
    final senderName = data['senderName']?.toString().trim();
    if (threadId.isEmpty || senderId.isEmpty) {
      return null;
    }
    return ChatOpenPayload(
      threadId: threadId,
      senderId: senderId,
      senderName: senderName,
    );
  }
}

@immutable
class ChatOpenPayload {
  const ChatOpenPayload({
    required this.threadId,
    required this.senderId,
    this.senderName,
  });

  final String threadId;
  final String senderId;
  final String? senderName;
}
