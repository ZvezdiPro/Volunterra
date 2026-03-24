import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// Screen for playing video content using Chewie
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  // Controllers for video playback and UI interface
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  // Sets up the video player and Chewie interface
  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    await _videoPlayerController.initialize();

    setState(() {
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        optionsTranslation: OptionsTranslation(
          playbackSpeedButtonText: 'Скорост на възпроизвеждане',
          subtitlesButtonText: 'Субтитри',
          cancelButtonText: 'Отказ',
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(errorMessage, style: const TextStyle(color: Colors.white)),
          );
        },
      );
    });
  }

  @override
  void dispose() {
    // Clean up resources to prevent memory leaks
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          // Show loading indicator until video is ready
          child: _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
              ? Theme(
                  data: Theme.of(context).copyWith(
                    listTileTheme: const ListTileThemeData(
                      iconColor: Colors.black,
                      textColor: Colors.black,
                      titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
                      subtitleTextStyle: TextStyle(fontSize: 14, color: Colors.black87),
                      minVerticalPadding: 16.0,
                    ),
                    textTheme: Theme.of(context).textTheme.copyWith(
                      titleMedium: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w500), 
                      bodyLarge: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w500),
                    ),
                  ),
                  child: Chewie(controller: _chewieController!),
                )
              : const CircularProgressIndicator(),
        ),
      ),
    );
  }
}