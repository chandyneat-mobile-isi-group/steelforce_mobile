import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/utils/money.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/depot_stop_information.dart';

/// Parses `GET /mobile/depots/{id}/stop-information`.
///
/// Kept apart from [DepotApiMapper] on purpose. The two payloads describe the
/// same outlet but do not agree on how absence is spelled — this one uses
/// `null` where the route sync uses `''` — and the backend notice is explicit
/// that they must not share a parser.
abstract final class DepotStopInformationMapper {
  /// The envelope's `data` object: `{ customer, financial }`.
  ///
  /// `customer`, not `depot`: the route says depot because that is the business
  /// word, and the payload keeps SAP's word because renaming response fields
  /// would have been a wire break (ADR-0007).
  static DepotStopInformation fromData(DataMap data) {
    final outlet = (data['customer'] as Map?)?.cast<String, dynamic>();
    final financial = (data['financial'] as Map?)?.cast<String, dynamic>();

    return DepotStopInformation(
      outlet: _outlet(outlet ?? const {}),
      credit: _credit(financial ?? const {}),
    );
  }

  static DepotOutletProfile _outlet(DataMap json) => DepotOutletProfile(
        id: json['id']?.toString() ?? '',
        code: _string(json['code']),
        name: _string(json['name']),
        // Blank-to-null as well as null-to-null: a server that ever sends `''`
        // must not produce an "empty Khmer name" that renders as a gap.
        nameKh: _nullIfBlank(json['nameKh']),
        contact: _nullIfBlank(json['contact']),
        phone: _string(json['phone']),
        address: _string(json['address']),
        telegram: _nullIfBlank(json['telegram']),
        outletType: _string(json['outletType']),
      );

  static DepotCreditProfile _credit(DataMap json) {
    // One currency per outlet, carried at the top level; the money objects
    // each carry their own, and this is only the fallback for a malformed one.
    final currency = _nullIfBlank(json['currency']) ?? 'USD';

    return DepotCreditProfile(
      creditLimit:
          Money.fromJson(json['creditLimit'], fallbackCurrency: currency),
      creditBalance:
          Money.fromJson(json['creditBalance'], fallbackCurrency: currency),
      // Read, never recomputed from limit − balance.
      availableCredit:
          Money.fromJson(json['availableCredit'], fallbackCurrency: currency),
      currency: currency,
      creditLimitDate: parseUtc(json['creditLimitDate']),
      paymentTermCode: _nullIfBlank(json['paymentTermCode']),
      paymentTermLabel: _nullIfBlank(json['paymentTermLabel']),
      paymentTermDays: (json['paymentTermDays'] as num?)?.toInt(),
    );
  }

  /// Any scalar as text, `''` when absent. SAP codes and phone numbers are
  /// digits, and a server that ever sends one as a JSON number must not throw
  /// the whole profile away.
  static String _string(Object? raw) => raw?.toString() ?? '';

  /// Null for absent *and* for empty, so callers have one case to handle.
  static String? _nullIfBlank(Object? raw) {
    if (raw == null) return null;
    final value = raw.toString().trim();
    return value.isEmpty ? null : value;
  }
}
