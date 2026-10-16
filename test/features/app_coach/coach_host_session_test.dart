import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/shared/animations/coach_mascot.dart';
import 'package:mocktail/mocktail.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_status.dart';
import 'package:steelforce/features/app_coach/presentation/blocs/app_coach_bloc.dart';
import 'package:steelforce/features/app_coach/presentation/widgets/app_coach_host.dart';
import 'package:steelforce/features/authentication/domain/entities/user.dart';
import 'package:steelforce/features/authentication/domain/entities/user_role.dart';
import 'package:steelforce/features/shell/presentation/bloc/home_cubit.dart';

class _MockCoachBloc extends MockBloc<AppCoachEvent, AppCoachState>
    implements AppCoachBloc {}

/// The coach — overlay and the paused Lottie assistant — belongs to the
/// signed-in shell only. Its bloc is an app-wide singleton whose state
/// survives sign-out, so without this gate the paused assistant floated over
/// the guest landing's Sign In button.
void main() {
  late _MockCoachBloc bloc;
  late SessionManager session;
  late ShellTabController tabs;

  const paused = AppCoachState(
    status: CoachStatus.paused,
    steps: [],
    index: -1,
    completedStepIds: {},
  );

  const rep = User(
    id: 'u-1',
    email: 'rep@isigroup.com.kh',
    fullName: 'Sok Dara',
    roles: {UserRole.salesRep},
  );

  setUp(() async {
    await sl.reset();
    bloc = _MockCoachBloc();
    whenListen(bloc, const Stream<AppCoachState>.empty(), initialState: paused);
    sl.registerSingleton<AppCoachBloc>(bloc);
    tabs = ShellTabController();
    sl.registerSingleton(tabs);
    session = SessionManager();
  });

  tearDown(() async {
    session.dispose();
    await sl.reset();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        home: Stack(children: [
          Positioned.fill(child: AppCoachHost(session: session)),
        ]),
      ));

  testWidgets('a guest never sees the assistant', (tester) async {
    await pump(tester);

    expect(find.byType(CoachMascot), findsNothing);
    verifyNever(() => bloc.add(const CoachStarted()));
  });

  testWidgets('signing in shows it and starts the coach', (tester) async {
    await pump(tester);

    session.setUser(rep);
    await tester.pump();

    expect(find.byType(CoachMascot), findsOneWidget);
    verify(() => bloc.add(const CoachStarted())).called(1);
  });

  testWidgets('signing out hides it again', (tester) async {
    session.setUser(rep);
    await pump(tester);
    expect(find.byType(CoachMascot), findsOneWidget);

    session.clear();
    await tester.pump();

    expect(find.byType(CoachMascot), findsNothing);
  });

  testWidgets('the paused assistant shows on Home only', (tester) async {
    session.setUser(rep);
    await pump(tester);
    expect(find.byType(CoachMascot), findsOneWidget);

    tabs.goTo(ShellTab.myVisits);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CoachMascot), findsNothing);

    tabs.goTo(ShellTab.home);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CoachMascot), findsOneWidget);
  });
}
