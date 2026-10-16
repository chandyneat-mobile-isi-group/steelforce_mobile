import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/localization/domain/entities/language_entity.dart';
import 'package:steelforce/features/localization/domain/usecases/change_language.dart';
import 'package:steelforce/features/localization/domain/usecases/get_current_language.dart';
import 'package:steelforce/features/localization/domain/usecases/get_supported_languages.dart';
import 'package:steelforce/features/localization/domain/usecases/restore_saved_language.dart';

/// Presentation face of the localization feature. State stays a plain [Locale]
/// (what `MaterialApp` consumes in `app.dart`); everything else — catalog,
/// persistence, live bundle reload — goes through domain usecases so this
/// cubit never touches storage or the translation store directly.
class LanguageCubit extends Cubit<Locale> {
  LanguageCubit({
    required GetCurrentLanguage getCurrentLanguage,
    required GetSupportedLanguages getSupportedLanguages,
    required ChangeLanguage changeLanguage,
    required RestoreSavedLanguage restoreSavedLanguage,
    Future<void> Function(String languageCode)? onLanguageChanged,
  })  : _getSupportedLanguages = getSupportedLanguages,
        _changeLanguage = changeLanguage,
        _onLanguageChanged = onLanguageChanged,
        super(Locale(getCurrentLanguage().code)) {
    // Startup restoration: load the persisted bundle so `.tr` resolves before
    // the first screen renders. Async by nature (asset I/O) — LocalizedBuilder
    // repaints the moment it lands.
    restoreSavedLanguage();
  }

  final GetSupportedLanguages _getSupportedLanguages;
  final ChangeLanguage _changeLanguage;

  /// Told about every switch after it has landed locally — wired to save the
  /// rep's preferred language on the server. Fire-and-forget: the switch
  /// never waits on the network, and a failure (offline, guest) never undoes
  /// it.
  final Future<void> Function(String languageCode)? _onLanguageChanged;

  /// Display-ordered catalog for selector UIs.
  List<LanguageEntity> get supportedLanguages => _getSupportedLanguages();

  /// Hot language switch: reloads strings (every [LocalizedBuilder] rebuilds
  /// instantly), persists the choice, then emits the new [Locale] so
  /// `MaterialApp` updates locale/font.
  Future<void> changeLanguage(String languageCode) async {
    await _changeLanguage(languageCode);
    emit(Locale(languageCode));
    if (_onLanguageChanged case final notify?) {
      unawaited(notify(languageCode).catchError((Object _) {}));
    }
  }
}
