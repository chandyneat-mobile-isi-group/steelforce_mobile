import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steelforce/features/localization/domain/entities/language_entity.dart';
import 'package:steelforce/features/localization/domain/repositories/language_repository.dart';
import 'package:steelforce/features/localization/domain/usecases/change_language.dart';
import 'package:steelforce/features/localization/domain/usecases/get_current_language.dart';
import 'package:steelforce/features/localization/domain/usecases/get_supported_languages.dart';
import 'package:steelforce/features/localization/domain/usecases/restore_saved_language.dart';
import 'package:steelforce/features/localization/presentation/bloc/language_cubit.dart';

class _MockLanguageRepository extends Mock implements LanguageRepository {}

const _english =
    LanguageEntity(code: 'en', nameKey: 'en', regionKey: 'us', flag: '🇺🇸');

void main() {
  group('LanguageCubit.changeLanguage', () {
    late _MockLanguageRepository repository;

    LanguageCubit cubit({Future<void> Function(String)? onLanguageChanged}) =>
        LanguageCubit(
          getCurrentLanguage: GetCurrentLanguage(repository),
          getSupportedLanguages: GetSupportedLanguages(repository),
          changeLanguage: ChangeLanguage(repository),
          restoreSavedLanguage: RestoreSavedLanguage(repository),
          onLanguageChanged: onLanguageChanged,
        );

    setUp(() {
      repository = _MockLanguageRepository();
      when(() => repository.getCurrentLanguage()).thenReturn(_english);
      when(() => repository.restoreSavedLanguage()).thenAnswer((_) async {});
      when(() => repository.changeLanguage(any())).thenAnswer((_) async {});
    });

    test('tells the server after the switch has landed locally', () async {
      final notified = <String>[];
      final c = cubit(onLanguageChanged: (code) async => notified.add(code));

      await c.changeLanguage('km');

      verify(() => repository.changeLanguage('km')).called(1);
      expect(c.state.languageCode, 'km');
      expect(notified, ['km']);
      await c.close();
    });

    test('never waits on the server, and a failure does not undo the switch',
        () async {
      final pending = Completer<void>();
      final c = cubit(onLanguageChanged: (_) => pending.future);

      await c.changeLanguage('km');
      expect(c.state.languageCode, 'km');

      pending.completeError(Exception('offline'));
      await pumpEventQueue();
      expect(c.state.languageCode, 'km');
      await c.close();
    });
  });
}
