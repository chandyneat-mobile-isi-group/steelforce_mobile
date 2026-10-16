import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/settings/theme/domain/entities/app_theme_mode.dart';
import 'package:steelforce/features/settings/theme/domain/repositories/theme_repository.dart';
import 'package:steelforce/features/settings/theme/presentation/cubit/theme_state.dart';

/// Owns the app's theme selection. Mirrors the existing `LanguageCubit`
/// pattern: a lazy singleton, seeded synchronously from local storage in its
/// constructor, provided once above `MaterialApp` so a change rebuilds the whole
/// app with no restart.
///
/// The initial restore is synchronous (Hive reads don't await), so by the time
/// the first frame builds the correct theme is already in [state] — the app
/// never flashes the wrong theme.
class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit(this._repository) : super(const ThemeInitial()) {
    _restore();
  }

  final ThemeRepository _repository;

  /// Convenience for callers that only need the current mode.
  AppThemeMode get mode => state.mode;

  /// Restores the persisted preference. Defaults to Light on first launch and
  /// degrades gracefully to Light if storage is unreadable.
  void _restore() {
    emit(ThemeLoading(state.mode));
    try {
      emit(ThemeLoaded(_repository.getThemeMode()));
    } catch (error, stackTrace) {
      debugPrint('ThemeCubit: failed to restore theme — $error');
      debugPrintStack(stackTrace: stackTrace);
      emit(ThemeError(AppThemeMode.light, error.toString()));
    }
  }

  /// Applies and persists [mode]. Emits immediately so the UI updates before the
  /// (async) write completes; the write can't block the visual switch.
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (mode == state.mode && state is! ThemeError) return;
    emit(ThemeChanged(mode));
    try {
      await _repository.saveThemeMode(mode);
    } catch (error, stackTrace) {
      debugPrint('ThemeCubit: failed to persist theme — $error');
      debugPrintStack(stackTrace: stackTrace);
      // Keep the just-applied mode on screen; only surface the failure.
      emit(ThemeError(mode, error.toString()));
    }
  }
}
