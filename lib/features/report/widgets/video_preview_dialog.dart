import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoPreviewDialog extends StatefulWidget {
  final String url;
  final String? localPath;
  const VideoPreviewDialog({super.key, required this.url, this.localPath});

  @override
  State<VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<VideoPreviewDialog> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (widget.localPath != null) {
      _videoController = VideoPlayerController.file(File(widget.localPath!));
    } else {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    }
    await _videoController.initialize();
    
    if (mounted) {
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoController,
          autoPlay: true,
          looping: false,
          aspectRatio: _videoController.value.aspectRatio,
          errorBuilder: (context, errorMessage) {
            return Center(child: Text(errorMessage, style: const TextStyle(color: Colors.white)));
          },
        );
      });
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
       backgroundColor: Colors.black,
       insetPadding: EdgeInsets.zero,
       child: Stack(
         alignment: Alignment.center,
         children: [
           if (_chewieController != null)
             Chewie(controller: _chewieController!)
           else
             const CircularProgressIndicator(color: Colors.white),
           Positioned(
             top: 40,
             right: 20,
             child: IconButton(
               icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
               onPressed: () => Navigator.of(context).pop(),
             ),
           ),
         ],
       ),
    );
  }
}
