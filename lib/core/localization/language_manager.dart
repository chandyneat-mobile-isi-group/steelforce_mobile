import 'package:steelforce/core/localization/localization_services.dart';

/// Core facade over the reactive translation store.
///
/// The one place that "applies" a language to the running app: it loads the
/// `assets/lang/<code>.json` bundle into [LocalizationService], which then
/// notifies every [LocalizedBuilder] so the live tree re-renders instantly.
///
/// Widgets and blocs never touch [LocalizationService] directly for
/// *switching* — presentation goes through the localization feature's
/// usecases, whose repository ends up here. Reading (`'key'.tr`) stays on the
/// String extension, which is deliberately context-free.
class LanguageManager {
  const LanguageManager(this._service);

  final LocalizationService _service;

  /// Code of the bundle currently loaded into the UI.
  String get currentCode => _service.currentLanguageCode;

  /// Loads [code]'s bundle and notifies the UI. No persistence — that is the
  /// repository/datasource's job.
  Future<void> apply(String code) => _service.load(code);
}
