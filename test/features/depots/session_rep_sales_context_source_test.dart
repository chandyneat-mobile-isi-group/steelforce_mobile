import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/domain/entities/auth_profile.dart';
import 'package:steelforce/features/authentication/domain/entities/user.dart';
import 'package:steelforce/features/authentication/domain/entities/user_role.dart';
import 'package:steelforce/features/authentication/domain/repositories/auth_repository.dart';
import 'package:steelforce/features/depots/data/local/session_rep_sales_context_source.dart';
import 'package:mocktail/mocktail.dart';

/// The personnel number on a registration must be the signed-in rep's, and
/// there must be no fallback to a fixed one.
class _MockAuth extends Mock implements AuthRepository {}

const _user = User(
  id: 'u-1',
  email: 'rep@isi.test',
  fullName: 'Sok Dara',
  roles: {UserRole.salesRep},
);

AuthProfile _profile({String id = 'u-1', String employeeId = '107576'}) =>
    AuthProfile(
      id: id,
      employeeId: employeeId,
      email: 'rep@isi.test',
      fullName: 'Sok Dara',
    );

void main() {
  late _MockAuth auth;
  late SessionManager session;
  late SessionRepSalesContextSource source;

  void cached(ResultFuture<AuthProfile?> Function() answer) =>
      when(() => auth.cachedProfile()).thenAnswer((_) => answer());

  setUp(() {
    auth = _MockAuth();
    session = SessionManager();
    source = SessionRepSalesContextSource(auth: auth, session: session);
  });

  tearDown(() => session.dispose());

  test('uses the signed-in rep\'s own personnel number', () async {
    session.setUser(_user);
    cached(() async => Success(_profile()));

    final rep = await source.current();

    expect(rep, isNotNull);
    expect(rep!.salesEmployeeId, '107576');
    expect(rep.salesEmployeeName, 'Sok Dara');
    // Not claimed from the profile — left for the documented defaults.
    expect(rep.salesOrganization, isEmpty);
    expect(rep.salesOffice, isEmpty);
  });

  test('a different rep gets a different number — nothing is fixed', () async {
    session.setUser(_user);
    cached(() async => Success(_profile(employeeId: '200001')));

    expect((await source.current())!.salesEmployeeId, '200001');
  });

  test('no signed-in user means no identity, and no profile read', () async {
    cached(() async => Success(_profile()));

    expect(await source.current(), isNull);
    verifyNever(() => auth.cachedProfile());
  });

  test('no cached profile means no identity', () async {
    session.setUser(_user);
    cached(() async => const Success(null));

    expect(await source.current(), isNull);
  });

  test('a failed profile read means no identity', () async {
    session.setUser(_user);
    cached(() async => const Failed(CacheFailure(message: 'unreadable')));

    expect(await source.current(), isNull);
  });

  test('a profile cached for another account is not used', () async {
    session.setUser(_user);
    cached(() async => Success(_profile(id: 'someone-else')));

    expect(await source.current(), isNull);
  });

  test('an empty personnel number is not an identity', () async {
    session.setUser(_user);
    cached(() async => Success(_profile(employeeId: '  ')));

    expect(await source.current(), isNull);
  });

  test('a non-numeric personnel number is refused, not sent', () async {
    // SAP PERNR is numeric; a label is accepted by the backend and then lost
    // on the push.
    session.setUser(_user);
    cached(() async => Success(_profile(employeeId: 'mobile')));

    expect(await source.current(), isNull);
  });
}
