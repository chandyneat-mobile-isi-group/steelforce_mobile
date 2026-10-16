import 'package:steelforce/core/theme/app_colors.dart';

/// Auth-screen visual tokens — kept as a small local class so the login
/// widgets stay decoupled, but every value delegates to [AppColors]
/// (lib/core/utils/colors.dart), the single source of truth for the app's
/// palette, so this can no longer drift from the main [Vibe]
/// (lib/core/utils/app_vibe.dart) — both previously declared the same hex
/// values independently.
class Vibe {
  Vibe._();

  static const bg = AppColors.background;
  static const surface = AppColors.surface;
  static const surfaceStrong = AppColors.surfaceStrong;
  static const stroke = AppColors.border;
  static const text = AppColors.textPrimary;
  static const muted = AppColors.textSecondary;

  static const violet = AppColors.primary;
  static const pink = AppColors.secondary;
  static const mint = AppColors.info;
  static const danger = AppColors.error;
  static const success = AppColors.success;

  static const radius = AppColors.radius;

  static const cta = AppColors.ctaGradient;
}
