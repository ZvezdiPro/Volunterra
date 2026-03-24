import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:volunteer_app/screens/main/helper_screens/video_player_screen.dart';
import 'package:volunteer_app/screens/main/helper_screens/image_viewer_screen.dart';
import 'package:volunteer_app/shared/colors.dart';

// Main widget for displaying individual chat messages
class ChatBubble extends StatelessWidget {
  final String message;
  final String? fileUrl;
  final String type; // 'text', 'image', 'video', 'file', 'contact', 'audio'
  final String? fileName;
  final String? fileSize;
  final String? contactName;
  final String? contactPhone;
  final String? duration; // Duration for audio
  final double? aspectRatio;
  final bool isMe;
  final String senderName;
  final String? roleTag;
  final DateTime timestamp;
  
  // Fields for Reply and Reactions
  final Map<String, dynamic> reactions;
  final String? replyToName;
  final String? replyToText;
  final bool isEdited;
  
  final VoidCallback? onLongPress;
  final Function(String emoji)? onReactionTap;

  const ChatBubble({
    super.key,
    required this.message,
    this.fileUrl,
    required this.type,
    this.fileName,
    this.fileSize,
    this.contactName,
    this.contactPhone,
    this.duration,
    this.aspectRatio,
    required this.isMe,
    required this.senderName,
    this.roleTag,
    required this.timestamp,
    this.reactions = const {},
    this.replyToName,
    this.replyToText,
    this.isEdited = false,
    this.onLongPress,
    this.onReactionTap,
  });

  Future<void> _onOpenLink(LinkableElement link) async {
    final Uri url = Uri.parse(link.url);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Не може да се отвори ${link.url}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
      bottomRight: isMe ? Radius.zero : const Radius.circular(16),
    );

    return GestureDetector(
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: isMe ? greenPrimary : Colors.white,
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display reply preview if applicable
                  if (replyToName != null && replyToText != null)
                    Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.black.withAlpha(25) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(
                            color: isMe ? Colors.white70 : greenPrimary, 
                            width: 4
                          )
                        )
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            replyToName!,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isMe ? Colors.white70 : greenPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            replyToText!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isMe ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Sender name (show for all messages except when it's me)
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              senderName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.orange[800],
                              ),
                            ),
                          ),
                          if (roleTag != null) ...[
                            Builder(
                              builder: (context) {
                                final tagColor = (roleTag == 'Организатор' || roleTag == 'Официален акаунт') 
                                    ? accentAmber 
                                    : (roleTag == 'Съорганизатор' ? blueSecondary : greenPrimary);
                                return Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: tagColor.withAlpha(30),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      roleTag!,
                                      style: TextStyle(
                                        color: tagColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            ),
                          ],
                        ],
                      ),
                    ),

                  // Content based on message type
                  if (!isMe && type != 'text')
                    const SizedBox(height: 4),
                  if (type == 'audio' && fileUrl != null)
                    AudioBubble(
                      url: fileUrl!,
                      duration: duration,
                      isMe: isMe,
                    )
                  else if (type == 'video' && fileUrl != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: VideoThumbnailPlaceholder(videoUrl: fileUrl!),
                    )
                  else if (type == 'image' && fileUrl != null)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ImageViewerScreen(
                            imageUrl: fileUrl!,
                            title: senderName,
                          )
                        ));
                      },
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 400,
                            minHeight: 150,
                            minWidth: 150,
                          ),
                          child: aspectRatio != null
                              ? AspectRatio(
                                  aspectRatio: aspectRatio!,
                                  child: CachedNetworkImage(
                                    imageUrl: fileUrl!,
                                    fadeInDuration: Duration.zero,
                                    fadeOutDuration: Duration.zero,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: SizedBox(
                                          width: 30,
                                          height: 30,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: greenPrimary)
                                        )
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: Colors.grey[200],
                                      child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                    ),
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: fileUrl!,
                                  fadeInDuration: Duration.zero,
                                  fadeOutDuration: Duration.zero,
                                  placeholder: (context, url) => Container(
                                    height: 150,
                                    width: 220,
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: SizedBox(
                                        width: 30,
                                        height: 30,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: greenPrimary)
                                      )
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    height: 150,
                                    width: 220,
                                    color: Colors.grey[200],
                                    child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                  ),
                                ),
                        ),
                      ),
                    )
                  else if (type == 'file' && fileUrl != null)
                    FileBubble(
                      fileName: fileName ?? 'Документ',
                      fileSize: fileSize ?? '',
                      fileUrl: fileUrl!,
                      isMe: isMe,
                    )
                  else if (type == 'contact')
                    ContactBubble(
                      name: contactName ?? 'Неизвестен',
                      phone: contactPhone ?? '',
                      isMe: isMe,
                    ),
      
                  // Text content and timestamp
                  if (type == 'text' || (message.isNotEmpty && type != 'audio'))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.isNotEmpty)
                            Linkify(
                              onOpen: _onOpenLink,
                              text: message,
                              style: TextStyle(
                                fontSize: 15,
                                color: isMe ? Colors.white : Colors.black87,
                              ),
                              linkStyle: TextStyle(
                                color: isMe ? Colors.white : Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
      
                          const SizedBox(height: 4),

                           Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isEdited)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text(
                                    "(редактирано)",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                      color: isMe ? Colors.white.withAlpha(150) : Colors.grey[400],
                                    ),
                                  ),
                                ),
                              Text(
                                DateFormat('HH:mm').format(timestamp),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe ? Colors.white.withAlpha(180) : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                   // Timestamp for media/audio only bubbles
                   if (type != 'text' && message.isEmpty && type != 'audio')
                     Padding(
                       padding: const EdgeInsets.only(right: 12, bottom: 6, left: 6),
                       child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            DateFormat('HH:mm').format(timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe ? Colors.white.withAlpha(180) : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                     ),
                ],
              ),
            ),
          ),

          // Reactions display
          if (reactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                left: isMe ? 0 : 12, 
                right: isMe ? 12 : 0, 
                top: 2
              ),
              child: Wrap(
                spacing: 4,
                children: _buildReactionChips(),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildReactionChips() {
    final Map<String, int> counts = {};
    reactions.forEach((uid, emoji) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    });

    return counts.entries.map((entry) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
             BoxShadow(color: Colors.black12, blurRadius: 1, offset: const Offset(0,1))
          ]
        ),
        child: Text(
          "${entry.key} ${entry.value}",
          style: const TextStyle(fontSize: 11),
        ),
      );
    }).toList();
  }
}

// Audio message bubble widget
class AudioBubble extends StatefulWidget {
  final String url;
  final String? duration;
  final bool isMe;

  const AudioBubble({super.key, required this.url, this.duration, required this.isMe});

  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<AudioBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _currentPosition = p);
    });
    
    _audioPlayer.onDurationChanged.listen((d) {
       if (mounted) setState(() => _totalDuration = d);
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentPosition = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inMinutes)}:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              if (_isPlaying) {
                await _audioPlayer.pause();
              } else {
                await _audioPlayer.play(UrlSource(widget.url));
              }
            },
            child: CircleAvatar(
              radius: 20,
              backgroundColor: widget.isMe ? Colors.white.withAlpha(77) : Colors.grey[200],
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: widget.isMe ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 SliderTheme(
                   data: SliderTheme.of(context).copyWith(
                     thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                     overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                     trackHeight: 2,
                     thumbColor: widget.isMe ? Colors.white : Colors.orange,
                     activeTrackColor: widget.isMe ? Colors.white70 : Colors.orange.withAlpha(200),
                     inactiveTrackColor: widget.isMe ? Colors.white24 : Colors.grey[300],
                   ),
                   child: Slider(
                    min: 0,
                    max: _totalDuration.inSeconds > 0 ? _totalDuration.inSeconds.toDouble() : 1.0,
                    value: _currentPosition.inSeconds.toDouble().clamp(0, (_totalDuration.inSeconds > 0 ? _totalDuration.inSeconds.toDouble() : 1.0)),
                    onChanged: (val) async {
                      await _audioPlayer.seek(Duration(seconds: val.toInt()));
                    },
                  ),
                 ),
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 4),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                        Text(
                         _formatDuration(_currentPosition),
                         style: TextStyle(fontSize: 10, color: widget.isMe ? Colors.white70 : Colors.grey),
                       ),
                       Text(
                         widget.duration ?? _formatDuration(_totalDuration),
                         style: TextStyle(fontSize: 10, color: widget.isMe ? Colors.white70 : Colors.grey),
                       ),
                     ],
                   ),
                 )
              ],
            ),
          )
        ],
      ),
    );
  }
}

// (Other Widgets like ContactBubble, FileBubble, VideoThumbnailPlaceholder, DateChip remain identical)
class ContactBubble extends StatelessWidget {
  final String name;
  final String phone;
  final bool isMe;
  const ContactBubble({super.key, required this.name, required this.phone, required this.isMe});
  Future<void> _callContact() async {
    final Uri launchUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
  }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _callContact,
      child: Container(
        padding: const EdgeInsets.all(12),
        width: 220,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isMe ? Colors.white24 : Colors.grey.shade300))),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: isMe ? Colors.white24 : Colors.grey.shade200, radius: 20, child: Icon(Icons.person, color: isMe ? Colors.white : Colors.grey)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isMe ? Colors.white : Colors.black87)), Text(phone, style: TextStyle(fontSize: 12, color: isMe ? Colors.white70 : Colors.grey[600]))])),
          ],
        ),
      ),
    );
  }
}

class FileBubble extends StatelessWidget {
  final String fileName;
  final String fileSize;
  final String fileUrl;
  final bool isMe;
  const FileBubble({super.key, required this.fileName, required this.fileSize, required this.fileUrl, required this.isMe});
  Future<void> _openFile() async {
    final Uri url = Uri.parse(fileUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) throw Exception('Не може да се отвори $fileUrl');
  }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openFile,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isMe ? Colors.black.withAlpha(25) : Colors.grey[100], borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isMe ? Colors.white.withAlpha(51) : Colors.white, shape: BoxShape.circle), child: Icon(Icons.insert_drive_file, color: isMe ? Colors.white : Colors.orange, size: 24)), const SizedBox(width: 12), Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? Colors.white : Colors.black87, decoration: TextDecoration.underline)), const SizedBox(height: 4), Text(fileSize, style: TextStyle(fontSize: 11, color: isMe ? Colors.white70 : Colors.grey[600]))]))]),
      ),
    );
  }
}

class VideoThumbnailPlaceholder extends StatelessWidget {
  final String videoUrl;
  const VideoThumbnailPlaceholder({super.key, required this.videoUrl});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(videoUrl: videoUrl))); },
      child: Container(height: 160, width: double.infinity, color: Colors.black87, child: Stack(alignment: Alignment.center, children: [Icon(Icons.play_circle_fill, color: Colors.white.withAlpha(200), size: 50), Positioned(bottom: 10, child: Text("Видео", style: TextStyle(color: Colors.white.withAlpha(204), fontSize: 12)))])),
    );
  }
}

class DateChip extends StatelessWidget {
  final DateTime date;
  const DateChip({super.key, required this.date});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12)), child: Text(_formatDate(date), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)))));
  }
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    if (difference == 0 && now.day == date.day) return "ДНЕС";
    if (difference == 1 || (difference == 0 && now.day != date.day)) return "ВЧЕРА";
    return DateFormat('d MMMM y', 'bg').format(date);
  }
}