
import 'package:flutter/material.dart';
import 'package:flutterapp7/PermissionTestScreen.dart';
import 'ui_improvements/enhanced_home_screen.dart';
import 'ui_improvements/modern_theme.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Modern Video Player',
      theme: ModernTheme.lightTheme,
      home: EnhancedHomeScreen(),
    );
  }
}


