import 'package:flutter/foundation.dart';

// TODO(release-gate): integration logging for the depot-draft routes — delete
// this file and its call sites once the routes are verified end to end. Every
// entry point is a no-op outside debug builds.

/// Console blocks for every depot-draft call: request, response, error.
///
/// Filter the debug console on `Feature : Depot`. Personal data is masked
/// before printing (security.md §3): names and the search terms built from
/// them, phones, email, street, remarks, notes, coordinates, the credit
/// limit, file names and the signed file links show as `***`. Codes, ids,
/// statuses and the reference lists print in full.
abstract final class DepotDraftDebugLog {
  static void request(
    String method,
    String url, {
    Map<String, dynamic>? params,
    Object? body,
  }) {
    if (!kDebugMode) return;
    debugPrint('''
========== API REQUEST ==========
Feature : Depot
Method  : $method
URL     : $url
Params  : ${params ?? {}}${body == null ? '' : '\nBody    : ${mask(body)}'}
=================================
''');
  }

  static void response(String method, String url, int? status, Object? data) {
    if (!kDebugMode) return;
    debugPrint('''
========== API RESPONSE ==========
Feature : Depot
Method  : $method
URL     : $url
Status  : $status
Data    : ${mask(data)}
==================================
''');
  }

  static void error(String method, String url, Object error, StackTrace stack,
      {int? status, Object? data}) {
    if (!kDebugMode) return;
    debugPrint('''
========== API ERROR ==========
Feature : Depot
Method  : $method
URL     : $url
Status  : ${status ?? '-'}
Error   : $error${data == null ? '' : '\nData    : ${mask(data)}'}
Stack   : $stack
===============================
''');
  }

  /// Keys whose values identify a person, a place or a private link.
  static const Set<String> _private = {
    'nameEn',
    'nameKh',
    'nameKm',
    'name',
    'telephone',
    'mobilePhone',
    'faxNumber',
    'phoneNumber',
    'email',
    'street',
    'remarks',
    'note',
    'originalFileName',
    'url',
    'thumbnailUrl',
    'latitude',
    'longitude',
    // Built from the shop's name, so it names the shop as well.
    'searchTerm1',
    'searchTerm2',
    // Money, which security.md §3 keeps out of logs like a name.
    'creditLimit',
  };

  /// A copy of [value] with every private key's value replaced by `***`.
  ///
  /// Lists of `{code, name}` pick-list options are kept as they are: a SAP
  /// list name ("Phnom Penh (ISI)") is reference data, not a person.
  static Object? mask(Object? value, {bool inOptionList = false}) =>
      switch (value) {
        final Map<dynamic, dynamic> map => {
            for (final e in map.entries)
              e.key: _private.contains('${e.key}') &&
                      !(inOptionList && e.key == 'name') &&
                      e.value != null
                  ? '***'
                  : mask(e.value),
          },
        final List<dynamic> list => [
            for (final item in list) mask(item, inOptionList: _isOption(item)),
          ],
        _ => value,
      };

  /// `{code, name}` and nothing else: one SAP pick-list value.
  static bool _isOption(Object? item) =>
      item is Map &&
      item.length == 2 &&
      item.containsKey('code') &&
      item.containsKey('name');
}
