import 'package:cloud_firestore/cloud_firestore.dart';

class MatchOneLinerStore {
  static String storageKey({
    required String matchType,
    required String matchKey,
  }) {
    return '$matchType|$matchKey';
  }

  static String docId({required String matchType, required String matchKey}) {
    return Uri.encodeComponent(
      storageKey(matchType: matchType, matchKey: matchKey),
    );
  }

  static Future<Map<String, String>> loadMine(String userDocId) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('matchOneLiners')
        .get();
    final result = <String, String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final type = data['matchType']?.toString() ?? '';
      final key = data['matchKey']?.toString() ?? '';
      final message = data['message']?.toString() ?? '';
      if (type.isEmpty || key.isEmpty) {
        continue;
      }
      result[storageKey(matchType: type, matchKey: key)] = message;
    }
    return result;
  }

  static Future<void> upsertMine({
    required String userDocId,
    required String matchType,
    required String matchKey,
    required String message,
  }) async {
    final trimmed = message.trim();
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('matchOneLiners')
        .doc(docId(matchType: matchType, matchKey: matchKey));
    if (trimmed.isEmpty) {
      await ref.delete();
      return;
    }
    final limited = trimmed.length > 20 ? trimmed.substring(0, 20) : trimmed;
    await ref.set({
      'ownerId': userDocId,
      'matchType': matchType,
      'matchKey': matchKey,
      'message': limited,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<String?> loadForUser({
    required String userDocId,
    required String matchType,
    required String matchKey,
  }) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userDocId)
        .collection('matchOneLiners')
        .doc(docId(matchType: matchType, matchKey: matchKey))
        .get();
    final text = doc.data()?['message']?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }
}
