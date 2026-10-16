import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/notifications/local/local_notification_presenter.dart';
import 'package:steelforce/core/notifications/push/push_messaging_service.dart';
import 'package:steelforce/features/notification/data/remote/api_notification_remote_data_source.dart';
import 'package:steelforce/features/notification/data/remote/mock_notification_remote_data_source.dart';
import 'package:steelforce/features/notification/data/remote/notification_remote_data_source.dart';
import 'package:steelforce/features/notification/notification_injection.dart';
import 'package:steelforce/features/order/data/mock/demo_material_selection_remote_data_source.dart';
import 'package:steelforce/features/order/data/mock/demo_pricing_remote_data_source.dart';
import 'package:steelforce/features/order/data/mock/demo_quotation_remote_data_source.dart';
import 'package:steelforce/features/order/data/remote/api_material_selection_remote_data_source.dart';
import 'package:steelforce/features/order/data/remote/material_selection_remote_data_source.dart';
import 'package:steelforce/features/order/data/remote/pricing_remote_data_source.dart';
import 'package:steelforce/features/order/data/remote/quotation_remote_data_source.dart';
import 'package:steelforce/features/order/order_injection.dart';

/// Which remote sources the two feature registrars select.
///
/// Run twice to cover both builds:
///
/// ```
/// flutter test test/features/order/data/mock/demo_mode_injection_test.dart
/// flutter test --dart-define=USE_MOCK_DATA=true \
///   test/features/order/data/mock/demo_mode_injection_test.dart
/// ```
void main() {
  late GetIt sl;
  late AppDatabase db;

  setUp(() async {
    sl = GetIt.asNewInstance();
    db = AppDatabase(NativeDatabase.memory());
    sl.registerSingleton<AppDatabase>(db);
    sl.registerSingleton<AppLogger>(const ConsoleAppLogger(verbose: false));
    if (DataSourceMode.useMocks) {
      sl.registerSingleton<DemoNetwork>(DemoNetwork());
    } else {
      // Constructing a client sends nothing; the sources are only resolved.
      sl.registerSingleton<Dio>(Dio());
    }
    await registerOrderFeature(sl);
    registerNotificationFeature(sl);
  });

  tearDown(() => db.close());

  test('demo build selects demo sources and the push no-ops', () {
    expect(
        sl<QuotationRemoteDataSource>(), isA<DemoQuotationRemoteDataSource>());
    expect(sl<PricingRemoteDataSource>(), isA<DemoPricingRemoteDataSource>());
    expect(sl<MaterialSelectionRemoteDataSource>(),
        isA<DemoMaterialSelectionRemoteDataSource>());
    expect(sl<NotificationRemoteDataSource>(),
        isA<MockNotificationRemoteDataSource>());
    expect(sl<PushMessagingService>().isSupported, isFalse);
    expect(sl<LocalNotificationPresenter>().runtimeType.toString(),
        'NoopLocalNotificationPresenter');
  }, skip: DataSourceMode.useLiveApi ? 'live build' : false);

  test('live build keeps the API sources', () {
    expect(sl.isRegistered<DemoNetwork>(), isFalse);
    expect(
        sl<QuotationRemoteDataSource>(), isA<ApiQuotationRemoteDataSource>());
    expect(sl<PricingRemoteDataSource>(), isA<ApiPricingRemoteDataSource>());
    expect(sl<MaterialSelectionRemoteDataSource>(),
        isA<ApiMaterialSelectionRemoteDataSource>());
    expect(sl<NotificationRemoteDataSource>(),
        isA<ApiNotificationRemoteDataSource>());
  }, skip: DataSourceMode.useMocks ? 'demo build' : false);
}
