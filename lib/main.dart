import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  SharedPreferences? preferences;
  try {
    preferences = await SharedPreferences.getInstance();
  } catch (error) {
    debugPrint('Device storage unavailable, the theme won’t be remembered: $error');
  }

  runApp(TartLejenApp(preferences: preferences));
}
