import 'dart:io';
import 'package:file_manager/file_manager.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'video_files_screen.dart';
import 'package:device_info_plus/device_info_plus.dart';

class FoldersScreen extends StatefulWidget   {
  @override
  _FoldersScreenState createState() => _FoldersScreenState();
}
class _FoldersScreenState extends State<FoldersScreen> with WidgetsBindingObserver {
    bool _hasPermission = false; // Track permission status

final FileManagerController controller = FileManagerController();
final List<String> videoExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv'];
 @override
  void initState() {
    super.initState();
      print('-FoldersScreen initState called');
  WidgetsBinding.instance.addObserver(this); // Add the observer

    _checkAndRequestStoragePermission(); // <-- REQUEST PERMISSION HERE
  }
@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this); // Remove the observer
  super.dispose();
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    // Re-check permissions when the app resumes
        if (!_hasPermission) {

_checkAndRequestStoragePermission1();
        }
  }
}
   Future<void> _checkAndRequestStoragePermission1() async {
 final deviceInfo =await DeviceInfoPlugin().androidInfo;
        var videoPermissionStatus = await Permission.videos.status;
 if(deviceInfo.version.sdkInt>32){
     if (videoPermissionStatus.isGranted ) {
      setState(() {
        _hasPermission = true;
      });
    } else {
      setState(() {
        _hasPermission = false;
      });
    }
 }else{
      var videoPermissionStatus = await Permission.storage.status;
     if (videoPermissionStatus.isGranted ) {
      setState(() {
        _hasPermission = true;
      });
    } else {
      setState(() {
        _hasPermission = false;
      });
    }
 }
  }
   
   Future<void> _checkAndRequestStoragePermission() async {
    bool permissionStatus;
 final deviceInfo =await DeviceInfoPlugin().androidInfo;
print('-------------------------->>>..>>>>>>>>');
 if(deviceInfo.version.sdkInt>32){
      permissionStatus = await Permission.videos.request().isGranted;
    }else{
      permissionStatus = await Permission.storage.request().isGranted;

    }
     if (permissionStatus) {
      setState(() {
        _hasPermission = true; // Update the state to reflect granted permissions
      });
    } else {
      // Optionally, handle the case when permission is denied
      // For example, show a dialog or a message to the user

      setState(() {
        _hasPermission = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Storage permissionn is required to access folders.'),
        ),
      );
    }
  }
@override
Widget build(BuildContext context) {

  return WillPopScope(
     onWillPop: () async {
        final currentPath = controller.getCurrentPath;
        final parentDirectory = Directory(currentPath).parent.path;

        // If we are not in the root directory, navigate to the parent directory and filter for video folders
        if (parentDirectory != currentPath) {
          // Fetch video folders in the parent directory
          final parentEntities = await Directory(parentDirectory).list().toList();
          final videoFolders = await findVideoFoldersRecursive(parentEntities);

          if (videoFolders.isNotEmpty) {
            controller.openDirectory(Directory(parentDirectory));
            // Show only video folders in the parent directory
            setState(() {
              // Manually update the entity list to only show video folders
              // You could also call a method to refresh the list of video folders
            });
            return false; // Prevent the default back button behavior
          }
        }

        // Allow default back button behavior if at the root directory or no video folders in parent
        return true;
      },
  child : Scaffold(
    appBar: AppBar(
      title: Text('Ford'),
      actions: [
        IconButton(
          icon: Icon(Icons.search),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.grid_view),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.person),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.create_new_folder_outlined),
          onPressed: () => createFolder(context),
        ),
        IconButton(
          icon: Icon(Icons.sort_rounded),
          onPressed: () => sort(context),
        ),
      ],
    ),
    body: _hasPermission
            ? Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            spacing: 8.0,
            children: [
              _buildChip('Music', Icons.music_note),
              _buildChip('Privacy', Icons.lock),
              _buildChip('MXShare', Icons.share),
              _buildChip('Video', Icons.videocam),
            ],
          ),
        ),
        
        Expanded(
        
         child: FileManager(
  controller: controller,
  builder: (context, snapshot) {
    final List<FileSystemEntity> entities = snapshot;
    print('sundeep ${controller.getCurrentPath}');
    // If we're in root directory, show only video folders
    if (controller.getCurrentPath == Directory('/storage/emulated/0').path) {
      return FutureBuilder<List<FileSystemEntity>>(
        future: findVideoFoldersRecursive(entities),
        builder: (context, futureSnapshot) {
          if (futureSnapshot.hasData) {
            final videoFolders = futureSnapshot.data!;
            return buildEntityList(videoFolders);
          }
          return Center(child: CircularProgressIndicator());
        }
      );
    }else{
      print('103 error');
    }
    
    // If we're inside a folder, show all contents
    return buildEntityList(entities);
  }
),
        ),
      ],
    ):Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0), // Adds horizontal padding for better readability
        child: Text(
          'Storage permission is required to access folders. Please grant permission.',
          textAlign: TextAlign.center, // Centers text horizontally within the Text widget
          style: TextStyle(
            fontSize: 16.0, // Optional: Adjusts font size for better visibility
          ),
        ),
      ),
      SizedBox(height: 20), // Adds space between the text and the button
      ElevatedButton(
          onPressed: () {
            openAppSettings();
          },
        child: Text('Open Settings'),
      ),
    ],
                ),
  ),
  ));
}
Widget buildEntityList(List<FileSystemEntity> entities) {
  return ListView.builder(
    itemCount: entities.length,
    itemBuilder: (context, index) {
      FileSystemEntity entity = entities[index];
      return Card(
        child: ListTile(
          leading: FileManager.isFile(entity) 
              ? Icon(Icons.feed_outlined) 
              : Icon(Icons.folder),
          title: Text(FileManager.basename(entity)),
          subtitle: subtitle(entity),
          onTap: () {
             if (FileManager.isDirectory(entity)) {
              // Navigate to the new screen and pass the folder path
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FolderContentsScreen(folderPath: entity.path),
                ),
              );
            } else {
              print("Tapped file: ${entity.path}");
            }
          },
        ),
      );
    },
  );
}

Future<List<FileSystemEntity>> findVideoFoldersRecursive(List<FileSystemEntity> entities) async {
  final List<FileSystemEntity> videoFolders = [];

  try {
    for (final entity in entities) {
      print('152 sundeep $entity');
      if (FileManager.isDirectory(entity)) {
        try {
          // List all files and subdirectories in the current directory (non-recursive)
          final subEntities = await Directory(entity.path).list(recursive: false).toList();
   print('156 sundeep $subEntities');
          // Check if this directory contains any video files
          final containsVideo = subEntities.any((subEntity) =>
              FileManager.isFile(subEntity) &&
              videoExtensions.any((ext) => subEntity.path.toLowerCase().endsWith(ext)));

          // Add the folder if it contains video files
          if (containsVideo) {
            print('Found video folder: ${entity.path}');
            videoFolders.add(entity);
          }

          // Recursively check subdirectories
          videoFolders.addAll(await findVideoFoldersRecursive(subEntities));
        } catch (e) {
          print('Error accessing directory ${entity.path}: $e');
        }
      }
    }
  } catch (e) {
    print('Error processing entities: $e');
  }

  print('Folders with videos: $videoFolders');
  return videoFolders;
}

Widget subtitle(FileSystemEntity entity) {
  return FutureBuilder<FileStat>(
    future: entity.stat(),
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        if (entity is File) {
          int size = snapshot.data!.size;
          return Text("${FileManager.formatBytes(size)}");
        }
        return Text("${snapshot.data!.modified}".substring(0, 10));
      } else {
        return Text("");
      }
    },
  );
}

Widget _buildChip(String label, IconData icon) {
  return Chip(
    label: Text(label),
    avatar: Icon(icon, size: 20.0),
  );
}

Future<void> createFolder(BuildContext context) async {
  TextEditingController folderNameController = TextEditingController();
  
  showDialog(
    context: context,
    builder:(context) => Dialog(
      child : Container(
        padding : EdgeInsets.all(10),
        child : Column (
          mainAxisSize : MainAxisSize.min,
          children : [
            ListTile (
              title : TextField (
                controller : folderNameController,
                decoration : InputDecoration(hintText : "Enter folder name"),
              ),
            ),
            ElevatedButton (
              onPressed : () async {
                try {
                  await FileManager.createFolder(controller.getCurrentPath, folderNameController.text);
                  controller.openDirectory(Directory('${controller.getCurrentPath}/${folderNameController.text}'));
                } catch (e) {
                  print("Error creating folder $e");
                }
                Navigator.pop(context);
              },
              child : Text('Create Folder'),
            )
          ],
        ),
      ),
    ),
  );
}

void sort(BuildContext context) async {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Container(
        padding: EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text("Name"), onTap: () { controller.sortBy(SortBy.name); Navigator.pop(context); }),
            ListTile(title: Text("Size"), onTap: () { controller.sortBy(SortBy.size); Navigator.pop(context); }),
            ListTile(title: Text("Date"), onTap: () { controller.sortBy(SortBy.date); Navigator.pop(context); }),
            ListTile(title: Text("Type"), onTap: () { controller.sortBy(SortBy.type); Navigator.pop(context); }),
          ],
        ),
      ),
    ),
  );
}
}
