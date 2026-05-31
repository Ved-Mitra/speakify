import 'package:flutter/material.dart';
import 'package:speakify/screens/home_screen.dart';
import 'package:speakify/theme/app_colors.dart';
import 'package:speakify/theme/app_text_styles.dart';
import 'package:speakify/utils/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _sizeController;
  late AnimationController _glowController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _sizeAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _sizeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );
    _sizeAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _sizeController, curve: Curves.easeOutCubic),
    );
    _glowAnimation = Tween<double>(begin: 8.0, end: 30.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _sizeController.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const HomeScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _sizeController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // FIX: Expanded pushes the content to fill available space.
          // The Center widget inside then vertically + horizontally centers it.
          Expanded(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _sizeAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _glowAnimation,
                        builder: (context, child) {
                          return Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              // FIX: boxShadow expects a List<BoxShadow>, not a single one.
                              // Use [BoxShadow(...)] with square brackets.
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  // FIX: blurRadius expects a double, not an Animation.
                                  // Use _glowAnimation.value to get the current double.
                                  blurRadius: _glowAnimation.value,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: child,
                          );
                        },
                        // The icon doesn't change, so pass it as `child`
                        // for performance — AnimatedBuilder won't rebuild it.
                        child: Icon(
                          Icons.speaker_group_rounded,
                          color: AppColors.primary,
                          size: 72,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        AppConstants.appName,
                        style: AppTextStyles.displayMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Listen Together',
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Progress bar at the very bottom
          LinearProgressIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceVariant,
            minHeight: 2,
          ),
        ],
      ),
    );
  }
}
