// video_files_screen.dart
import 'dart:io';
import 'package:file_manager/file_manager.dart';
import 'package:flutter/material.dart';
import 'video_player_screen.dart';

// Updated Screen to Display Only Video Files
class FolderContentsScreen extends StatelessWidget {
  final String folderPath;
  final List<String> videoExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv'];

  FolderContentsScreen({required this.folderPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Videoo Files'),
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
                    final videoTitle = FileManager.basename(file); // 
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CustomVideoPlayer(videoPath: file.path,videoTitle: videoTitle),
    ),
  );},
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
}

// Modify the ListTile onTap in the Main Screen

