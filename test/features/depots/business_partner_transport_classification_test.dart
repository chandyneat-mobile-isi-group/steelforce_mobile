import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/features/depots/data/datasources/business_partner_remote_data_source.dart';
import 'package:steelforce/features/depots/data/models/business_partner_request_model.dart';

/// The registration endpoint takes no idempotency key, and the offline queue
/// resends a "never sent" registration automatically. So the data source's
/// one job here is to call "never sent" only what provably was: anything else
/// must take the may-have-landed path (504), or one shop becomes two business
/// partners in SAP.
class _ThrowingAdapter implements HttpClientAdapter {
  _ThrowingAdapter(this.fail);

  final DioException Function(RequestOptions) fail;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      throw fail(options);

  @override
  void close({bool force = false}) {}
}

BusinessPartnerRequestModel _request() => BusinessPartnerRequestModel.fromJson({
      'Name1': 'Toul Kork Yard',
      'SalesOrg': '0002',
      'DistributionChannel': '10',
      'Division': '10',
      'Country': 'KH',
      'PersonnelNumber': '1001',
    });

Future<Object> _failureFor(
    DioException Function(RequestOptions) failWith) async {
  final dio = Dio()..httpClientAdapter = _ThrowingAdapter(failWith);
  try {
    await BusinessPartnerRemoteDataSourceImpl(dio)
        .createBusinessPartner(_request());
  } catch (e) {
    return e;
  }
  throw TestFailure('expected a failure');
}

void main() {
  test('a socket that never connected is "never sent"', () async {
    final e = await _failureFor((o) => DioException.connectionError(
          requestOptions: o,
          reason: 'refused',
          error: const SocketException('Connection refused'),
        ));
    expect(e, isA<NetworkException>());
  });

  test('a connection dropped after the body went out may have landed',
      () async {
    final e = await _failureFor((o) => DioException.connectionError(
          requestOptions: o,
          reason: 'Connection closed before full header was received',
          error: const HttpException('Connection closed before full header was '
              'received'),
        ));
    expect(e, isA<ServerException>());
    expect((e as ServerException).statusCode, 504);
  });

  test('a connect timeout is "never sent"', () async {
    final e = await _failureFor((o) => DioException.connectionTimeout(
          requestOptions: o,
          timeout: const Duration(seconds: 5),
        ));
    expect(e, isA<NetworkException>());
  });

  test('a receive timeout may have landed', () async {
    final e = await _failureFor((o) => DioException.receiveTimeout(
          requestOptions: o,
          timeout: const Duration(seconds: 60),
        ));
    expect(e, isA<ServerException>());
    expect((e as ServerException).statusCode, 504);
  });
}
