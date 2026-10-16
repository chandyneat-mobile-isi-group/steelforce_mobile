import 'package:equatable/equatable.dart';
import 'package:steelforce/features/settings/theme/domain/entities/app_theme_mode.dart';

/// State for [ThemeCubit].
///
/// Every state carries the [mode] currently in effect, so consumers (chiefly
/// `MaterialApp`) can render from any state without special-casing. The
/// distinct subtypes model the lifecycle the spec calls for — initial, loading,
/// loaded, changed, error — while keeping a single readable `mode` field.
sealed class ThemeState extends Equatable {
  const ThemeState(this.mode);

  final AppThemeMode mode;

  @override
  List<Object?> get props => [mode];
}

/// Before the saved preference has been read. Defaults to Light so the very
/// first frame is never the wrong theme.
final class ThemeInitial extends ThemeState {
  const ThemeInitial() : super(AppThemeMode.light);
}

/// Transient — the saved preference is being restored.
final class ThemeLoading extends ThemeState {
  const ThemeLoading(super.mode);
}

/// The saved preference has been restored and applied.
final class ThemeLoaded extends ThemeState {
  const ThemeLoaded(super.mode);
}

/// The user changed the theme; [mode] is the newly-applied selection.
final class ThemeChanged extends ThemeState {
  const ThemeChanged(super.mode);
}

/// A load or save failed. [mode] holds the last-known-good theme still in
/// effect, so the UI keeps rendering correctly despite the error.
final class ThemeError extends ThemeState {
  const ThemeError(super.mode, this.message);

  final String message;

  @override
  List<Object?> get props => [mode, message];
}
