import 'package:flutter/material.dart';
import '../../data/models/video_model.dart';
import '../../core/constants/app_constants.dart';
import 'video_card.dart';

class VideoGrid extends StatelessWidget {
  final List<VideoModel> videos;
  final Function(VideoModel) onVideoTap;
  final VoidCallback? onRefresh;
  final bool showLastPlayed;

  const VideoGrid({
    super.key,
    required this.videos,
    required this.onVideoTap,
    this.onRefresh,
    this.showLastPlayed = false,
  });

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        onRefresh?.call();
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: AppConstants.defaultPadding,
          mainAxisSpacing: AppConstants.defaultPadding,
        ),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          return VideoCard(
            video: video,
            onTap: () => onVideoTap(video),
            showLastPlayed: showLastPlayed,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: AppConstants.defaultPadding),
          Text(
            'No videos found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppConstants.smallPadding),
          Text(
            'Pull down to refresh and scan for videos',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.largePadding),
          if (onRefresh != null)
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Scan for Videos'),
            ),
        ],
      ),
    );
  }
}