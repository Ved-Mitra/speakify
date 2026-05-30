import 'package:flutter/material.dart';
import 'package:speakify/screens/device_list_screens.dart';
import 'package:speakify/theme/theme.dart';
import 'package:speakify/utils/constants.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:speakify/models/device_role.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    // Fix 1: Scaffold should wrap SafeArea, not the other way around.
    // SafeArea is a widget that insets its child to avoid OS UI (notch, status bar).
    // It must be INSIDE the Scaffold so the Scaffold background covers the full screen.
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),

              // ── App Icon + Title (centered) ──────────────────────
              // Fix 1: Instead of AppBar (which forces leading/title layout),
              // use a simple Column to center the icon and title freely.
              Icon(
                Icons.speaker_group_rounded,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                AppConstants.appName,
                style: AppTextStyles.displayMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),

              // ── App Description (more dominant) ──────────────────
              // Fix 4: Using displaySmall instead of headlineMedium,
              // and adding a subtle primary tint to make it pop.
              Text(
                AppConstants.appDes,
                style: AppTextStyles.displaySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),

              const Spacer(),

              // ── Role Selection Cards ─────────────────────────────
              // Fix 3: Wrapping each card in InkWell for tap feedback.
              _RoleCard(
                icon: Icons.cell_tower_rounded,
                accentColor: AppColors.primary,
                title: 'Master Device',
                subtitle: 'Capture audio & broadcast',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeviceListScreen(role: DeviceRole.master),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              _RoleCard(
                icon: Icons.headphones_rounded,
                accentColor: AppColors.secondary,
                title: 'Slave Device',
                subtitle: 'Connect & listen',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeviceListScreen(role: DeviceRole.slave),
                    ),
                  );
                },
              ),

              const Spacer(),

              // ── Footer ───────────────────────────────────────────
              const FootNote(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// A reusable, tappable role selection card.
///
/// Fix 2 & 3: Proper padding, Row layout with icon | text | arrow,
/// and wrapped in Material + InkWell for ripple effect.
class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Material is needed as an ancestor for InkWell's ripple to render.
    // We set color to transparent because the Container below handles the background.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        // splashColor controls the ripple color when you tap.
        splashColor: accentColor.withValues(alpha: 0.1),
        // highlightColor controls the sustained press color.
        highlightColor: accentColor.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: const GradientBoxBorder(
              gradient: AppColors.cardGradient,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          // Fix 2: Row layout — Icon | Text Column | Spacer | Arrow
          child: Row(
            children: [
              // Left icon in a subtle circular container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.headlineSmall),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              // Arrow pushed to far right
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textDisabled,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FootNote extends StatelessWidget {
  const FootNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [Text('v1.0.0', style: AppTextStyles.labelSmall)],
    );
  }
}
