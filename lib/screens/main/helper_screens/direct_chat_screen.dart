import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';
import 'package:volunteer_app/screens/main/helper_screens/image_viewer_screen.dart';
import 'package:volunteer_app/screens/main/helper_screens/public_profile_screen.dart';
import 'package:volunteer_app/screens/main/helper_screens/video_player_screen.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/services/direct_chat_service.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/widgets/chat_bubbles.dart';

class DirectChatScreen extends StatefulWidget {
  final String chatId;
  final String currentUid;
  final String currentName;
  final String? currentAvatarUrl;
  final String recipientUid;
  final String recipientName;
  final String? recipientAvatarUrl;

  const DirectChatScreen({
    super.key,
    required this.chatId,
    required this.currentUid,
    required this.currentName,
    this.currentAvatarUrl,
    required this.recipientUid,
    required this.recipientName,
    this.recipientAvatarUrl,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final DirectChatService _chatService = DirectChatService();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream;
  bool _isSending = false;
  bool _isUploading = false;
  bool _isRecording = false;
  Map<String, String>? _replyMessage;
  Map<String, String>? _editingMessage;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _messagesStream = FirebaseFirestore.instance
        .collection('directChats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _sendMessage({
    String? text,
    String? fileUrl,
    String type = 'text',
    String? fileName,
    String? fileSize,
    double? aspectRatio,
    String? duration,
    String? contactName,
    String? contactPhone,
  }) async {
    final messageText = text ?? _messageController.text;
    if (type == 'text' &&
        _editingMessage != null &&
        messageText.trim().isNotEmpty) {
      await _editMessage(messageText);
      return;
    }
    if (_isSending ||
        (type == 'text' && messageText.trim().isEmpty) ||
        (type == 'contact' && (contactName == null || contactPhone == null))) {
      return;
    }

    final reply = _replyMessage;
    if (reply != null && mounted) setState(() => _replyMessage = null);
    setState(() => _isSending = true);
    try {
      await _chatService.sendMessage(
        chatId: widget.chatId,
        senderUid: widget.currentUid,
        senderName: widget.currentName,
        senderAvatarUrl: widget.currentAvatarUrl,
        recipientUid: widget.recipientUid,
        recipientName: widget.recipientName,
        recipientAvatarUrl: widget.recipientAvatarUrl,
        text: messageText,
        type: type,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: fileSize,
        aspectRatio: aspectRatio,
        duration: duration,
        contactName: contactName,
        contactPhone: contactPhone,
        replyToId: reply?['id'],
        replyToName: reply?['name'],
        replyToText: reply?['text'],
      );
      if (type == 'text') _messageController.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Неуспешно изпращане на съобщението: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _editMessage(String text) async {
    final editing = _editingMessage;
    if (editing == null) return;
    try {
      await _messageReference(
        editing['id']!,
      ).update({'text': text.trim(), 'isEdited': true});
      if (mounted) {
        setState(() => _editingMessage = null);
        _messageController.clear();
      }
    } catch (error) {
      _showError('Неуспешно редактиране на съобщението: $error');
    }
  }

  DocumentReference<Map<String, dynamic>> _messageReference(String messageId) {
    return FirebaseFirestore.instance
        .collection('directChats')
        .doc(widget.chatId)
        .collection('messages')
        .doc(messageId);
  }

  Future<void> _toggleReaction(
    String messageId,
    String emoji,
    Map<String, dynamic> reactions,
  ) async {
    final reference = _messageReference(messageId);
    try {
      if (reactions[widget.currentUid] == emoji) {
        await reference.update({
          'reactions.${widget.currentUid}': FieldValue.delete(),
        });
      } else {
        await reference.update({'reactions.${widget.currentUid}': emoji});
      }
    } catch (error) {
      _showError('Неуспешно добавяне на реакция: $error');
    }
  }

  Future<void> _saveToGallery(String fileUrl, String type) async {
    try {
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      final tempDir = await getTemporaryDirectory();
      final extension = type == 'image' ? 'jpg' : 'mp4';
      final filePath =
          '${tempDir.path}${Platform.pathSeparator}direct_chat_${DateTime.now().millisecondsSinceEpoch}.$extension';
      await Dio().download(fileUrl, filePath);
      if (type == 'image') {
        await Gal.putImage(filePath, album: 'Volunterra');
      } else {
        await Gal.putVideo(filePath, album: 'Volunterra');
      }
      await File(filePath).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Запазено в галерията! (Албум Volunterra)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: greenPrimary,
          ),
        );
      }
    } catch (error) {
      _showError('Грешка при запазване в галерията: $error');
    }
  }

  Future<void> _saveGenericFile(
    String fileUrl,
    String? fileName,
    String type,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fallbackExtension = type == 'audio' ? 'm4a' : 'bin';
      var saveName =
          fileName ??
          'direct_chat_${DateTime.now().millisecondsSinceEpoch}.$fallbackExtension';
      if (!saveName.contains('.')) saveName = '$saveName.$fallbackExtension';
      final savePath = '${tempDir.path}${Platform.pathSeparator}$saveName';
      await Dio().download(fileUrl, savePath);
      final path = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(sourceFilePath: savePath),
      );
      if (path != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Файлът е запазен.')));
      }
    } catch (error) {
      _showError('Грешка при запазване на файла: $error');
    }
  }

  Future<void> _shareMessageContent(
    String messageText,
    String? fileUrl,
    String type,
  ) async {
    if (type == 'contact') {
      await SharePlus.instance.share(ShareParams(text: messageText));
      return;
    }
    if (fileUrl == null || fileUrl.isEmpty) {
      if (messageText.isNotEmpty) {
        await SharePlus.instance.share(ShareParams(text: messageText));
      }
      return;
    }

    setState(() => _isSharing = true);
    try {
      final response = await http.get(Uri.parse(fileUrl));
      if (response.statusCode != 200) {
        throw Exception('Download failed with status ${response.statusCode}');
      }
      final tempDir = await getTemporaryDirectory();
      final extension = switch (type) {
        'image' => 'jpg',
        'video' => 'mp4',
        'audio' => 'm4a',
        _ => 'bin',
      };
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}share_${DateTime.now().millisecondsSinceEpoch}.$extension',
      );
      await file.writeAsBytes(response.bodyBytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: messageText.isEmpty ? null : messageText,
        ),
      );
    } catch (error) {
      _showError('Неуспешно споделяне на съобщението: $error');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _deleteMessage(String messageId, String? fileUrl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Изтриване на съобщение'),
        content: const Text(
          'Сигурни ли сте, че искате да изтриете това съобщение? Това действие не може да бъде отменено.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отказ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Изтрий', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _chatService.deleteMessage(
        chatId: widget.chatId,
        messageId: messageId,
      );
      if (fileUrl != null && fileUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(fileUrl).delete();
        } catch (error) {
          debugPrint('Could not delete direct-chat attachment: $error');
          _showError('Съобщението е изтрито, но файлът не беше премахнат.');
        }
      }
    } catch (error) {
      _showError('Неуспешно изтриване на съобщението: $error');
    }
  }

  void _handleMessageLongPress({
    required String messageId,
    required bool isMe,
    required String messageText,
    required String senderName,
    required String type,
    required String? fileUrl,
    required String? fileName,
    required Map<String, dynamic> reactions,
    required String? contactName,
    required String? contactPhone,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Material(
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['👍', '❤️', '😂', '😮', '😢', '🙏']
                        .map(
                          (emoji) => GestureDetector(
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _toggleReaction(messageId, emoji, reactions);
                            },
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.reply, color: Colors.blue),
                  title: const Text('Отговори'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    setState(() {
                      _replyMessage = {
                        'id': messageId,
                        'name': senderName,
                        'text': messageText.isEmpty
                            ? (type == 'contact'
                                  ? '$contactName ($contactPhone)'
                                  : 'Медия')
                            : messageText,
                      };
                    });
                  },
                ),
                if (fileUrl != null && fileUrl.isNotEmpty)
                  ListTile(
                    leading: const Icon(
                      Icons.download_rounded,
                      color: Colors.purple,
                    ),
                    title: const Text('Запази в устройството'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      if (type == 'image' || type == 'video') {
                        _saveToGallery(fileUrl, type);
                      } else {
                        _saveGenericFile(fileUrl, fileName, type);
                      }
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.share, color: greenPrimary),
                  title: const Text('Сподели / Препрати'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    final shareText = type == 'contact'
                        ? '$contactName ($contactPhone)'
                        : messageText;
                    _shareMessageContent(shareText, fileUrl, type);
                  },
                ),
                if (messageText.isNotEmpty && type == 'text')
                  ListTile(
                    leading: const Icon(Icons.copy, color: Colors.grey),
                    title: const Text('Копирай текста'),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: messageText));
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Копирано!')),
                      );
                    },
                  ),
                if (isMe && type == 'text' && messageText.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.edit, color: Colors.purple),
                    title: const Text('Редактирай'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      setState(() {
                        _editingMessage = {
                          'id': messageId,
                          'text': messageText,
                        };
                        _replyMessage = null;
                        _messageController.text = messageText;
                      });
                    },
                  ),
                if (isMe)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text(
                      'Изтрий',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _deleteMessage(messageId, fileUrl);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _uploadAndSend(
    File file,
    String type, {
    String? fileName,
    String? fileSize,
    double? aspectRatio,
    String? fileExtension,
  }) async {
    setState(() => _isUploading = true);
    try {
      final extension =
          fileExtension ??
          switch (type) {
            'image' => 'jpg',
            'video' => 'mp4',
            'audio' => 'm4a',
            _ => fileName?.split('.').last ?? 'bin',
          };
      final storageName =
          '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(100000)}.$extension';
      final storageRef = FirebaseStorage.instance.ref().child(
        'direct_chats/${widget.chatId}/$storageName',
      );
      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      await _sendMessage(
        text: '',
        fileUrl: downloadUrl,
        type: type,
        fileName: fileName,
        fileSize: fileSize,
        aspectRatio: aspectRatio,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Грешка при качване на файла: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _handleAttachment(String type) async {
    try {
      final picker = ImagePicker();
      if (type == 'image') {
        final images = await picker.pickMultiImage(imageQuality: 70);
        for (final image in images) {
          final file = File(image.path);
          if (await file.length() > 10 * 1024 * 1024) {
            _showError('Изображението ${image.name} надвишава 10 MB.');
            continue;
          }

          double? aspectRatio;
          try {
            final imageData = await file.readAsBytes();
            final codec = await ui.instantiateImageCodec(imageData);
            final frame = await codec.getNextFrame();
            aspectRatio = frame.image.width / frame.image.height;
            codec.dispose();
          } catch (error) {
            debugPrint('Could not read direct-chat image dimensions: $error');
          }

          await _uploadAndSend(
            file,
            'image',
            aspectRatio: aspectRatio,
            fileExtension: image.name.contains('.')
                ? image.name.split('.').last
                : null,
          );
        }
      } else if (type == 'video') {
        final video = await picker.pickVideo(source: ImageSource.gallery);
        if (video == null) return;

        final file = File(video.path);
        if (await file.length() > 50 * 1024 * 1024) {
          _showError('Видеоклипът ${video.name} надвишава 50 MB.');
          return;
        }

        await _uploadAndSend(
          file,
          'video',
          fileExtension: video.name.contains('.')
              ? video.name.split('.').last
              : null,
        );
      } else if (type == 'file') {
        final result = await FilePicker.platform.pickFiles();
        final selected = result?.files.single;
        if (selected?.path == null) return;
        if (selected!.size > 50 * 1024 * 1024) {
          _showError('Файлът не трябва да надвишава 50 MB.');
          return;
        }
        await _uploadAndSend(
          File(selected.path!),
          'file',
          fileName: selected.name,
          fileSize: _formatBytes(selected.size),
          fileExtension: selected.name.contains('.')
              ? selected.name.split('.').last
              : null,
        );
      } else if (type == 'contact') {
        final permission = await FlutterContacts.permissions.request(
          PermissionType.read,
        );
        if (permission.name != 'granted') {
          _showError(
            'Разрешете достъп до контактите, за да споделите контакт.',
          );
          return;
        }

        final pickedContact = await FlutterContacts.native.showPicker();
        if (pickedContact == null) return;
        final contact = await FlutterContacts.get(
          pickedContact.id!,
          properties: {ContactProperty.phone},
        );
        if (contact == null || contact.phones.isEmpty) {
          _showError('Избраният контакт няма телефонен номер.');
          return;
        }
        await _sendMessage(
          text: '',
          type: 'contact',
          contactName: contact.displayName,
          contactPhone: contact.phones.first.number,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Неуспешно добавяне на прикачен файл: $error'),
          ),
        );
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      try {
        final path = await _audioRecorder.stop();
        if (mounted) setState(() => _isRecording = false);
        if (path != null) await _uploadAndSend(File(path), 'audio');
      } catch (error) {
        if (mounted) {
          setState(() => _isRecording = false);
          _showError('Грешка при запис на аудио: $error');
        }
      }
      return;
    }

    try {
      if (!await _audioRecorder.hasPermission()) {
        await Permission.microphone.request();
      }
      if (!await _audioRecorder.hasPermission()) {
        _showError('Необходимо е разрешение за микрофон.');
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      if (mounted) setState(() => _isRecording = true);
    } catch (error) {
      if (mounted) _showError('Неуспешно стартиране на аудио запис: $error');
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade400),
    );
  }

  Future<void> _showAttachmentOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttachmentOption(
                icon: Icons.image,
                label: 'Галерия',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleAttachment('image');
                },
              ),
              _AttachmentOption(
                icon: Icons.videocam,
                label: 'Видео',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleAttachment('video');
                },
              ),
              _AttachmentOption(
                icon: Icons.insert_drive_file,
                label: 'Файл',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleAttachment('file');
                },
              ),
              _AttachmentOption(
                icon: Icons.person,
                label: 'Контакт',
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleAttachment('contact');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showConversationInfo(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> messages,
  ) async {
    try {
      final volunteer = await DatabaseService(
        uid: widget.recipientUid,
      ).getVolunteerUser();
      if (!mounted) return;
      if (volunteer == null) {
        _showError('Профилът на този потребител не е наличен.');
        return;
      }

      final mediaMessages = messages.where((message) {
        final data = message.data();
        final type = data['type'] as String? ?? 'text';
        final url = data['fileUrl'] as String? ?? '';
        return url.isNotEmpty &&
            const {'image', 'video', 'audio', 'file'}.contains(type);
      }).toList(growable: false);

      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => SafeArea(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: greenPrimary.withAlpha(35),
                    backgroundImage:
                        volunteer.avatarUrl != null &&
                            volunteer.avatarUrl!.isNotEmpty
                        ? NetworkImage(volunteer.avatarUrl!)
                        : null,
                    child:
                        volunteer.avatarUrl == null ||
                            volunteer.avatarUrl!.isEmpty
                        ? const Icon(
                            Icons.person,
                            color: greenPrimary,
                            size: 38,
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${volunteer.firstName} ${volunteer.lastName}'.trim(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (volunteer.bio != null &&
                      volunteer.bio!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      volunteer.bio!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                PublicProfileScreen(volunteer: volunteer),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Отвори профила'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: greenPrimary,
                        side: const BorderSide(color: greenPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Споделени медии (${mediaMessages.length})',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (mediaMessages.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: backgroundGrey,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Все още няма споделени снимки, видеа, аудио или файлове.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    _buildMediaGallery(mediaMessages),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) _showError('Неуспешно зареждане на профила: $error');
    }
  }

  Widget _buildMediaGallery(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> messages,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: messages.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) => _buildMediaTile(messages[index]),
    );
  }

  Widget _buildMediaTile(
    QueryDocumentSnapshot<Map<String, dynamic>> message,
  ) {
    final data = message.data();
    final type = data['type'] as String? ?? 'file';
    final url = data['fileUrl'] as String? ?? '';
    final fileName = data['fileName'] as String? ?? '';
    final mediaLabel = switch (type) {
      'image' => 'Снимка',
      'video' => 'Видео',
      'audio' => 'Аудио',
      _ => fileName.isEmpty ? 'Файл' : fileName,
    };

    return Material(
      color: backgroundGrey,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: type == 'image' || type == 'video'
            ? () => _openMediaPreview(type, url)
            : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (type == 'image')
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 36,
                    color: Colors.grey,
                  ),
                ),
              )
            else ...[
              if (type == 'video')
                const ColoredBox(color: Color(0x44000000)),
              Center(
                child: Icon(
                  switch (type) {
                    'video' => Icons.play_circle_outline,
                    'audio' => Icons.music_note,
                    _ => Icons.attach_file,
                  },
                  color: type == 'video'
                      ? Colors.white
                      : type == 'audio'
                      ? greenPrimary
                      : Colors.orange,
                  size: 38,
                ),
              ),
            ],
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                color: Colors.black.withAlpha(150),
                child: Text(
                  mediaLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMediaPreview(String type, String url) {
    if (type == 'image') {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              ImageViewerScreen(imageUrl: url, title: widget.recipientName),
        ),
      );
    } else if (type == 'video') {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => VideoPlayerScreen(videoUrl: url),
        ),
      );
    }
  }

  bool _shouldShowDate(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int index,
  ) {
    if (index == docs.length - 1) return true;
    final current = (docs[index].data()['timestamp'] as Timestamp?)?.toDate();
    final previous = (docs[index + 1].data()['timestamp'] as Timestamp?)
        ?.toDate();
    if (current == null || previous == null) return false;
    return current.year != previous.year ||
        current.month != previous.month ||
        current.day != previous.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        titleSpacing: 0,
        title: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _messagesStream,
          builder: (context, snapshot) => InkWell(
            onTap: snapshot.hasData
                ? () => _showConversationInfo(snapshot.data!.docs)
                : () => _showConversationInfo(const []),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: greenPrimary.withAlpha(35),
                    backgroundImage:
                        widget.recipientAvatarUrl != null &&
                            widget.recipientAvatarUrl!.isNotEmpty
                        ? NetworkImage(widget.recipientAvatarUrl!)
                        : null,
                    child:
                        widget.recipientAvatarUrl == null ||
                            widget.recipientAvatarUrl!.isEmpty
                        ? const Icon(
                            Icons.person,
                            color: greenPrimary,
                            size: 22,
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.recipientName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Грешка при зареждане на чата: ${snapshot.error}',
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: greenPrimary),
                  );
                }

                final messages = snapshot.data?.docs ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Все още няма съобщения.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 20,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data();
                    final timestamp = data['timestamp'] as Timestamp?;
                    final senderId = data['senderId'] as String? ?? '';
                    final type = data['type'] as String? ?? 'text';
                    final messageText = data['text'] as String? ?? '';
                    final fileUrl =
                        (data['fileUrl'] as String?)?.isNotEmpty == true
                        ? data['fileUrl'] as String
                        : null;
                    final reactions = Map<String, dynamic>.from(
                      data['reactions'] ?? {},
                    );
                    return Column(
                      children: [
                        if (_shouldShowDate(messages, index))
                          DateChip(date: timestamp?.toDate() ?? DateTime.now()),
                        ChatBubble(
                          message: messageText,
                          fileUrl: fileUrl,
                          type: type,
                          fileName: data['fileName'] as String?,
                          fileSize: data['fileSize'] as String?,
                          contactName: data['contactName'] as String?,
                          contactPhone: data['contactPhone'] as String?,
                          duration: data['duration'] as String?,
                          aspectRatio: (data['aspectRatio'] as num?)
                              ?.toDouble(),
                          isMe: senderId == widget.currentUid,
                          senderName:
                              data['senderName'] as String? ?? 'Потребител',
                          timestamp: timestamp?.toDate() ?? DateTime.now(),
                          reactions: reactions,
                          replyToName: data['replyToName'] as String?,
                          replyToText: data['replyToText'] as String?,
                          isEdited: data['isEdited'] as bool? ?? false,
                          onLongPress: () => _handleMessageLongPress(
                            messageId: messages[index].id,
                            isMe: senderId == widget.currentUid,
                            messageText: type == 'contact'
                                ? '${data['contactName'] ?? ''} (${data['contactPhone'] ?? ''})'
                                : messageText,
                            senderName:
                                data['senderName'] as String? ?? 'Потребител',
                            type: type,
                            fileUrl: fileUrl,
                            fileName: data['fileName'] as String?,
                            reactions: reactions,
                            contactName: data['contactName'] as String?,
                            contactPhone: data['contactPhone'] as String?,
                          ),
                          onReactionTap: (emoji) => _toggleReaction(
                            messages[index].id,
                            emoji,
                            reactions,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (_isUploading)
            const LinearProgressIndicator(minHeight: 2, color: greenPrimary),
          if (_isSharing)
            const LinearProgressIndicator(minHeight: 2, color: blueSecondary),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyMessage != null || _editingMessage != null)
              Container(
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _editingMessage != null
                      ? Colors.purple.withAlpha(15)
                      : Colors.blue.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(
                      color: _editingMessage != null
                          ? Colors.purple
                          : Colors.blue,
                      width: 4,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _editingMessage != null ? Icons.edit : Icons.reply,
                      color: _editingMessage != null
                          ? Colors.purple
                          : Colors.blue,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _editingMessage != null
                                ? 'Редактиране на съобщение'
                                : 'Отговор до ${_replyMessage!['name']}',
                            style: TextStyle(
                              color: _editingMessage != null
                                  ? Colors.purple
                                  : Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _editingMessage?['text'] ??
                                _replyMessage?['text'] ??
                                '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        setState(() {
                          _replyMessage = null;
                          _editingMessage = null;
                          _messageController.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!_isRecording)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.grey,
                        size: 28,
                      ),
                      onPressed: _isUploading ? null : _showAttachmentOptions,
                    ),
                  ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? Colors.red.withAlpha(25)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _isRecording ? Colors.red : Colors.grey[300]!,
                      ),
                    ),
                    child: _isRecording
                        ? const SizedBox(
                            height: 44,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.fiber_manual_record,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Записване... натиснете стоп за изпращане',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : TextField(
                            controller: _messageController,
                            maxLines: 5,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _sendMessage(),
                            decoration: const InputDecoration(
                              hintText: 'Напишете съобщение...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: IconButton.filled(
                    onPressed: _isUploading || _isSending
                        ? null
                        : _isRecording
                        ? _toggleRecording
                        : _messageController.text.trim().isNotEmpty
                        ? _sendMessage
                        : _toggleRecording,
                    style: IconButton.styleFrom(
                      backgroundColor: _isRecording ? Colors.red : greenPrimary,
                      disabledBackgroundColor: greenPrimary.withAlpha(100),
                    ),
                    icon: Icon(
                      _isSending
                          ? Icons.hourglass_top
                          : _isRecording
                          ? Icons.stop
                          : _messageController.text.trim().isNotEmpty
                          ? Icons.send_rounded
                          : Icons.mic,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color.withAlpha(25),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
