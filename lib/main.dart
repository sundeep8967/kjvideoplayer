
import 'package:flutter/material.dart';
import 'package:flutterapp7/PermissionTestScreen.dart';
import 'firstscreen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
       debugShowCheckedModeBanner: false,
      title: 'Folders App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FoldersScreen(),
    );
  }
}


