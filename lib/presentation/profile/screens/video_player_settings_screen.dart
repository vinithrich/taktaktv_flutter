import 'package:flutter/material.dart';
import '../../../core/constants/app_constant.dart';
import '../../player/screens/player_screen.dart';
import '../../../../core/utils/video_quality_manager.dart';

class VideoPlayerSettingsScreen extends StatefulWidget {
  const VideoPlayerSettingsScreen({super.key});

  @override
  State<VideoPlayerSettingsScreen> createState() => _VideoPlayerSettingsScreenState();
}

class _VideoPlayerSettingsScreenState extends State<VideoPlayerSettingsScreen> {
  final List<Map<String, String>> qualities = [
    {"label": "Auto (Recommended)", "key": "Auto"},
    {"label": "1080p | Full HD", "key": "1080p"},
    {"label": "720p | HD", "key": "720p"},
    {"label": "480p | SD", "key": "480p"},
    {"label": "360p | Data saver mode", "key": "360p"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0710),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Video Player Settings', style: TextStyle(color: Colors.white, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: qualities.length,
        itemBuilder: (context, index) {
          final q = qualities[index];
          final isSelected = VideoQualityManager.selectedQuality == q['key'];

          return RadioListTile<String>(
            title: Text(q['label']!, style: const TextStyle(color: Colors.white, fontSize: 15)),
            value: q['key']!,
            groupValue: VideoQualityManager.selectedQuality,
            activeColor: const Color(0xFFE6007A),
            onChanged: (val) {
              setState(() {
                VideoQualityManager.selectedQuality = val!;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Video quality set to ${q['label']}'), duration: const Duration(seconds: 1)),
              );
            },
          );
        },
      ),
    );
  }
}