// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:async';
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
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart'; 
import 'package:share_plus/share_plus.dart';
import 'package:volunteer_app/models/ngo.dart';
import 'package:volunteer_app/screens/main/helper_screens/ngo_members_screen.dart';
import 'package:volunteer_app/screens/main/helper_screens/public_ngo_screen.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/widgets/chat_bubbles.dart';

// Main screen for NGO chat widget
class NgoChatScreen extends StatefulWidget {
  final NGO ngo;
  final dynamic currentUser;

  const NgoChatScreen({
    super.key,
    required this.ngo,
    required this.currentUser,
  });

  @override
  State<NgoChatScreen> createState() => _NgoChatScreenState();
}

class _NgoChatScreenState extends State<NgoChatScreen> {
  // State variables
  Map<String, String>? _replyMessage;
  Map<String, String>? _editingMessage;
  bool _isUploading = false;
  bool _isSharing = false;
  bool _showInfoBanner = true;

  late final Stream<DocumentSnapshot> _ngoStream;
  late final Stream<QuerySnapshot> _messagesStream;

  @override
  void initState() {
    super.initState();
    _ngoStream = FirebaseFirestore.instance.collection('ngos').doc(widget.ngo.id).snapshots();
    _messagesStream = FirebaseFirestore.instance
        .collection('ngos')
        .doc(widget.ngo.id)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  String get _currentUid => widget.currentUser is NGO ? widget.currentUser.id : widget.currentUser.uid;
  String get _currentName => widget.currentUser is NGO ? widget.currentUser.name : widget.currentUser.firstName;

  bool get _canSendMessages => widget.ngo.admins.contains(_currentUid) || widget.ngo.id == _currentUid;

  // Helper method to format bytes to human-readable string
  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 Б";
    const suffixes = ["Б", "КБ", "МБ", "ГБ", "ТБ"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  // Save image/video to gallery
  Future<void> _saveToGallery(String fileUrl, String type) async {
    if (fileUrl.isEmpty) return;

    try {
      setState(() => _isSharing = true);

      // See if we have access to gallery
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }

      final tempDir = await getTemporaryDirectory();
      
      // Determine file extension
      String ext = "";
      if (type == 'image') ext = "jpg";
      else if (type == 'video') ext = "mp4";
      else {
        throw Exception("Аудио файловете не се поддържат от Галерията.");
      }
      
      final String fileName = "volunteer_${DateTime.now().millisecondsSinceEpoch}.$ext";
      final String filePath = '${tempDir.path}/$fileName';

      await Dio().download(fileUrl, filePath);

      if (type == 'image') {
        await Gal.putImage(filePath, album: 'Volunterra');
      } else if (type == 'video') {
        await Gal.putVideo(filePath, album: 'Volunterra');
      }

      try {
        File(filePath).delete(); 
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Запазено в галерията! (Албум Volunterra)", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: greenPrimary,
          ),
        );
      }

    } catch (e) {
      debugPrint("Gallery Error: $e");
      if (mounted) {
        String errorMsg = "Грешка при запазване.";
        if (e.toString().contains("ACCESS_DENIED")) {
          errorMsg = "Няма права за достъп до Галерията.";
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  // Save generic file (audio, document, etc.)
  Future<void> _saveGenericFile(String fileUrl, String? fileName, String type) async {
    try {
      setState(() => _isSharing = true);

      final tempDir = await getTemporaryDirectory();
      String ext = type == 'audio' ? 'm4a' : 'bin';
      String finalName = fileName ?? "audio_${DateTime.now().millisecondsSinceEpoch}.$ext";
      
      if (!finalName.contains('.')) finalName += ".$ext";

      final String savePath = '${tempDir.path}/$finalName';
      await Dio().download(fileUrl, savePath);

      final params = SaveFileDialogParams(sourceFilePath: savePath);
      final filePath = await FlutterFileDialog.saveFile(params: params);

      if (mounted) {
        if (filePath != null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Файлът е запазен!"), 
              backgroundColor: greenPrimary
          ));
        } 
      }
    } catch (e) {
      debugPrint("File Save Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Грешка: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  // Pin message
  Future<void> _pinMessage(String messageId, String text, String type) async {
    if (!_canSendMessages) return;
    try {
      await FirebaseFirestore.instance.collection('ngos').doc(widget.ngo.id).update({
        'pinnedMessage': {
          'id': messageId,
          'text': text,
          'type': type,
          'timestamp': DateTime.now().toIso8601String(),
        }
      });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Съобщението е закачено!", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: greenPrimary));
    } catch (e) {
      debugPrint("Pin Error: $e");
    }
  }

  Future<void> _unpinMessage() async {
    if (!_canSendMessages) return;
    try {
      await FirebaseFirestore.instance.collection('ngos').doc(widget.ngo.id).update({
        'pinnedMessage': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint("Unpin Error: $e");
    }
  }

  // Sand message handlers
  void _handleSendText(String text) {
    if (_editingMessage != null) {
      _handleUpdateMessage(text);
    } else {
      _sendMessage(text: text);
    }
  }

  void _handleUpdateMessage(String newText) async {
    final originalMessageId = _editingMessage!['id']!;
    setState(() {
      _editingMessage = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('ngos')
          .doc(widget.ngo.id)
          .collection('messages')
          .doc(originalMessageId)
          .update({
        'text': newText,
        'isEdited': true,
      });
    } catch (e) {
      debugPrint("Error updating message: $e");
    }
  }

  void _handleSendAudio(String path) async {
    await _uploadAndSend(File(path), 'chat_audio', 'audio', 'm4a');
  }

  Future<void> _uploadAndSend(File file, String folder, String type, String ext, {double? aspectRatio}) async {
    setState(() => _isUploading = true);
    try {
      String fileName = "${DateTime.now().millisecondsSinceEpoch}.$ext";
      Reference storageRef = FirebaseStorage.instance.ref().child('$folder/${widget.ngo.id}/$fileName');
      
      await storageRef.putFile(file);
      String downloadUrl = await storageRef.getDownloadURL();

      _sendMessage(
        fileUrl: downloadUrl,
        type: type,
        aspectRatio: aspectRatio,
        fileName: type == 'file' ? file.path.split('/').last : null,
      );
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Грешка при качване: $e")));
    } finally {
      if(mounted) setState(() => _isUploading = false);
    }
  }

  void _sendMessage({
    String? text,
    String? fileUrl,
    String type = 'text',
    String? fileName,
    String? fileSize,
    String? contactName,
    String? contactPhone,
    double? aspectRatio,
  }) async {
    if (!_canSendMessages) return;

    final replyData = _replyMessage;
    if (_replyMessage != null) {
      setState(() {
        _replyMessage = null;
      });
    }

    try {
      await FirebaseFirestore.instance
          .collection('ngos')
          .doc(widget.ngo.id)
          .collection('messages')
          .add({
        'text': text ?? '',
        'fileUrl': fileUrl ?? '',
        'type': type,
        'fileName': fileName ?? '',
        'fileSize': fileSize ?? '',
        'contactName': contactName ?? '',
        'contactPhone': contactPhone ?? '',
        'aspectRatio': aspectRatio,
        'senderId': _currentUid,
        'senderName': _currentName,
        'timestamp': FieldValue.serverTimestamp(),
        'reactions': {},
        'replyToName': replyData?['name'],
        'replyToText': replyData?['text'],
        'replyToId': replyData?['id'],
      });
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }

  void _showSizeExceededError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }

  // Attachment handlers
  void _handleAttachment(String type) async {
    final ImagePicker picker = ImagePicker();

    final int maxImageSize = 10 * 1024 * 1024;
    final int maxVideoFileSize = 50 * 1024 * 1024;

    try {
      if (type == 'gallery') {
         final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
         if (image != null) {
           File file = File(image.path);
           if (file.lengthSync() > maxImageSize) {
             _showSizeExceededError("Изображението не трябва да надвишава 10 MB!");
             return;
           }
           double? imageAspectRatio;
           try {
             final data = await file.readAsBytes();
             final codec = await ui.instantiateImageCodec(data);
             final frameInfo = await codec.getNextFrame();
             imageAspectRatio = frameInfo.image.width / frameInfo.image.height;
           } catch (e) {
             debugPrint("Image decode error: $e");
           }
           _uploadAndSend(file, 'chat_images', 'image', 'jpg', aspectRatio: imageAspectRatio);
         }
      } else if (type == 'video') {
         final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
         if (video != null) {
           File file = File(video.path);
           if (file.lengthSync() > maxVideoFileSize) {
             _showSizeExceededError("Видеоклипът не трябва да надвишава 50 MB!");
             return;
           }
           _uploadAndSend(file, 'chat_videos', 'video', 'mp4');
         }
      } else if (type == 'file') {
         FilePickerResult? result = await FilePicker.platform.pickFiles();
         if (result != null && result.files.single.path != null) {
            File file = File(result.files.single.path!);
            
            if (result.files.single.size > maxVideoFileSize) {
              _showSizeExceededError("Файлът не трябва да надвишава 50 MB!");
              return;
            }

            String size = _formatBytes(result.files.single.size, 1);
            
            setState(() => _isUploading = true);
            Reference ref = FirebaseStorage.instance.ref().child('chat_files/${widget.ngo.id}/${result.files.single.name}');
            await ref.putFile(file);
            String url = await ref.getDownloadURL();
            _sendMessage(fileUrl: url, type: 'file', fileName: result.files.single.name, fileSize: size);
            setState(() => _isUploading = false);
         }
      } else if (type == 'contact') {
        if (await FlutterContacts.requestPermission(readonly: true)) {
          final Contact? contact = await FlutterContacts.openExternalPick();
          if (contact != null && contact.phones.isNotEmpty) {
            _sendMessage(type: 'contact', contactName: contact.displayName, contactPhone: contact.phones.first.number);
          }
        }
      }
    } catch (e) {
      if(mounted) setState(() => _isUploading = false);
    }
  }

  // Share message content to other apps
  Future<void> _shareMessageContent(String? text, String? fileUrl, String type) async {
    if ((fileUrl == null || fileUrl.isEmpty) && text != null && text.isNotEmpty) {
      await SharePlus.instance.share(ShareParams(text: text));
      return;
    }

    if (fileUrl != null && fileUrl.isNotEmpty) {
      try {
        setState(() => _isSharing = true);

        final http.Response response = await http.get(Uri.parse(fileUrl));
        if (response.statusCode != 200) throw Exception("Грешка при сваляне");

        final Directory tempDir = await getTemporaryDirectory();
        
        String extension = 'bin';
        String mimeType = '*/*';

        if (type == 'image') { extension = 'jpg'; mimeType = 'image/jpeg'; }
        else if (type == 'video') { extension = 'mp4'; mimeType = 'video/mp4'; }
        else if (type == 'audio') { extension = 'm4a'; mimeType = 'audio/mp4'; }
        else if (type == 'file') {
          if (fileUrl.toLowerCase().contains('.pdf')) { extension = 'pdf'; mimeType = 'application/pdf'; }
          else { extension = 'file'; }
        }

        final String cleanFileName = 'share_${DateTime.now().millisecondsSinceEpoch}.$extension';
        final File file = File('${tempDir.path}/$cleanFileName');
        
        await file.writeAsBytes(response.bodyBytes);

        if (!await file.exists()) throw Exception("File write failed");

        final XFile xFile = XFile(file.path, mimeType: mimeType);
        
        await Future.delayed(const Duration(milliseconds: 100));
        await SharePlus.instance.share(ShareParams(files: [xFile], text: (text != null && text.isNotEmpty) ? text : null));

      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red.shade300, content: Center(child: Text("Неуспешно споделяне на файл."))));
        }
      } finally {
        if (mounted) setState(() => _isSharing = false);
      }
    }
  }

  // Toggle reaction
  Future<void> _toggleReaction(String docId, String emoji, Map<String, dynamic> currentReactions) async {
    final uid = _currentUid;
    final docRef = FirebaseFirestore.instance.collection('ngos').doc(widget.ngo.id).collection('messages').doc(docId);
    if (currentReactions[uid] == emoji) {
       await docRef.update({'reactions.$uid': FieldValue.delete()});
    } else {
       await docRef.update({'reactions.$uid': emoji});
    }
  }

  // Message long press menu
  void _handleMessageLongPress(String docId, bool isMe, String messageText, String senderName, String? fileUrl, String type, Map<String, dynamic> currentReactions, String? fileName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reactions row
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ["👍", "❤️", "😂", "😮", "😢", "🙏"].map((emoji) {
                    return GestureDetector(
                      onTap: () { Navigator.pop(context); _toggleReaction(docId, emoji, currentReactions); },
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1),
              
              // Response button - ONLY if user can send messages
              if (_canSendMessages)
                ListTile(
                  leading: const Icon(Icons.reply, color: Colors.blue),
                  title: const Text('Отговори'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _replyMessage = {'id': docId, 'name': senderName, 'text': messageText.isEmpty ? (type == 'text' ? '' : 'Медия') : messageText};
                    });
                  },
                ),

              // Save button
              if (fileUrl != null && fileUrl.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.download_rounded, color: Colors.purple),
                  title: const Text('Запази в устройството'),
                  onTap: () {
                    Navigator.pop(context);
                    if (type == 'image' || type == 'video') {
                      _saveToGallery(fileUrl, type);
                    } else {
                      _saveGenericFile(fileUrl, fileName, type);
                    }
                  },
                ),

              // Share button
              ListTile(
                leading: const Icon(Icons.share, color: greenPrimary),
                title: const Text('Сподели / Препрати'),
                onTap: () {
                  Navigator.pop(context);
                  String contentToShare = messageText;
                  if (type == 'contact') contentToShare = messageText;
                  _shareMessageContent(contentToShare, fileUrl, type);
                },
              ),

              // Pin button (only for admins)
              if (_canSendMessages)
                ListTile(
                  leading: const Icon(Icons.push_pin, color: Colors.orange),
                  title: const Text('Закачи съобщение'),
                  onTap: () {
                    Navigator.pop(context);
                    String pinText = messageText;
                    if (pinText.isEmpty) {
                      if (type == 'image') pinText = '📷 Снимка';
                      else if (type == 'audio') pinText = '🎤 Гласово съобщение';
                      else if (type == 'video') pinText = '🎥 Видео';
                      else if (type == 'file') pinText = '📄 Файл';
                      else if (type == 'contact') pinText = '👤 Контакт';
                    }
                    _pinMessage(docId, pinText, type);
                  },
                ),

              if (messageText.isNotEmpty && type == 'text')
                ListTile(
                  leading: const Icon(Icons.copy, color: Colors.grey),
                  title: const Text('Копирай текста'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: messageText));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Копирано!")));
                  },
                ),
              if (isMe && type == 'text' && messageText.isNotEmpty && _canSendMessages)
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.purple),
                  title: const Text('Редактирай'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _editingMessage = {'id': docId, 'text': messageText};
                    });
                  },
                ),
              if ((isMe || _canSendMessages) && _canSendMessages)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Изтрий', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(context);

                    // Check if the message is pinned and unpin it if so
                    try {
                      final ngoDoc = await FirebaseFirestore.instance.collection('ngos').doc(widget.ngo.id).get();
                      if (ngoDoc.exists) {
                        final data = ngoDoc.data() as Map<String, dynamic>;
                        if (data.containsKey('pinnedMessage')) {
                          final pinned = data['pinnedMessage'] as Map<String, dynamic>;
                          if (pinned['id'] == docId) {
                            await FirebaseFirestore.instance.collection('ngos').doc(widget.ngo.id).update({
                              'pinnedMessage': FieldValue.delete(),
                            });
                          }
                        }
                      }
                    } catch (e) {
                      debugPrint("Error checking/unpinning message: $e");
                    }

                    if (fileUrl != null && fileUrl.isNotEmpty) {
                      try {
                        await FirebaseStorage.instance.refFromURL(fileUrl).delete();
                      } catch (e) {
                        debugPrint("Error deleting file from storage: $e");
                      }
                    }

                    FirebaseFirestore.instance.collection('ngos').doc(widget.ngo.id).collection('messages').doc(docId).delete();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _shouldShowDate(List<QueryDocumentSnapshot> docs, int index) {
    if (index == docs.length - 1) return true;
    final currentMsgTime = (docs[index]['timestamp'] as Timestamp?)?.toDate();
    final previousMsgTime = (docs[index + 1]['timestamp'] as Timestamp?)?.toDate();
    if (currentMsgTime == null || previousMsgTime == null) return false;
    return currentMsgTime.day != previousMsgTime.day;
  }

  // Build method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: _ngoStream,
          builder: (context, snapshot) {
            String title = widget.ngo.name;
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data != null && data.containsKey('name')) {
                title = data['name'];
              }
            }
            return Text(
              '$title - инфо канал', 
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          // Three dots menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (String value) {
              if (value == 'info') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PublicNgoScreen(ngo: widget.ngo),
                  ),
                );
              } else if (value == 'members') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NgoMembersScreen(ngo: widget.ngo),
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                // Info option
                const PopupMenuItem<String>(
                  value: 'info',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.black54, size: 20),
                      SizedBox(width: 12),
                      Text('Информация'),
                    ],
                  ),
                ),
                // Members option
                const PopupMenuItem<String>(
                  value: 'members',
                  child: Row(
                    children: [
                      Icon(Icons.group, color: Colors.black54, size: 20),
                      SizedBox(width: 12),
                      Text('Членове'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: _ngoStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
                  
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  if (data == null || !data.containsKey('pinnedMessage')) return const SizedBox.shrink();
                  
                  final pinned = data['pinnedMessage'] as Map<String, dynamic>;
                  final String text = pinned['text'] ?? '';

                  return Container(
                    width: double.infinity,
                    color: Colors.amber.withAlpha(50),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.push_pin, size: 18, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Закачено съобщение", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 11)),
                              Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                            ],
                          ),
                        ),
                        if (_canSendMessages)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Colors.black54),
                            onPressed: _unpinMessage,
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  );
                },
              ),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Text("Все още няма съобщения.", style: TextStyle(color: Colors.grey[400])));

                    final docs = snapshot.data!.docs;

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final isMe = data['senderId'] == _currentUid;
                        final String? fileUrl = data['fileUrl'] ?? data['imageUrl'];
                        final String type = data['type'] ?? (data['imageUrl'] != null ? 'image' : 'text');
                        
                        String msgContent = data['text'] ?? '';
                        if (type == 'contact') {
                           msgContent = "${data['contactName']} (${data['contactPhone']})";
                        }

                        Map<String, dynamic> reactions = data['reactions'] != null ? Map<String, dynamic>.from(data['reactions']) : {};

                        return Column(
                          children: [
                            if (_shouldShowDate(docs, index))
                               DateChip(date: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now()),
                            ChatBubble(
                              message: data['text'] ?? '',
                              fileUrl: fileUrl,
                              type: type,
                              fileName: data['fileName'],
                              fileSize: data['fileSize'],
                              contactName: data['contactName'],
                              contactPhone: data['contactPhone'],
                              duration: data['duration'],
                              aspectRatio: data['aspectRatio']?.toDouble(),
                              isMe: isMe,
                              isEdited: data['isEdited'] ?? false,
                              senderName: data['senderName'] ?? 'Потребител',
                              timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
                              reactions: reactions,
                              replyToName: data['replyToName'],
                              replyToText: data['replyToText'],
                              onLongPress: () => _handleMessageLongPress(
                                docs[index].id, 
                                isMe, 
                                msgContent, 
                                data['senderName'] ?? '',
                                fileUrl,
                                type,
                                reactions,
                                data['fileName']
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              
              if (_isUploading) const LinearProgressIndicator(minHeight: 2, color: greenPrimary),
 
               if (_editingMessage != null)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Container(
                       padding: const EdgeInsets.all(8),
                       decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: Colors.blue, width: 4))),
                       child: Row(children: [
                         const Icon(Icons.edit, color: Colors.blue, size: 20),
                         const SizedBox(width: 8),
                         Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                           const Text("Редактиране", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                           Text(_editingMessage!['text']!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54))
                         ])),
                         IconButton(icon: const Icon(Icons.close, size: 20, color: Colors.grey), onPressed: () => setState(() => _editingMessage = null))
                       ]),
                    ),
                  ),

               if (_canSendMessages)
                 _ChatInputArea(
                   onSendText: _handleSendText,
                   onSendAudio: _handleSendAudio,
                   onAttachmentTap: _handleAttachment,
                   editingMessage: _editingMessage?['text'],
                   replyingMessage: _replyMessage,
                   onCancelEdit: () => setState(() => _editingMessage = null),
                   onCancelReply: () => setState(() => _replyMessage = null),
                 )
               else if (_showInfoBanner)
                 Container(
                   width: double.infinity,
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                   color: Colors.white,
                   child: SafeArea(
                     child: Container(
                       padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                       decoration: BoxDecoration(
                         color: Colors.blue.shade50,
                         borderRadius: BorderRadius.circular(12),
                         border: Border.all(color: Colors.blue.shade200)
                       ),
                       child: Row(
                         crossAxisAlignment: CrossAxisAlignment.center,
                         children: [
                           Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                           const SizedBox(width: 12),
                           Expanded(
                             child: Text(
                               "Това е информационен канал. Само администраторите на организацията могат да изпращат съобщения тук.",
                               style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                             ),
                           ),
                           GestureDetector(
                             onTap: () => setState(() => _showInfoBanner = false),
                             child: Icon(Icons.close, size: 20, color: Colors.blue.shade700),
                           )
                         ],
                       ),
                     ),
                   ),
                 )
               else
                 Container(color: Colors.white, child: const SafeArea(child: SizedBox(height: 8))),
            ],
          ),

          if (_isSharing)
            Container(
              color: Colors.black.withAlpha(100),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text("Обработка...", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}

// Chat input area widget
class _ChatInputArea extends StatefulWidget {
  final Function(String) onSendText;
  final Function(String) onSendAudio;
  final Function(String) onAttachmentTap;
  final String? editingMessage;
  final Map<String, String>? replyingMessage;
  final VoidCallback? onCancelEdit;
  final VoidCallback? onCancelReply;

  const _ChatInputArea({
    required this.onSendText,
    required this.onSendAudio,
    required this.onAttachmentTap,
    this.editingMessage,
    this.replyingMessage,
    this.onCancelEdit,
    this.onCancelReply,
  });

  @override
  State<_ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<_ChatInputArea> {
  final TextEditingController _controller = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  bool _showSendButton = false;
  bool _isRecording = false;

  @override
  void didUpdateWidget(_ChatInputArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editingMessage != oldWidget.editingMessage && widget.editingMessage != null) {
      _controller.text = widget.editingMessage!;
      _showSendButton = true;
    } else if (widget.editingMessage == null && oldWidget.editingMessage != null) {
      _controller.clear();
      _showSendButton = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // Start audio recording
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory tempDir = await getTemporaryDirectory();
        final String filePath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: filePath);
        setState(() => _isRecording = true);
        HapticFeedback.mediumImpact();
      } else {
        await Permission.microphone.request();
      }
    } catch (e) {
      debugPrint("Rec Error: $e");
    }
  }

  // Stop audio recording
  Future<void> _stopRecording() async {
    try {
      final String? path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        widget.onSendAudio(path); 
      }
    } catch (e) {
      debugPrint("Stop Error: $e");
    }
  }

  // Show attachment options
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttachmentOption(icon: Icons.image, label: "Галерия", color: Colors.blue, onTap: () { Navigator.pop(ctx); widget.onAttachmentTap('gallery'); }),
              _AttachmentOption(icon: Icons.videocam, label: "Видео", color: Colors.red, onTap: () { Navigator.pop(ctx); widget.onAttachmentTap('video'); }),
              _AttachmentOption(icon: Icons.insert_drive_file, label: "Файл", color: Colors.orange, onTap: () { Navigator.pop(ctx); widget.onAttachmentTap('file'); }),
              _AttachmentOption(icon: Icons.person, label: "Контакт", color: Colors.purple, onTap: () { Navigator.pop(ctx); widget.onAttachmentTap('contact'); }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 8), 
      color: Colors.white,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyingMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(left: BorderSide(color: greenPrimary, width: 4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reply, color: greenPrimary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Отговор до ${widget.replyingMessage!['name']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: greenPrimary)),
                          Text(widget.replyingMessage!['text']!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                      onPressed: widget.onCancelReply,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    )
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
             AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: SizedBox(
                  width: _isRecording ? 0 : 48,
                  child: !_isRecording 
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.grey, size: 28),
                          onPressed: _showAttachmentOptions,
                        ),
                      )
                    : null,
                ),
              ),

              // Text input / Recording indicator
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.red.withAlpha(25) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _isRecording ? Colors.red : Colors.grey[300]!)
                  ),
                  // Recording indicator
                  child: _isRecording
                  ? const SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          Icon(Icons.fiber_manual_record, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          DefaultTextStyle(
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                            child: Text("Записване..."),
                          ),
                        ],
                      ),
                    )
                  : TextField(
                      controller: _controller,
                      maxLines: 5,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (text) {
                        final shouldShow = text.trim().isNotEmpty;
                        if (_showSendButton != shouldShow) {
                          setState(() {
                            _showSendButton = shouldShow;
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        hintText: "Напишете съобщение...",
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                ),
              ),

              const SizedBox(width: 8),

              // Send / Record button
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: GestureDetector(
                  onTap: _showSendButton 
                    ? () {
                        widget.onSendText(_controller.text.trim());
                        _controller.clear();
                        setState(() => _showSendButton = false);
                      }
                    : null,
                  
                  onLongPressStart: !_showSendButton ? (_) => _startRecording() : null,
                  onLongPressEnd: !_showSendButton ? (_) => _stopRecording() : null,

                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.red : greenPrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                         BoxShadow(color: (_isRecording ? Colors.red : greenPrimary).withAlpha(100), blurRadius: 4, offset: const Offset(0, 2))
                      ]
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          _showSendButton ? (widget.editingMessage != null ? Icons.check_circle_outline : Icons.send_rounded) : Icons.mic,
                          key: ValueKey(_showSendButton),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
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

// Attachment option widget
class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AttachmentOption({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, child: Column(mainAxisSize: MainAxisSize.min, children: [CircleAvatar(radius: 25, backgroundColor: color.withAlpha(25), child: Icon(icon, color: color, size: 28)), const SizedBox(height: 8), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))]));
  }
}
