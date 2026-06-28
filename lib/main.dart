import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speakify/screens/splash_screen.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'theme/theme.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the native Opus codec library (required before any encode/decode).
  await opus_flutter.load();

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
