import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionTestScreen extends StatefulWidget {
  @override
  _PermissionTestScreenState createState() => _PermissionTestScreenState();
}

class _PermissionTestScreenState extends State<PermissionTestScreen> {
  bool _isPermissionGranted = false;
  bool _isRequesting = false;
  final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();

  @override
  void initState() {
    super.initState();
    _checkInitialPermission();
  }

  // Check permission status when the widget initializes
  Future<void> _checkInitialPermission() async {
    try {
      debugPrint('Checking initial storage permission...');
      if (await _isStoragePermissionGranted()) {
        debugPrint('Storage permission already granted');
        setState(() {
          _isPermissionGranted = true;
        });
      } else {
        debugPrint('Storage permission not granted yet');
        setState(() {
          _isPermissionGranted = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking initial permission: $e');
    }
  }

  Future<bool> _isStoragePermissionGranted() async {
    if (!Platform.isAndroid) {
      return false; // Handle iOS or other platforms if necessary
    }

    var androidInfo = await deviceInfoPlugin.androidInfo;
    String versionRelease = androidInfo.version.release;
    int androidVersion = int.parse(versionRelease.split('.').first);

    PermissionStatus statusPhotos;
    PermissionStatus statusVideos;

    if (androidVersion >= 33) { // Android 13 (API level 33) and above
      statusPhotos = await Permission.photos.status;
      statusVideos = await Permission.videos.status;

      if (statusPhotos.isDenied) {
        statusPhotos = await Permission.photos.request();
      }

      if (statusVideos.isDenied) {
        statusVideos = await Permission.videos.request();
      }

      return statusPhotos.isGranted && statusVideos.isGranted;
    } else { // For Android versions below 13
      var status = await Permission.storage.status;
      if (status.isDenied) {
        status = await Permission.storage.request();
      }

      return !status.isPermanentlyDenied && status.isGranted;
    }
}


  // Method to handle permission request on button click
  Future<void> _handlePermissionRequest() async {
    setState(() {
      _isRequesting = true; // Show loading indicator
    });

    try {
      bool isGranted = await _isStoragePermissionGranted();
      if (isGranted) {
        debugPrint('Storage permission granted');
        setState(() {
          _isPermissionGranted = true;
        });
      } else {
        debugPrint('Storage permission denied');
        _showPermissionDeniedDialog();
        setState(() {
          _isPermissionGranted = false;
        });
      }
    } catch (e) {
      debugPrint('Error during permission request: $e');
    } finally {
      setState(() {
        _isRequesting = false; // Hide loading indicator
      });
    }
  }

  // Dialog to guide users to app settings if permission is permanently denied
  void _showPermissionDeniedDialog() {
    debugPrint('Showing permission denied dialog');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permission Required'),
        content: Text(
            'Storage access is required to access photos and videos. Please grant permission to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // Optional: Show rationale before requesting permission
  Future<bool> _shouldShowRequestPermissionRationale() async {
    if (!Platform.isAndroid) return false;

    var androidInfo = await deviceInfoPlugin.androidInfo;
    String versionRelease = androidInfo.version.release;
    int androidVersion = int.parse(versionRelease.split('.').first);

    if (androidVersion >= 13) {
      return await Permission.photos.shouldShowRequestRationale || 
             await Permission.videos.shouldShowRequestRationale;
    } else {
      return await Permission.storage.shouldShowRequestRationale;
    }
  }
                                    

  @override
  Widget build(BuildContext context) {

 

    return Scaffold(
      appBar: AppBar(
        title: Text('Permission Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _isPermissionGranted
                ? Text(
                    'Storage Permission Granted',
                    style: TextStyle(color: Colors.green, fontSize: 16),
                  )
                : Text(
                    'Storage Permission Not Granted',
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
            SizedBox(height: 20),
            _isRequesting
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _isRequesting
                        ? null
                        : () async {
                            // Optional: Show rationale if needed
                            if (await _shouldShowRequestPermissionRationale()) {
                              bool? proceed = await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Permission Needed'),
                                  content: Text(
                                      'This app needs storage access to display your photos and videos.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () async{
                                      
                                     
 bool permissionStatus;
 final deviceInfo =await DeviceInfoPlugin().androidInfo;

 if(deviceInfo.version.sdkInt>32){
      permissionStatus = await Permission.videos.request().isGranted;
    }else{
      permissionStatus = await Permission.storage.request().isGranted;

    }


                                       },
                                      
                                      child: Text('Continue'),
                                    ),
                                  ],
                                ),
                              );

                              if (proceed != true) return;
                            }

                            _handlePermissionRequest();
                          },
                    child: Text('Request Storage Permission'),
                  ),
          ],
        ),
      ),
    );
  }
}
    requestPerm() async{
                                          var status = await Permission.storage.request();
                                          if(status.isGranted){
                                            debugPrint('Permission Granted');
                                          }
                                          else if(status.isDenied){
                                            debugPrint('Permission Denied');
                                        }else if(status.isPermanentlyDenied){
                                          
                                        }}
                                        
