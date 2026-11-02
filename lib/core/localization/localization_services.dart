import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/assets/app_assets.dart';

/// Global, reactive translation store. It's a [ChangeNotifier] so that any
/// widget can rebuild the instant the language changes — wrap a subtree in
/// [LocalizedBuilder] (which listens here) and every `.tr` inside re-evaluates
/// live, no app restart and no re-navigation required. Deliberately
/// context-free (a singleton) so the `.tr` String extension works anywhere.
class LocalizationService extends ChangeNotifier {
  // Global singleton instance so the String extension can access it context-free
  static final LocalizationService instance = LocalizationService._internal();
  LocalizationService._internal();

  /// The language every other bundle falls back to, key by key. English is
  /// the one bundle guaranteed complete — `localization_assets_test` checks
  /// every other locale against it.
  static const String fallbackLanguageCode = 'en';

  Map<String, String> _localizedStrings = {};
  Map<String, String> _fallbackStrings = {};

  /// Top-level sections of the English bundle ("auth", "products", …).
  Set<String> _namespaces = {};
  String _currentLanguageCode = fallbackLanguageCode;

  /// Keys already reported missing, so a list of 200 rows logs once.
  final Set<String> _reportedMissing = {};

  String get currentLanguageCode => _currentLanguageCode;

  /// Loads, parses, and flattens nested JSON structures from assets, then
  /// notifies listeners so the live view tree rebuilds with the new language.
  ///
  /// The English bundle is kept alongside any other language, so a key a
  /// translation has not caught up with yet reads in English instead of as
  /// "products.status.low_stock".
  Future<void> load(String languageCode) async {
    final active = await _loadBundle(languageCode);
    _use(
      languageCode,
      active,
      languageCode == fallbackLanguageCode
          ? active
          : await _loadBundle(fallbackLanguageCode),
    );
  }

  /// Installs bundles directly, so tests can exercise the fallback chain with
  /// a key one language lacks — the shipped bundles are kept complete.
  @visibleForTesting
  void debugUse(
    String languageCode, {
    required Map<String, String> active,
    required Map<String, String> fallback,
  }) =>
      _use(languageCode, active, fallback);

  void _use(
    String languageCode,
    Map<String, String> active,
    Map<String, String> fallback,
  ) {
    _currentLanguageCode = languageCode;
    _localizedStrings = active;
    _fallbackStrings = fallback;
    _namespaces = {
      for (final k in fallback.keys) k.split('.').first,
    };
    _reportedMissing.clear();
    notifyListeners();
  }

  Future<Map<String, String>> _loadBundle(String languageCode) async {
    try {
      final String jsonString = await rootBundle
          .loadString(AppDataAssets.languageBundle(languageCode));
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      final out = <String, String>{};
      _flatten(jsonMap, '', out); // Recursively flattens maps
      return out;
    } catch (e) {
      // Previously swallowed silently, which made a missing/renamed asset or
      // malformed JSON indistinguishable from "everything just falls back to
      // raw keys" with no way to tell why. Log it so a bad load is visible
      // during development instead of a mystery.
      debugPrint(
          'LocalizationService: failed to load "$languageCode.json" — $e');
      return {};
    }
  }

  // Helper method to turn nested objects into "parent.child.key" strings
  static void _flatten(
      Map<String, dynamic> jsonMap, String prefix, Map<String, String> out) {
    jsonMap.forEach((key, value) {
      final String newKey = prefix.isEmpty ? key : '$prefix.$key';
      if (value is Map<String, dynamic>) {
        _flatten(value, newKey, out);
      } else {
        out[newKey] = value.toString();
      }
    });
  }

  /// Looks up [key] in the active language, then in English.
  ///
  /// A key neither bundle has is shown as readable words from its last
  /// segment ("none_on_hand" → "None on hand") rather than as the raw key, and
  /// reported once in debug builds. Anything that is not a key — server text
  /// passed through `.tr`, a name, a number — comes back unchanged.
  String translate(String key) =>
      _localizedStrings[key] ?? _fallbackStrings[key] ?? _missing(key);

  /// [key]'s text in the active language or English, or null when neither
  /// bundle has it — for callers that pick their own fallback (an unknown
  /// server code reading as a generic message). Never compare `.tr` with its
  /// key to detect a miss: a miss reads as words, not as the key.
  String? translateOrNull(String key) =>
      _localizedStrings[key] ?? _fallbackStrings[key];

  static final _keyShape = RegExp(r'^[a-z][a-z0-9_]*(\.[a-zA-Z0-9_]+)+$');

  String _missing(String key) {
    // Only something shaped like a key in a namespace the bundles own. A
    // plain sentence, an email or a domain name must pass through as is.
    if (!_keyShape.hasMatch(key)) return key;
    if (!_namespaces.contains(key.substring(0, key.indexOf('.')))) return key;

    if (kDebugMode && _reportedMissing.add(key)) {
      debugPrint('LocalizationService: missing translation "$key"');
    }
    final words = key.substring(key.lastIndexOf('.') + 1).replaceAll('_', ' ');
    return words.isEmpty ? key : words[0].toUpperCase() + words.substring(1);
  }

  /// Like [translate], but replaces `{name}` placeholders in the resolved
  /// string with the matching value from [params]. e.g. a value of
  /// "sent to {target}" with `{'target': 'a@b.com'}` becomes
  /// "sent to a@b.com".
  String translateWithParams(String key, Map<String, dynamic> params) {
    var result = translate(key);
    params.forEach((name, value) {
      result = result.replaceAll('{$name}', '$value');
    });
    return result;
  }
}

/// THIS IS CRITICAL: This activates the 'key'.tr syntax anywhere in your project!
extension LocalizationStringExtension on String {
  String get tr => LocalizationService.instance.translate(this);

  /// This key's text, or null when no bundle has it. See
  /// [LocalizationService.translateOrNull].
  String? get trOrNull => LocalizationService.instance.translateOrNull(this);

  /// Translates this key and fills in `{name}` placeholders from [params],
  /// e.g. `'auth.verify_code_subtitle'.trParams({'target': email})`.
  String trParams(Map<String, dynamic> params) =>
      LocalizationService.instance.translateWithParams(this, params);
}
