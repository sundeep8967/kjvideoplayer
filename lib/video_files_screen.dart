// video_files_screen.dart
import 'dart:io';
import 'package:file_manager/file_manager.dart';
import 'package:flutter/material.dart';
import 'video_player_screen.dart';
import 'nextplayer_video_player.dart';

// Updated Screen to Display Only Video Files
class FolderContentsScreen extends StatelessWidget {
  final String folderPath;
  final List<String> videoExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv'];

  FolderContentsScreen({required this.folderPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Files'),
      ),
      body: FutureBuilder<List<FileSystemEntity>>(
        future: _getVideoFiles(folderPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final videoFiles = snapshot.data!;
            if (videoFiles.isEmpty) {
              return Center(child: Text('No video files found.'));
            }
            return ListView.builder(
              itemCount: videoFiles.length,
              itemBuilder: (context, index) {
                final file = videoFiles[index];
                return ListTile(
                  leading: Icon(Icons.video_file),
                  title: Text(FileManager.basename(file)),
                  subtitle: FutureBuilder<FileStat>(
                    future: file.stat(),
                    builder: (context, statSnapshot) {
                      if (statSnapshot.hasData) {
                        final size = statSnapshot.data!.size;
                        return Text("Size: ${FileManager.formatBytes(size)}");
                      }
                      return Text("");
                    },
                  ),
                  onTap: () {
                    final videoTitle = FileManager.basename(file);
                    _showPlayerSelectionDialog(context, file.path, videoTitle);
                  },
                );
              },
            );
          } else {
            return Center(child: Text('No video files found.'));
          }
        },
      ),
    );
  }

  // Method to fetch only video files from a folder
  Future<List<FileSystemEntity>> _getVideoFiles(String path) async {
    final directory = Directory(path);
    final entities = await directory.list().toList();
    print('72 sundeep $entities');
    return entities.where((entity) {
      if (FileManager.isFile(entity)) {
        final extension = entity.path.split('.').last.toLowerCase();
        return videoExtensions.any((ext) => entity.path.toLowerCase().endsWith(ext));
      }
      return false; // Exclude directories
    }).toList();
  }

  void _showPlayerSelectionDialog(BuildContext context, String videoPath, String videoTitle) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Video Player'),
          content: const Text('Select your preferred video player:'),
          actions: [
            // PRIMARY OPTION - NextPlayer (RECOMMENDED)
            Container(
              width: double.maxFinite,
              margin: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.video_library, size: 28),
                label: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'NextPlayer',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'RECOMMENDED - ExoPlayer Based',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NextPlayerVideoPlayer(
                        videoPath: videoPath,
                        videoTitle: videoTitle,
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // ALTERNATIVE OPTIONS
            const Divider(thickness: 1),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Alternative Players:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            
            // Original Player
            TextButton.icon(
              icon: const Icon(Icons.play_circle_outline, color: Colors.grey),
              label: const Text('Original Player'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomVideoPlayer(
                      videoPath: videoPath,
                      videoTitle: videoTitle,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// Modify the ListTile onTap in the Main Screen

