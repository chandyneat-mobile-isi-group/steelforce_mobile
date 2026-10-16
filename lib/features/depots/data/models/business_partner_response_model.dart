// =============================================================================
// business_partner_response_model.dart
//
// Parses the response of `POST /api/v1/mobile/depots/business-partner`.
//
// Written to accept several shapes rather than one. The endpoint is a
// passthrough over a BAPI, and passthroughs are inconsistent about whether the
// number comes back as `DepotNumber`, `depotNumber` or
// `BusinessPartner`, and whether the return table is `Return`, `messages` or
// absent on success. Reading a small set of aliases costs a few lines here and
// saves a release when the middleware is adjusted; the alternative — a strict
// parser — turns a successful registration into an unparseable response and
// the rep re-registers a shop that already exists.
//
// Note the asymmetry with the request model: the request is exact because we
// own what we send, the response is tolerant because we do not own what we get.
// =============================================================================

import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_result.dart';

class SapReturnMessageModel extends SapReturnMessage {
  const SapReturnMessageModel({
    required super.type,
    required super.message,
    super.id,
    super.number,
    super.field,
  });

  factory SapReturnMessageModel.fromJson(DataMap json) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return '';
    }

    return SapReturnMessageModel(
      type: SapMessageType.fromCode(pick(['TYPE', 'Type', 'type', 'severity'])),
      message: pick([
        'MESSAGE',
        'Message',
        'message',
        'MESSAGE_V1',
        'text',
      ]),
      id: pick(['ID', 'Id', 'id', 'MESSAGE_CLASS']),
      number: pick(['NUMBER', 'Number', 'number', 'MESSAGE_NUMBER']),
      field: pick(['FIELD', 'Field', 'field', 'FIELDNAME']),
    );
  }

  /// A message we synthesise when the server reports failure in prose instead
  /// of a return table — so the bloc has one place to read errors from.
  factory SapReturnMessageModel.error(String message) =>
      SapReturnMessageModel(type: SapMessageType.error, message: message);
}

class BusinessPartnerResponseModel extends BusinessPartnerResult {
  const BusinessPartnerResponseModel({
    super.depotNumber,
    super.partnerNumber,
    super.localId,
    super.status,
    super.submittedToSap,
    super.messages,
    this.receivedKeys = const [],
  });

  /// The top-level keys of the parsed body, for diagnostics only.
  ///
  /// Carried because the failure mode of a tolerant parser is silence: every
  /// field resolves to empty and the log says nothing about why. Traced by the
  /// repository when a response cannot be interpreted.
  final List<String> receivedKeys;

  factory BusinessPartnerResponseModel.fromJson(DataMap json) {
    // Unwrap one level of envelope if there is one. `core/network/` already
    // strips the standard `{ data: ... }` wrapper, but this endpoint has been
    // seen returning `{ result: ... }`, and unwrapping twice is harmless while
    // not unwrapping at all yields a result with every field empty.
    DataMap body = json;
    for (final key in const ['data', 'result', 'payload']) {
      final inner = body[key];
      if (inner is Map) {
        body = Map<String, dynamic>.from(inner);
        break;
      }
    }

    String pick(List<String> keys) {
      for (final k in keys) {
        final v = body[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return '';
    }

    final rawMessages = <SapReturnMessage>[];
    for (final key in const ['Return', 'RETURN', 'messages', 'Messages']) {
      final table = body[key];
      if (table is List) {
        rawMessages.addAll(
          table.whereType<Map>().map(
                (m) => SapReturnMessageModel.fromJson(
                  Map<String, dynamic>.from(m),
                ),
              ),
        );
        break;
      }
    }

    // A bare `message` alongside `success: false` is the other way this
    // endpoint reports trouble. Promote it so `hasError` is true either way.
    final success = body['success'];
    final flatMessage = pick(['message', 'Message', 'error']);
    if (rawMessages.isEmpty && flatMessage.isNotEmpty && success == false) {
      rawMessages.add(SapReturnMessageModel.error(flatMessage));
    }

    // `depotCode` first, and `depot_code` after it. This endpoint's
    // documented success shape is `{depotCode, sapStatus, depotId}` —
    // see `CreateBpResponse` in `data/remote/depot_datasources.dart`, which
    // has been parsing this same route all along. Looking only for
    // `DepotNumber` is why a successful submit came back with nothing.
    final depotNumber = pick([
      'DepotNumber',
      'customerNumber',
      'customerCode',
      'depot_code',
      'DepotCode',
      'Depot',
      'KUNNR',
    ]).trim();

    return BusinessPartnerResponseModel(
      depotNumber: depotNumber,
      partnerNumber: pick([
        'BusinessPartner',
        'businessPartner',
        'PartnerNumber',
        'partnerNumber',
        'PARTNER',
      ]),
      // Exists as soon as the record is stored, with or without a SAP number.
      localId: pick([
        'customerId',
        'depot_id',
        'DepotId',
        'localId',
        'local_id',
        'id',
      ]).trim(),
      status: BpSubmissionStatus.fromCode(
        pick(['sapStatus', 'sap_status', 'SapStatus', 'status', 'Status']),
      ),
      // Absent means "we asked it to, and nothing said otherwise" — the flag
      // is echoed inconsistently, and defaulting to false would show every
      // successful registration as parked for review.
      submittedToSap: switch (body['submitToSap'] ?? body['submittedToSap']) {
        final bool v => v,
        final String v => v.toLowerCase() == 'true',
        _ => depotNumber.isNotEmpty,
      },
      // Keys are surfaced so a shape change shows up in the log as the field
      // names actually received, rather than as a result with everything
      // empty and no way to tell why.
      receivedKeys: body.keys.map((k) => k.toString()).toList(growable: false),
      messages: rawMessages,
    );
  }

  /// Note on the depot number: SAP pads it to ten characters
  /// (`0000123456`) and it is kept exactly as received. The padded form is the
  /// key in SAP, so stripping the zeros would produce an id that fails the
  /// next lookup.
}
