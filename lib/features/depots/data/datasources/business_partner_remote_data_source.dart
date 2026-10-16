// =============================================================================
// business_partner_remote_data_source.dart
//
// The single network call for SAP BP registration.
//
// Replaced the three-call server-draft protocol (`POST draft`, `POST update`,
// `POST submit`). That protocol needed a `serverDraftId` before the rep could
// type anything, so the wizard's first action was a network call and the
// primary button stayed disabled until it returned — which meant a rep with no
// signal could not even start the form.
//
// With one write there is no id to obtain and no reason to be online before
// submit. `AddDepotBloc` is now local state until the rep taps send.
// =============================================================================

import 'package:dio/dio.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/logging/debug_trace.dart';
import 'package:steelforce/core/network/transport/request_reach.dart';
import 'package:steelforce/features/depots/data/models/business_partner_request_model.dart';
import 'package:steelforce/features/depots/data/models/business_partner_response_model.dart';

abstract class BusinessPartnerRemoteDataSource {
  Future<BusinessPartnerResponseModel> createBusinessPartner(
    BusinessPartnerRequestModel request,
  );
}

/// Console tracer for the registration HTTP call. Debug builds only; field
/// names are traced, never their values.
const _trace = DebugTrace('registration');

class BusinessPartnerRemoteDataSourceImpl
    implements BusinessPartnerRemoteDataSource {
  const BusinessPartnerRemoteDataSourceImpl(this._client);

  /// The authed client from `core/network/`. Base URL, auth header and the
  /// redacting logger come from there; nothing about credentials belongs here.
  final Dio _client;

  static const String endpoint = '/api/v1/mobile/depots/business-partner';

  /// SAP BP creation runs synchronously through the middleware and regularly
  /// takes longer than a list fetch. The default client timeout is tuned for
  /// reads, and inheriting it means the rep sees a timeout for a registration
  /// that SAP went on to complete — the worst outcome available, because the
  /// obvious response is to try again and create a duplicate.
  static const Duration _writeTimeout = Duration(seconds: 60);

  /// Keys in the documented request body. See
  /// `BusinessPartnerRequestModel.toJson`.
  static const int _expectedFieldCount = 47;

  @override
  Future<BusinessPartnerResponseModel> createBusinessPartner(
    BusinessPartnerRequestModel request,
  ) async {
    final payload = request.toJson();

    // The wire contract is 47 fields and the server drops keys it does not
    // recognise without complaining, so a payload that has lost some is
    // accepted and reaches SAP incomplete. Traced rather than thrown: the
    // count is a smoke alarm for a bad merge, not a reason to block a rep
    // standing in a shop.
    if (payload.length != _expectedFieldCount) {
      _trace.warn('http', 'payload field count changed', {
        'sent': payload.length,
        'expected': _expectedFieldCount,
      });
    }

    try {
      final response = await _client.post<dynamic>(
        endpoint,
        data: payload,
        options: Options(
          receiveTimeout: _writeTimeout,
          sendTimeout: _writeTimeout,
          // Non-2xx is handled below rather than thrown as a transport error,
          // because this endpoint returns SAP's return table on 400 too and
          // that table is the only place the reason is written.
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final data = response.data;
      if (data is! Map) {
        throw ServerException(
          message: 'Unexpected response shape from $endpoint',
          statusCode: response.statusCode,
        );
      }

      final body = Map<String, dynamic>.from(data);
      final result = BusinessPartnerResponseModel.fromJson(body);

      // The shape of a *successful* response, traced whenever the parse comes
      // back without a handle on the record.
      //
      // A tolerant parser fails silently: every field resolves to empty and
      // the log says only that nothing was found, which is indistinguishable
      // from the server having sent nothing. Two rounds of guessing at these
      // key names cost more than this call does — the names are what settles
      // it, so they are printed once, on the path where it matters.
      if (!result.isAccepted) {
        _trace.warn('http', 'response not understood', {
          'top': DebugTrace.names(body.keys.map((k) => k.toString())),
          'parsed': DebugTrace.names(result.receivedKeys),
          'status_field': result.status.name,
        });
      }

      // A 4xx with no parseable message would otherwise surface as a silent
      // success with an empty depot number.
      final status = response.statusCode ?? 200;
      if (status >= 400 && !result.hasError) {
        throw ServerException(
          message: 'Registration rejected by the server',
          statusCode: status,
        );
      }

      return result;
    } on DioException catch (e) {
      // Thrown as distinct exception *types*, not one type with a readable
      // message. The caller has to tell "nothing was sent" from "sent, no
      // answer" to decide whether a retry is safe, and deciding that by
      // matching on message text breaks the first time the wording changes.
      switch (e.type) {
        case DioExceptionType.connectionError:
          // Not always "never sent". dio raises this for a connection dropped
          // *after* the body went out (`Connection closed before full header
          // was received`), and a browser raises it for every failure. Only a
          // socket that never connected proves SAP saw nothing; anything else
          // takes the may-have-landed path below, because the offline queue
          // resends a "never sent" registration automatically.
          if (neverReachedServer(e.error)) {
            throw NetworkException(message: _describe(e));
          }
          throw ServerException(message: _describe(e), statusCode: 504);

        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
          // Nothing complete reached SAP. Safe to retry as-is.
          throw NetworkException(message: _describe(e));

        case DioExceptionType.receiveTimeout:
          // The request went out and the answer never came, so the write may
          // have landed. 504 is the honest code for that and is what
          // distinguishes this case downstream — a blind retry here is how
          // one shop becomes two partners.
          throw ServerException(message: _describe(e), statusCode: 504);

        default:
          // Null status, not a sentinel: inventing one ('000', 0) makes a
          // transport failure look like a server response further up.
          throw ServerException(
            message: _describe(e),
            statusCode: e.response?.statusCode,
          );
      }
    }
  }

  /// Turns a Dio failure into something a rep can act on.
  ///
  /// The timeout cases are named explicitly because the action differs: on a
  /// send timeout nothing reached SAP and retrying is safe, while on a receive
  /// timeout the write may have landed and the rep should check the depot
  /// list before re-submitting.
  String _describe(DioException e) {
    final serverMessage = e.response?.data;
    if (serverMessage is Map) {
      final m = serverMessage['message'] ?? serverMessage['error'];
      if (m != null && m.toString().isNotEmpty) return m.toString();
    }
    return switch (e.type) {
      DioExceptionType.sendTimeout ||
      DioExceptionType.connectionTimeout =>
        'Could not reach the server. Nothing was submitted.',
      DioExceptionType.receiveTimeout =>
        'The server did not answer in time. Check the depot list before '
            'submitting again.',
      DioExceptionType.connectionError =>
        'No connection. The registration will be sent when you are back '
            'online.',
      _ => e.message ?? 'Registration failed',
    };
  }
}
