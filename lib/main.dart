import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
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
      home: const HomeScreen(),
    );
  }
}

/// Temporary placeholder until the Home Screen is built (Phase 0, Step 3).
// class _PlaceholderHome extends StatelessWidget {
//   const _PlaceholderHome();

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return Scaffold(
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.speaker_group_rounded,
//               size: 72,
//               color: AppColors.primary,
//             ),
//             const SizedBox(height: 24),
//             Text(
//               AppConstants.appName,
//               style: theme.textTheme.displayMedium?.copyWith(
//                 color: AppColors.primary,
//                 fontWeight: FontWeight.w800,
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Multi-device audio sync',
//               style: theme.textTheme.bodyLarge?.copyWith(
//                 color: AppColors.textSecondary,
//               ),
//             ),
//             const SizedBox(height: 48),
//             Text(
//               '🚧  Home screen coming next  🚧',
//               style: theme.textTheme.bodyMedium,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
