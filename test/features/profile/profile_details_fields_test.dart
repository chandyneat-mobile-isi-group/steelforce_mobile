import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/features/authentication/data/models/auth_profile_model.dart';
import 'package:steelforce/features/profile/data/models/worker_profile_model.dart';
import 'package:steelforce/features/profile/domain/entities/worker_profile.dart';
import 'package:steelforce/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:steelforce/features/profile/presentation/widgets/profile_header.dart';
import 'package:steelforce/features/profile/presentation/widgets/profile_info_section.dart';

/// The profile API sends a Khmer name, a line manager and (while one is in
/// force) a temporary-password expiry. They used to stop at the auth layer
/// and never reach the screen.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  /// `GET /api/v1/mobile/auth/profile`, as sent.
  const mobileProfile = {
    'id': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
    'employeeCode': 'EMP000202',
    'fullName': 'Sok Dara',
    'khmerName': 'សុខ ដារ៉ា',
    'phoneNumber': '+85512345209',
    'email': 'sok.dara@isigroup.com.kh',
    'role': 'Sales Representative',
    'passwordChangeRequired': false,
    'lastLoginAt': '2026-10-07T06:29:03.780Z',
    'lineManager': {
      'id': '3fa85f64-5717-4562-b3fc-2c963f66afa7',
      'empCode': 'EMP000001',
      'englishName': 'Chan Vichea',
    },
  };

  WorkerProfile worker(Map<String, dynamic> json) =>
      WorkerProfileModel.fromAuthProfile(AuthProfileModel.fromJson(json),
          apiBaseUrl: 'https://h');

  group('mapping', () {
    test('carries Khmer name, line manager and role label through', () {
      final w = worker(mobileProfile);
      expect(w.khmerName, 'សុខ ដារ៉ា');
      expect(w.lineManagerName, 'Chan Vichea');
      expect(w.lineManagerCode, 'EMP000001');
      // Name only — the manager's employee code is not shown.
      expect(w.lineManager, 'Chan Vichea');
      // The display name, not the enum identifier `salesRep`.
      expect(w.title, 'Sales Representative');
      expect(w.temporaryPasswordExpiresAt, isNull);
    });

    test('the temporary-password expiry shows only while one is in force', () {
      const expiry = '2026-10-08T06:00:00.000Z';
      expect(
        worker({
          ...mobileProfile,
          'passwordChangeRequired': true,
          'temporaryPasswordExpiresAt': expiry,
        }).temporaryPasswordExpiresAt,
        DateTime.parse(expiry),
      );
      expect(
        worker({...mobileProfile, 'temporaryPasswordExpiresAt': expiry})
            .temporaryPasswordExpiresAt,
        isNull,
      );
    });

    test('the line manager survives the offline cache', () {
      final cached = AuthProfileModel.fromJson(
          AuthProfileModel.fromJson(mobileProfile).toJson());
      expect(cached.lineManagerName, 'Chan Vichea');
      expect(cached.lineManagerCode, 'EMP000001');
      expect(cached.position, 'Sales Representative');
    });

    test('a manager with a code but no name is no row', () {
      final w = worker({
        ...mobileProfile,
        'lineManager': {'empCode': 'EMP000001'},
      });
      expect(w.lineManager, isNull);
    });

    test('the profile photo and its thumbnail come from the mobile profile',
        () {
      final w = worker({
        ...mobileProfile,
        'profilePhotoUrl': 'https://files.example/p/full.webp?sig=1',
        'profilePhotoThumbnailUrl': 'https://files.example/p/thumb.webp?sig=1',
      });
      expect(w.avatarUrl, 'https://files.example/p/full.webp?sig=1');
      expect(w.avatarThumbnailUrl, 'https://files.example/p/thumb.webp?sig=1');
    });

    test('no photo means initials, not a broken image', () {
      final w = worker(mobileProfile);
      expect(w.avatarUrl, isNull);
      expect(w.avatarThumbnailUrl, isNull);
    });

    test('a missing line manager is no row, not an empty one', () {
      final w = worker({...mobileProfile}..remove('lineManager'));
      expect(w.lineManager, isNull);
    });
  });

  group('screen', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light(AppTypography.latinFontFamily),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ));
      await tester.pump();
    }

    testWidgets('the header shows the Khmer name under the English one',
        (tester) async {
      await pump(
        tester,
        ProfileHeader(
            profile: worker(mobileProfile), onEdit: null, showEdit: false),
      );
      expect(find.text('Sok Dara'), findsOneWidget);
      expect(find.text('សុខ ដារ៉ា'), findsOneWidget);
      expect(find.text('Sales Representative'), findsOneWidget);
    });

    testWidgets('the header offers the photo edit button', (tester) async {
      var tapped = false;
      await pump(
        tester,
        ProfileHeader(
            profile: worker(mobileProfile), onEdit: () => tapped = true),
      );
      final edit = find.text('profile.edit'.tr);
      expect(edit, findsOneWidget);
      await tester.tap(edit);
      expect(tapped, isTrue);
    });

    testWidgets('the round avatar loads the thumbnail, not the full photo',
        (tester) async {
      await pump(
        tester,
        ProfileHeader(
          profile: worker({
            ...mobileProfile,
            'profilePhotoUrl': 'https://files.example/p/full.webp',
            'profilePhotoThumbnailUrl': 'https://files.example/p/thumb.webp',
          }),
          onEdit: null,
          showEdit: false,
        ),
      );
      final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
      expect(avatar.url, 'https://files.example/p/thumb.webp');
    });

    testWidgets('the details show the line manager and temp-password expiry',
        (tester) async {
      await pump(
        tester,
        ProfileInfoSection(
          profile: worker({
            ...mobileProfile,
            'passwordChangeRequired': true,
            'temporaryPasswordExpiresAt': '2026-10-08T06:00:00.000Z',
          }),
        ),
      );
      expect(find.text('profile.line_manager'.tr), findsOneWidget);
      expect(find.text('Chan Vichea'), findsOneWidget);
      expect(find.textContaining('EMP000001'), findsNothing);
      expect(find.text('profile.temp_password_expires'.tr), findsOneWidget);
    });
  });
}
