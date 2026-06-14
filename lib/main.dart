import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speakify/screens/splash_screen.dart';
import 'theme/theme.dart';
import 'utils/constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait orientation for consistent audio-sync UX.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const SpeakifyApp());
}

class SpeakifyApp extends StatelessWidget {
  const SpeakifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
