import 'package:steelforce/features/localization/domain/repositories/language_repository.dart';

/// Switches the app language: applies the new translation bundle to the live
/// UI and persists the choice so it survives restarts.
class ChangeLanguage {
  const ChangeLanguage(this._repository);
  final LanguageRepository _repository;

  Future<void> call(String code) => _repository.changeLanguage(code);
}
