import 'package:steelforce/features/localization/domain/repositories/language_repository.dart';

/// Startup restoration: re-applies the persisted language without rewriting
/// the stored preference. Called once during boot.
class RestoreSavedLanguage {
  const RestoreSavedLanguage(this._repository);
  final LanguageRepository _repository;

  Future<void> call() => _repository.restoreSavedLanguage();
}
