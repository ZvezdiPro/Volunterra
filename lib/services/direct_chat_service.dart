import 'package:cloud_firestore/cloud_firestore.dart';

class DirectChatService {
  final FirebaseFirestore _db;

  DirectChatService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  String chatIdFor(String firstUid, String secondUid) {
    final participants = [firstUid, secondUid]..sort();
    return '${participants[0]}__${participants[1]}';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> userChats(String uid) {
    return _db
        .collection('directChats')
        .where('participants', arrayContains: uid)
        .snapshots();
  }

  Future<String> createOrGetChat({
    required String currentUid,
    required String currentName,
    String? currentAvatarUrl,
    required String recipientUid,
    required String recipientName,
    String? recipientAvatarUrl,
  }) async {
    if (currentUid == recipientUid) {
      throw ArgumentError('A direct chat requires two different participants.');
    }

    final chatId = chatIdFor(currentUid, recipientUid);
    final chatRef = _db.collection('directChats').doc(chatId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(chatRef);
      final chatData = <String, dynamic>{
        'participants': [currentUid, recipientUid],
        'participantDetails': {
          currentUid: {'name': currentName, 'avatarUrl': currentAvatarUrl},
          recipientUid: {
            'name': recipientName,
            'avatarUrl': recipientAvatarUrl,
          },
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!snapshot.exists) {
        chatData['createdAt'] = FieldValue.serverTimestamp();
      }

      transaction.set(chatRef, chatData, SetOptions(merge: true));
    });

    return chatId;
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderUid,
    required String senderName,
    String? senderAvatarUrl,
    required String recipientUid,
    required String recipientName,
    String? recipientAvatarUrl,
    required String text,
    String type = 'text',
    String? fileUrl,
    String? fileName,
    String? fileSize,
    double? aspectRatio,
    String? duration,
    String? contactName,
    String? contactPhone,
    String? replyToName,
    String? replyToText,
    String? replyToId,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty && type == 'text') return;

    final chatRef = _db.collection('directChats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();
    final batch = _db.batch();

    final messageData = <String, dynamic>{
      'senderId': senderUid,
      'senderName': senderName,
      'senderAvatar': senderAvatarUrl,
      'text': trimmedText,
      'type': type,
      'fileUrl': fileUrl ?? '',
      'fileName': fileName ?? '',
      'fileSize': fileSize ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': <String, dynamic>{},
    };
    if (aspectRatio != null) messageData['aspectRatio'] = aspectRatio;
    if (duration != null) messageData['duration'] = duration;
    if (contactName != null) messageData['contactName'] = contactName;
    if (contactPhone != null) messageData['contactPhone'] = contactPhone;
    if (replyToName != null) messageData['replyToName'] = replyToName;
    if (replyToText != null) messageData['replyToText'] = replyToText;
    if (replyToId != null) messageData['replyToId'] = replyToId;
    batch.set(messageRef, messageData);

    batch.set(chatRef, {
      'participants': [senderUid, recipientUid],
      'participantDetails': {
        senderUid: {'name': senderName, 'avatarUrl': senderAvatarUrl},
        recipientUid: {'name': recipientName, 'avatarUrl': recipientAvatarUrl},
      },
      'lastMessage': _previewForMessage(messageData),
      'lastMessageId': messageRef.id,
      'lastMessageType': type,
      'lastMessageFileUrl': fileUrl ?? '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    final chatRef = _db.collection('directChats').doc(chatId);
    final messagesRef = chatRef.collection('messages');
    final messageRef = messagesRef.doc(messageId);
    final messageSnapshot = await messageRef.get();
    final deletedMessage = messageSnapshot.data();
    if (!messageSnapshot.exists || deletedMessage == null) return;

    await messageRef.delete();

    final remainingMessages = await messagesRef
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    final latestMessage = remainingMessages.docs.isEmpty
        ? null
        : remainingMessages.docs.first;

    await _db.runTransaction((transaction) async {
      final chatSnapshot = await transaction.get(chatRef);
      if (!chatSnapshot.exists) return;

      final chatData = chatSnapshot.data() ?? <String, dynamic>{};
      final deletedTimestamp = deletedMessage['timestamp'];
      final lastMessageAt = chatData['lastMessageAt'];
      final wasLastMessage =
          chatData['lastMessageId'] == messageId ||
          (chatData['lastMessageId'] == null &&
              deletedTimestamp is Timestamp &&
              lastMessageAt is Timestamp &&
              deletedTimestamp.compareTo(lastMessageAt) == 0);
      if (!wasLastMessage) return;

      if (latestMessage == null) {
        transaction.update(chatRef, {
          'lastMessage': FieldValue.delete(),
          'lastMessageId': FieldValue.delete(),
          'lastMessageType': FieldValue.delete(),
          'lastMessageFileUrl': FieldValue.delete(),
          'lastMessageAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final latestData = latestMessage.data();
      transaction.set(chatRef, {
        'lastMessage': _previewForMessage(latestData),
        'lastMessageId': latestMessage.id,
        'lastMessageType': latestData['type'] as String? ?? 'text',
        'lastMessageFileUrl': latestData['fileUrl'] as String? ?? '',
        'lastMessageAt': latestData['timestamp'],
        'updatedAt': latestData['timestamp'],
      }, SetOptions(merge: true));
    });
  }

  String _previewForMessage(Map<String, dynamic> message) {
    final text = (message['text'] as String? ?? '').trim();
    if (text.isNotEmpty) return text;

    return switch (message['type'] as String? ?? 'text') {
      'image' => '📷 Снимка',
      'video' => '🎥 Видео',
      'audio' => '🎤 Гласово съобщение',
      'file' => '📎 Файл: ${message['fileName'] as String? ?? ''}',
      'contact' =>
        '👤 Контакт: ${message['contactName'] as String? ?? ''}',
      _ => 'Ново съобщение',
    };
  }
}
