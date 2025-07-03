
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/utils/system_ui_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize system UI
  SystemUIHelper.initializeSystemUI();
  
  runApp(const IPlayerApp());
}


