import 'package:flutter/material.dart';

/// Speakify color palette — dark-mode-first with vibrant accents.
///
/// The palette is inspired by audio waveforms and neon studio lighting:
/// deep charcoal backgrounds, electric cyan primary, warm amber accents.
class AppColors {
  AppColors._();

  // ── Background & Surface ──────────────────────────────────────────
  static const Color background = Color(0xFF0D0D12);
  static const Color surface = Color(0xFF16161F);
  static const Color surfaceVariant = Color(0xFF1E1E2A);
  static const Color surfaceElevated = Color(0xFF252536);

  // ── Primary (Electric Cyan) ───────────────────────────────────────
  static const Color primary = Color(0xFF00E5FF);
  static const Color primaryDark = Color(0xFF00B8D4);
  static const Color primaryLight = Color(0xFF80F0FF);
  static const Color primaryContainer = Color(0xFF003640);

  // ── Secondary (Warm Amber / Gold) ─────────────────────────────────
  static const Color secondary = Color(0xFFFFAB40);
  static const Color secondaryDark = Color(0xFFFF9100);
  static const Color secondaryLight = Color(0xFFFFD180);
  static const Color secondaryContainer = Color(0xFF3D2E00);

  // ── Accent (Vivid Violet) ─────────────────────────────────────────
  static const Color accent = Color(0xFFB388FF);
  static const Color accentDark = Color(0xFF7C4DFF);
  static const Color accentLight = Color(0xFFD1C4E9);

  // ── Semantic ──────────────────────────────────────────────────────
  static const Color success = Color(0xFF69F0AE);
  static const Color error = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFD740);
  static const Color info = Color(0xFF40C4FF);

  // ── Text ──────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFB0B0C0);
  static const Color textDisabled = Color(0xFF606070);

  // ── Borders & Dividers ────────────────────────────────────────────
  static const Color border = Color(0xFF2A2A3A);
  static const Color divider = Color(0xFF1F1F2F);

  // ── Gradients ─────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accentDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [surface, surfaceVariant],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
