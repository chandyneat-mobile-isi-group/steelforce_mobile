import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/depots/domain/entities/pending_depot_registration.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_registration_outbox.dart';
import 'package:steelforce/features/depots/presentation/bloc/depot_registration_queue_cubit.dart';
import 'package:steelforce/features/depots/presentation/widgets/sync/pending_depot_registrations_section.dart';
import 'package:mocktail/mocktail.dart';

class _MockOutbox extends Mock implements DepotRegistrationOutbox {}

PendingDepotRegistration _item(
  String name,
  DepotRegistrationQueueStatus status,
  int minute,
) =>
    PendingDepotRegistration(
      id: name,
      depotName: name,
      status: status,
      createdAt: DateTime.utc(2026, 10, 5, 8, minute),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  Future<void> pump(
    WidgetTester tester,
    List<PendingDepotRegistration> items,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final outbox = _MockOutbox();
    when(outbox.watchAll).thenAnswer((_) => Stream.value(items));
    final cubit = DepotRegistrationQueueCubit(
      outbox: outbox,
      syncNow: () async => true,
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BlocProvider.value(
                value: cubit,
                child: const PendingDepotRegistrationsSection(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String position(int n, int of) =>
      'Number $n of $of in line. Depots send one at a time, oldest first.';

  testWidgets('waiting registrations show their place in line', (tester) async {
    await pump(tester, [
      _item('A', DepotRegistrationQueueStatus.queued, 1),
      _item('B', DepotRegistrationQueueStatus.needsReview, 2),
      _item('C', DepotRegistrationQueueStatus.queued, 3),
      _item('D', DepotRegistrationQueueStatus.queued, 4),
    ]);

    // Only the three waiting to send are counted; the row needing the rep is
    // not in line.
    expect(find.text(position(1, 3)), findsOneWidget);
    expect(find.text(position(2, 3)), findsOneWidget);
    expect(find.text(position(3, 3)), findsOneWidget);
  });

  testWidgets('a lone waiting registration shows no place in line',
      (tester) async {
    await pump(tester, [
      _item('A', DepotRegistrationQueueStatus.queued, 1),
      _item('B', DepotRegistrationQueueStatus.rejected, 2),
    ]);

    expect(find.textContaining('in line'), findsNothing);
  });
}
