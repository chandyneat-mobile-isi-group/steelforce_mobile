import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/depots/data/remote/depot_stop_information_remote_data_source.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

/// The stop screen's banner can only leave "loading" if every outcome of the
/// fetch comes back as a result — a parse error that escapes as a `TypeError`
/// leaves it spinning for good.
void main() {
  late _MockDio dio;
  late ApiDepotStopInformationRemoteDataSource source;

  setUp(() {
    dio = _MockDio();
    source = ApiDepotStopInformationRemoteDataSource(dio);
  });

  void answer(Object? body) {
    when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 200,
        data: body as Map<String, dynamic>?,
      ),
    );
  }

  test('a documented body parses', () async {
    answer({
      'success': true,
      'data': {
        'customer': {'id': 'd1', 'code': '6100000123', 'name': 'Outlet'},
        'financial': {'currency': 'USD'},
      },
    });

    final info = await source.fetch('d1');

    expect(info.outlet.code, '6100000123');
  });

  test('a body in the wrong shape becomes a ServerException, not a TypeError',
      () async {
    answer({
      'success': true,
      'data': {'customer': 'not-an-object'},
    });

    await expectLater(source.fetch('d1'), throwsA(isA<ServerException>()));
  });

  test('a missing payload is still a ServerException', () async {
    answer({'success': true});

    await expectLater(source.fetch('d1'), throwsA(isA<ServerException>()));
  });

  test('an HTTP error becomes an ApiException carrying the status', () async {
    final options = RequestOptions(path: '/x');
    when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: options, statusCode: 403),
    ));

    await expectLater(
      source.fetch('d1'),
      throwsA(isA<ApiException>()
          .having((e) => e.error.statusCode, 'statusCode', 403)),
    );
  });
}
