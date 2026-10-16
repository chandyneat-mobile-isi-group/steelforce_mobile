import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/domain/entities/quotation_status.dart';
import 'package:steelforce/features/order/domain/usecases/quotation_api_usecases.dart';
import 'package:steelforce/features/order/presentation/bloc/quotation/quotation_detail_cubit.dart';
import 'package:steelforce/features/order/presentation/screens/quotation/quotation_detail_screen.dart';

class _MockGetQuotationDetail extends Mock implements GetQuotationDetail {}

class _MockSubmitQuotation extends Mock implements SubmitQuotation {}

class _MockRepriceQuotation extends Mock implements RepriceQuotation {}

class _MockCancelQuotation extends Mock implements CancelQuotation {}

class _MockGetQuotationHistory extends Mock implements GetQuotationHistory {}

QuotationDetail _detail({String status = 'Draft', String? decisionReason}) =>
    QuotationDetail(
      id: 'qt-1',
      number: 'QT-0001',
      depotId: 'dep-1',
      depotName: 'Depot One',
      status: status,
      statusGroup: QuotationStatusGroup.drafts,
      shipmentType: 'Pickup',
      currency: 'USD',
      revision: 2,
      requiredApprovalLevel: 1,
      decisionReason: decisionReason,
      validTo: DateTime(2026, 10, 31),
      lines: const [
        QuotationLineItem(
          id: 'l-1',
          lineNumber: 1,
          materialNumber: 'MAT-001',
          materialDescription: 'Steel Pipe 2in',
          quantity: 3,
          unit: 'PC',
          priceAmount: 10,
          priceCurrency: 'USD',
          pricePricingUnit: 1,
          priceConditionUnit: 'PC',
          discounts: [],
          gross: 30,
          discountTotal: 0,
          net: 30,
        ),
      ],
      totals: const QuotationTotals(
        currency: 'USD',
        gross: 30,
        discountTotal: 0,
        net: 30,
        isEstimate: false,
      ),
    );

/// Pins what the detail screen renders before it is split into widgets, so
/// the split can be shown to change nothing a rep sees.
void main() {
  late _MockGetQuotationDetail getDetail;
  late _MockGetQuotationHistory getHistory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
    registerFallbackValue(const QuotationIdParams('fallback'));
  });

  setUp(() async {
    getDetail = _MockGetQuotationDetail();
    getHistory = _MockGetQuotationHistory();
    await GetIt.instance.reset();
    GetIt.instance.registerFactory(() => QuotationDetailCubit(
          getQuotationDetail: getDetail,
          submitQuotation: _MockSubmitQuotation(),
          repriceQuotation: _MockRepriceQuotation(),
          cancelQuotation: _MockCancelQuotation(),
          getQuotationHistory: getHistory,
        ));
  });
  tearDown(() async => GetIt.instance.reset());

  void loads(QuotationDetail detail,
      {List<QuotationApprovalHistory> history = const []}) {
    when(() => getDetail(any())).thenAnswer((_) async => Success(detail));
    when(() => getHistory(any())).thenAnswer((_) async => Success(history));
  }

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light(AppTypography.latinFontFamily),
        home: screen,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a draft shows header, line, totals and the draft actions',
      (tester) async {
    loads(_detail(), history: [
      QuotationApprovalHistory(
        id: 'h-1',
        action: 'Submitted',
        createdAt: DateTime(2026, 10, 1, 9, 5),
        actorName: 'Rep A',
      ),
    ]);
    await pump(tester, const QuotationDetailScreen(quotationId: 'qt-1'));

    expect(find.text('QT-0001'), findsOneWidget);
    expect(find.text('Revision 2'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Depot One'), findsOneWidget);
    expect(find.textContaining('31/10/2026'), findsOneWidget);
    expect(find.text('Steel Pipe 2in'), findsOneWidget);
    expect(find.text('Subtotal (Gross)'), findsOneWidget);
    expect(find.text('Total Net'), findsOneWidget);
    expect(find.text('Approval Trail'), findsOneWidget);
    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('By: Rep A'), findsOneWidget);
    expect(find.text('Submit for Approval'), findsOneWidget);
    expect(find.text('Withdraw Quotation'), findsOneWidget);
    expect(find.text('Withdraw from Approval'), findsNothing);
  });

  testWidgets('a returned quotation shows the approver reason', (tester) async {
    loads(_detail(status: 'Returned', decisionReason: 'Price too low'));
    await pump(tester, const QuotationDetailScreen(quotationId: 'qt-1'));

    expect(find.text('Approver Decision Reason:'), findsOneWidget);
    expect(find.text('Price too low'), findsOneWidget);
  });

  testWidgets('pending approval offers only withdraw', (tester) async {
    loads(_detail(status: 'PendingApproval'));
    await pump(tester, const QuotationDetailScreen(quotationId: 'qt-1'));

    expect(find.text('Withdraw from Approval'), findsOneWidget);
    expect(find.text('Submit for Approval'), findsNothing);
    expect(find.text('Approval Trail'), findsNothing);
  });

  testWidgets('withdraw asks for confirmation first', (tester) async {
    loads(_detail(status: 'PendingApproval'));
    await pump(tester, const QuotationDetailScreen(quotationId: 'qt-1'));

    await tester.tap(find.text('Withdraw from Approval'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel Quotation?'), findsOneWidget);
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel Quotation?'), findsNothing);
  });

  testWidgets('an error with no local copy offers retry', (tester) async {
    when(() => getDetail(any())).thenAnswer(
        (_) async => const Failed(ServerFailure(message: 'Not found')));
    await pump(tester, const QuotationDetailScreen(quotationId: 'qt-1'));

    expect(find.text('Not found'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('an error with a local copy shows it as an offline draft',
      (tester) async {
    when(() => getDetail(any())).thenAnswer(
        (_) async => const Failed(ServerFailure(message: 'offline')));
    final local = Quotation(
      id: 'local-1',
      lines: const [],
      subtotal: 50,
      discount: 5,
      tax: 0,
      total: 45,
      status: QuotationStatus.saved,
      sapDraftStatus: 'none',
      validUntil: DateTime(2026, 11, 30),
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
      depotId: 'dep-1',
      shopName: 'Local Shop',
    );
    await pump(tester, QuotationDetailScreen(quotation: local));

    expect(find.textContaining('Local Offline Draft'), findsOneWidget);
    expect(find.text('local-1'), findsOneWidget);
    expect(find.text('Local Shop'), findsOneWidget);
    expect(find.text('saved'), findsOneWidget);
  });
}
