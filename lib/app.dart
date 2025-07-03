import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'presentation/screens/home/ios_video_home_screen.dart';
import 'core/theme/app_theme.dart';

class IPlayerApp extends StatelessWidget {
  const IPlayerApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'I Player',
      theme: AppTheme.lightTheme,
      //darkTheme: AppTheme.darkTheme,
      //themeMode: ThemeMode.system,
      home: const IOSVideoHomeScreen(),
    );
  }
}