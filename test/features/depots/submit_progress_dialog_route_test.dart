import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/depots/domain/entities/depot_submit_progress.dart';
import 'package:steelforce/features/depots/presentation/widgets/depot_submit_progress_dialog.dart';

/// The dialog **as a route**, not as a widget.
///
/// ## Why this file exists separately
///
/// `depot_submit_progress_test.dart` renders the dialog directly, so it
/// never crosses a route boundary — and that is exactly the bug it missed:
/// `showDialog` builds its child from a context on the Navigator's overlay,
/// which sits *above* the `BlocProvider` the create screen supplies. A
/// `BlocBuilder` in there finds no provider and throws
/// `ProviderNotFoundException` the moment a rep presses Send.
///
/// A widget test that pumps the leaf can never catch that. This one pushes the
/// route the way the app does.
class _FakeProgressCubit extends Cubit<DepotSubmitProgress> {
  _FakeProgressCubit() : super(const DepotSubmitProgress());

  void advance(DepotSubmitProgress next) => emit(next);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  late _FakeProgressCubit cubit;

  setUp(() => cubit = _FakeProgressCubit());
  tearDown(() => cubit.close());

  /// Mirrors the sheet: a provider **below** the Navigator, and a dialog
  /// pushed onto it. Without the hand-across, the builder cannot see the
  /// provider — which is the whole point of the test.
  Future<void> pumpAndOpen(
    WidgetTester tester, {
    required bool handAcrossTheBloc,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        home: BlocProvider<_FakeProgressCubit>.value(
          value: cubit,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    final bloc = context.read<_FakeProgressCubit>();
                    showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      routeSettings: const RouteSettings(
                          name: DepotSubmitProgressDialog.routeName),
                      builder: (_) {
                        final child = BlocBuilder<_FakeProgressCubit,
                            DepotSubmitProgress>(
                          builder: (_, p) =>
                              DepotSubmitProgressDialog(progress: p),
                        );
                        return handAcrossTheBloc
                            ? BlocProvider<_FakeProgressCubit>.value(
                                value: bloc, child: child)
                            : child;
                      },
                    );
                  },
                  child: const Text('send'),
                ),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('send'));
    // Explicit pumps, not pumpAndSettle: the active stage renders a
    // CircularProgressIndicator, which never stops animating, so settling is
    // impossible by construction.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('the dialog opens and reads the bloc across the route',
      (tester) async {
    await pumpAndOpen(tester, handAcrossTheBloc: true);

    expect(tester.takeException(), isNull);
    expect(find.byType(DepotSubmitProgressDialog), findsOneWidget);
    expect(find.text('Checking the form'), findsOneWidget);
  });

  testWidgets('it keeps updating as the submit advances', (tester) async {
    await pumpAndOpen(tester, handAcrossTheBloc: true);

    cubit.advance(const DepotSubmitProgress(
      stage: SubmitStage.uploadingPhotos,
      photosSent: 2,
      photosTotal: 4,
    ));
    await tester.pump();

    // Proves the dialog is genuinely wired to the live bloc rather than
    // holding the snapshot it opened with.
    expect(find.text('Uploading photos (2 of 4)'), findsOneWidget);
  });

  testWidgets('without the hand-across it throws — the bug this guards',
      (tester) async {
    await pumpAndOpen(tester, handAcrossTheBloc: false);

    // Documents the failure precisely: the provider is genuinely out of scope
    // on the overlay, so `BlocProvider.value` is load-bearing, not ceremony.
    expect(tester.takeException(), isNotNull);
  });

  testWidgets('popping by route name leaves the screen beneath it',
      (tester) async {
    await pumpAndOpen(tester, handAcrossTheBloc: true);
    final context = tester.element(find.byType(DepotSubmitProgressDialog));

    Navigator.of(context).popUntil(
        (route) => route.settings.name != DepotSubmitProgressDialog.routeName);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(DepotSubmitProgressDialog), findsNothing);
    // The sheet must survive: popping the wrong route would drop the rep's
    // whole form after a successful registration.
    expect(find.text('send'), findsOneWidget);
  });
}
