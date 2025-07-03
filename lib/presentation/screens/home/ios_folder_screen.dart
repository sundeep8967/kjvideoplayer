import 'package:flutter/material.dart';
import '../../../data/models/video_model.dart';
import '../../widgets/ios_video_thumbnail.dart';

class IOSFolderScreen extends StatelessWidget {
  final String folderName;
  final List<VideoModel> videos;
  final Function(String, String) onVideoTap;

  const IOSFolderScreen({
    super.key,
    required this.folderName,
    required this.videos,
    required this.onVideoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        foregroundColor: const Color(0xFF007AFF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              folderName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF000000),
              ),
            ),
            Text(
              '${videos.length} video${videos.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: videos.isEmpty
          ? _buildEmptyState()
          : GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return IOSVideoThumbnail(
                  video: video,
                  onTap: () => onVideoTap(video.path, video.displayName),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64,
            color: Color(0xFF8E8E93),
          ),
          SizedBox(height: 16),
          Text(
            'No videos in this folder',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF3C3C43),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}