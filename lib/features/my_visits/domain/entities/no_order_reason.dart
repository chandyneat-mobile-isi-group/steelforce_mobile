import 'package:equatable/equatable.dart';

/// A reason a rep can give for checking out without an order. The list comes
/// from the server (`GET /visits/check-out-reasons`) and is cached on the
/// device so check-out works offline.
class NoOrderReason extends Equatable {
  const NoOrderReason({
    required this.code,
    required this.nameEn,
    required this.nameKm,
    required this.requiresNote,
    required this.sort,
  });

  /// What is sent. Stable; the names may change.
  final String code;
  final String nameEn;
  final String nameKm;
  final bool requiresNote;
  final int sort;

  /// The one reason that always exists, and the only one available before
  /// the list has ever been fetched. Its name comes from the app's own
  /// strings, so these are left empty.
  static const otherCode = 'other';
  static const other = NoOrderReason(
      code: otherCode, nameEn: '', nameKm: '', requiresNote: true, sort: 99);

  String name(String languageCode) {
    final km = nameKm.trim();
    if (languageCode == 'km' && km.isNotEmpty) return km;
    return nameEn;
  }

  @override
  List<Object?> get props => [code, nameEn, nameKm, requiresNote, sort];
}
