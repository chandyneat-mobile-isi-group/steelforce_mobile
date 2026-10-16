import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/profile/domain/entities/profile_update.dart';
import 'package:steelforce/features/profile/domain/entities/worker_profile.dart';
import 'package:steelforce/features/profile/domain/repositories/profile_repository.dart';
import 'package:steelforce/features/profile/domain/usecases/change_password.dart';
import 'package:steelforce/features/profile/domain/usecases/get_worker_profile.dart';
import 'package:steelforce/features/profile/domain/usecases/logout_worker.dart';
import 'package:steelforce/features/profile/domain/usecases/update_worker_profile.dart';
import 'package:steelforce/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:steelforce/features/profile/presentation/widgets/edit_profile_sheet.dart';
import 'package:steelforce/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:steelforce/features/profile/presentation/widgets/profile_details_dialog.dart';
import 'package:steelforce/features/profile/presentation/widgets/profile_header.dart';
import 'package:steelforce/features/profile/presentation/widgets/profile_info_section.dart';
import 'package:steelforce/features/profile/presentation/widgets/profile_menu.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements ProfileRepository {}

class _NoCamera implements ImageCaptureService {
  @override
  Future<List<XFile>> pickMultipleFromGallery(
          {int? maxWidth,
          int? maxHeight,
          int? imageQuality,
          int? limit}) async =>
      const [];

  @override
  bool get isAvailable => false;
  @override
  bool get isMock => true;
  @override
  Future<XFile?> capture(
          {int? maxWidth,
          int? maxHeight,
          int? imageQuality,
          bool preferRearCamera = true}) async =>
      null;
  @override
  Future<XFile?> pickFromGallery(
          {int? maxWidth, int? maxHeight, int? imageQuality}) async =>
      null;
  @override
  Future<XFile?> pick(ImageCaptureSource source,
          {int? maxWidth, int? maxHeight, int? imageQuality}) async =>
      null;
}

/// The live `/auth/me` record from the user's session, as the screen gets it.
final _profile = WorkerProfile(
  id: '01a06a68-6de6-7bad-9b6f-38e2e38c1ba9',
  fullName: 'Chan Sophea',
  employeeCode: '103424',
  email: 'sophea.chan@isigroup.com.kh',
  phone: '012345201',
  department: 'Field Sales',
  position: 'Sales Representative',
  territoryCode: 'PP-CENTRAL',
  language: 'km-KH',
  timeZone: 'Asia/Phnom_Penh',
  lastLoginAt: DateTime.utc(2026, 10, 2, 6, 32),
);

void main() {
  late _MockRepository repository;
  late ProfileCubit cubit;

  setUpAll(
      () => registerFallbackValue(const ProfileUpdate(removeAvatar: true)));

  setUp(() async {
    await LocalizationService.instance.load('en');
    repository = _MockRepository();
    when(repository.getProfile).thenAnswer((_) async => Success(_profile));
    cubit = ProfileCubit(
      getWorkerProfile: GetWorkerProfile(repository),
      updateWorkerProfile: UpdateWorkerProfile(repository),
      changePassword: ChangePassword(repository),
      logoutWorker: LogoutWorker(repository),
    );
    await cubit.load();
  });

  tearDown(() => cubit.close());

  Future<void> pump(WidgetTester tester, Widget child,
      {double textScale = 1.0,
      Size size = const Size(390, 844),
      EdgeInsets padding = EdgeInsets.zero}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScreenUtilInit(
      // As app.dart does: the phone design on a phone, 1:1 above it.
      designSize: size.width < 600 ? const Size(390, 844) : size,
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light(AppTypography.latinFontFamily),
        // In `builder`, above the Navigator, so dialogs and sheets — which
        // open in their own routes — get the same text scale and insets.
        builder: (context, app) => MediaQuery(
          data: MediaQueryData(
              size: size,
              padding: padding,
              viewPadding: padding,
              textScaler: TextScaler.linear(textScale)),
          child: app!,
        ),
        home: Scaffold(body: child),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Widget opener({WorkerProfile? profile}) => Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showEditProfileSheet(
              context: context,
              profile: profile ?? _profile,
              cubit: cubit,
              imageCapture: _NoCamera(),
            ),
            child: const Text('open'),
          ),
        ),
      );

  group('the profile preview', () {
    testWidgets('shows what /auth/me says, and no permissions', (tester) async {
      await pump(
        tester,
        ListView(children: [
          ProfileHeader(profile: _profile, onEdit: () {}),
          ProfileInfoSection(profile: _profile),
        ]),
      );

      for (final value in [
        'Chan Sophea',
        'sophea.chan@isigroup.com.kh',
        '012345201',
        'Field Sales',
        'PP-CENTRAL',
      ]) {
        expect(find.text(value), findsOneWidget, reason: value);
      }
      // No Preferences card: the language follows the app's own setting.
      expect(find.text('Khmer'), findsNothing);
      expect(find.text('Asia/Phnom_Penh'), findsNothing);
      // Territory sits where the job title was, and the job title after it.
      expect(
        tester.getTopLeft(find.text('PP-CENTRAL')).dy,
        // `.last`: the header shows the job title too, above the section.
        lessThan(tester.getTopLeft(find.text('Sales Representative').last).dy),
      );
      expect(find.textContaining('103424'), findsOneWidget);
      // Grant strings and flags are the app's business, not the user's.
      expect(find.textContaining('customers.read'), findsNothing);
      expect(find.textContaining('offlineSync'), findsNothing);
      // No depot assigned: the row is left out, not shown empty.
      expect(find.text('Depot'), findsNothing);
      // No picture: initials, never a stock photo.
      expect(find.text('CS'), findsOneWidget);
    });

    testWidgets('holds together in Khmer at 200% text', (tester) async {
      // Real async: an asset load inside the fake test clock never completes.
      await tester.runAsync(() => LocalizationService.instance.load('km'));
      await pump(
        tester,
        ListView(children: [
          ProfileHeader(profile: _profile, onEdit: () {}),
          ProfileInfoSection(profile: _profile),
        ]),
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('the profile menu', () {
    Widget menu(
            {VoidCallback? onEdit,
            VoidCallback? onTile,
            VoidCallback? onLogout}) =>
        ListView(children: [
          ProfileHeader(profile: _profile, onEdit: onEdit),
          ProfileMenuCard(
            logoutLabel: 'profile.logout'.tr,
            onLogout: onLogout,
            tiles: [
              ProfileMenuTile(
                icon: Icons.badge_outlined,
                title: 'profile.my_details'.tr,
                subtitle: _profile.email,
                onTap: onTile ?? () {},
              ),
              ProfileMenuTile(
                icon: Icons.lock_reset_rounded,
                title: 'profile.change_password'.tr,
                subtitle: 'profile.change_password_hint'.tr,
                onTap: () {},
              ),
            ],
          ),
        ]);

    testWidgets('header shows name, role and employee number', (tester) async {
      await pump(tester, menu());
      expect(find.text('Chan Sophea'), findsOneWidget);
      expect(find.text('Sales Representative'), findsOneWidget);
      expect(find.textContaining('103424', findRichText: true), findsOneWidget);
      expect(find.text('My details'), findsOneWidget);
      expect(find.text('sophea.chan@isigroup.com.kh'), findsOneWidget);
    });

    testWidgets('edit, a tile and log out each fire their own action',
        (tester) async {
      var edits = 0, tiles = 0, logouts = 0;
      await pump(
        tester,
        menu(
          onEdit: () => edits++,
          onTile: () => tiles++,
          onLogout: () => logouts++,
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.tap(find.text('My details'));
      await tester.tap(find.text('Log Out'));
      expect([edits, tiles, logouts], [1, 1, 1]);
    });

    testWidgets('edit is disabled while a save is in flight', (tester) async {
      await pump(tester, menu(onEdit: null));
      final button = tester.widget<ButtonStyleButton>(find.ancestor(
          of: find.text('Edit'),
          matching: find.bySubtype<ButtonStyleButton>()));
      expect(button.onPressed, isNull);
    });

    testWidgets('edit button keeps a 48dp touch target', (tester) async {
      await pump(tester, menu(onEdit: () {}));
      final size = tester.getSize(find.ancestor(
          of: find.text('Edit'),
          matching: find.bySubtype<ButtonStyleButton>()));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('tapping the photo opens it full screen, close returns',
        (tester) async {
      final withPhoto = WorkerProfile(
        id: _profile.id,
        fullName: _profile.fullName,
        employeeCode: _profile.employeeCode,
        email: _profile.email,
        phone: _profile.phone,
        avatarUrl: 'https://example.invalid/avatar.jpg',
      );
      await pump(tester, ProfileHeader(profile: withPhoto, onEdit: () {}));

      await tester.tap(find.byType(ProfileAvatar));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final close = find.byIcon(Icons.close_rounded);
      expect(close, findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      // The photo is laid out over the whole screen and centred, never drawn
      // at its pixel size in the corner.
      final photo = find.descendant(
          of: find.byType(InteractiveViewer), matching: find.byType(Image));
      expect(tester.getSize(photo), const Size(390, 844));
      expect(tester.getCenter(photo), const Offset(195, 422));

      await tester.tap(close);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(InteractiveViewer), findsNothing);
    });

    testWidgets('swiping the photo down closes the viewer', (tester) async {
      final withPhoto = WorkerProfile(
        id: _profile.id,
        fullName: _profile.fullName,
        employeeCode: _profile.employeeCode,
        email: _profile.email,
        phone: _profile.phone,
        avatarUrl: 'https://example.invalid/avatar.jpg',
      );
      await pump(tester, ProfileHeader(profile: withPhoto, onEdit: () {}));
      await tester.tap(find.byType(ProfileAvatar));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.fling(
          find.byType(InteractiveViewer), const Offset(0, 300), 1500);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(InteractiveViewer), findsNothing);
    });

    Future<void> openViewer(WidgetTester tester) async {
      final withPhoto = WorkerProfile(
        id: _profile.id,
        fullName: _profile.fullName,
        employeeCode: _profile.employeeCode,
        email: _profile.email,
        phone: _profile.phone,
        avatarUrl: 'https://example.invalid/avatar.jpg',
      );
      await pump(tester, ProfileHeader(profile: withPhoto, onEdit: () {}));
      await tester.tap(find.byType(ProfileAvatar));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    double viewerScale(WidgetTester tester) => tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!
        .value
        .getMaxScaleOnAxis();

    Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
      await tester.tap(f);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('+ and − zoom in and out, within 100%–400%', (tester) async {
      await openViewer(tester);
      final zoomIn = find.byTooltip('Zoom in');
      final zoomOut = find.byTooltip('Zoom out');
      expect(find.text('100%'), findsOneWidget);
      // Already at fit: nothing smaller to go to.
      expect(
          tester
              .widget<IconButton>(find.ancestor(
                  of: find.byIcon(Icons.remove_rounded),
                  matching: find.byType(IconButton)))
              .onPressed,
          isNull);

      await tapAndSettle(tester, zoomIn);
      expect(viewerScale(tester), closeTo(1.5, 0.001));
      expect(find.text('150%'), findsOneWidget);

      await tapAndSettle(tester, zoomIn);
      await tapAndSettle(tester, zoomIn);
      await tapAndSettle(tester, zoomIn);
      expect(viewerScale(tester), closeTo(4, 0.001));
      expect(find.text('400%'), findsOneWidget);

      await tapAndSettle(tester, zoomOut);
      expect(viewerScale(tester), closeTo(4 / 1.5, 0.001));

      // The percentage fits the photo again in one tap.
      await tapAndSettle(tester, find.text('267%'));
      expect(viewerScale(tester), closeTo(1, 0.001));
    });

    testWidgets('pinching zooms the photo', (tester) async {
      await openViewer(tester);
      final centre = tester.getCenter(find.byType(InteractiveViewer));
      final a = await tester.startGesture(centre - const Offset(40, 0));
      final b =
          await tester.startGesture(centre + const Offset(40, 0), pointer: 2);
      for (var i = 0; i < 10; i++) {
        await a.moveBy(const Offset(-10, 0));
        await b.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      await a.up();
      await b.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(viewerScale(tester), greaterThan(1.5));
      // A pinch is not a swipe: the viewer stays open.
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('double-tap zooms in, double-tap again fits', (tester) async {
      await openViewer(tester);
      final viewer = find.byType(InteractiveViewer);
      await tester.tap(viewer);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(viewer);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(viewerScale(tester), closeTo(2.5, 0.001));

      await tester.tap(viewer);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(viewer);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(viewerScale(tester), closeTo(1, 0.001));
    });

    testWidgets('initials have nothing to enlarge, so no viewer opens',
        (tester) async {
      await pump(tester, ProfileHeader(profile: _profile, onEdit: () {}));
      await tester.tap(find.byType(ProfileAvatar));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
    });

    testWidgets('holds together in Khmer at 200% text', (tester) async {
      await tester.runAsync(() => LocalizationService.instance.load('km'));
      await pump(tester, menu(onEdit: () {}), textScale: 2.0);
      expect(tester.takeException(), isNull);
    });
  });

  group('the details dialog', () {
    Widget opener() => BlocProvider.value(
          value: cubit,
          child: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showProfileDetailsDialog(context),
                child: const Text('details'),
              ),
            ),
          ),
        );

    testWidgets('opens over the screen with every section, closes on ✕',
        (tester) async {
      await pump(tester, opener());
      await tester.tap(find.text('details'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('My details'), findsOneWidget);
      for (final value in [
        'sophea.chan@isigroup.com.kh',
        '012345201',
        'Field Sales',
        'Sales Representative',
        'PP-CENTRAL',
        'Active',
      ]) {
        expect(find.text(value), findsOneWidget, reason: value);
      }
      expect(find.text('Khmer'), findsNothing);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    // Every field filled — the tallest the dialog can be.
    final fullProfile = WorkerProfile(
      id: _profile.id,
      fullName: _profile.fullName,
      employeeCode: _profile.employeeCode,
      email: _profile.email,
      phone: _profile.phone,
      department: _profile.department,
      position: _profile.position,
      territoryCode: _profile.territoryCode,
      depotCode: 'DEPOT-PP-01',
      language: _profile.language,
      timeZone: _profile.timeZone,
      lastLoginAt: DateTime.utc(2026, 10, 2, 6, 32),
      passwordExpiresAt: DateTime.utc(2027, 1, 1),
    );

    // Portrait only (main.dart locks it), smallest common Android up to iPad,
    // each with its real status-bar / home-indicator insets.
    const screens = {
      '360×640 Android': (Size(360, 640), EdgeInsets.only(top: 24)),
      '375×667 iPhone SE': (Size(375, 667), EdgeInsets.only(top: 20)),
      '390×844 iPhone': (Size(390, 844), EdgeInsets.only(top: 47, bottom: 34)),
      '412×915 Android': (Size(412, 915), EdgeInsets.only(top: 24, bottom: 16)),
      '768×1024 iPad': (Size(768, 1024), EdgeInsets.only(top: 24, bottom: 20)),
    };

    for (final lang in ['en', 'km']) {
      for (final MapEntry(key: name, value: (size, padding))
          in screens.entries) {
        testWidgets('fits one screen without scrolling: $name, $lang',
            (tester) async {
          if (lang != 'en') {
            await tester
                .runAsync(() => LocalizationService.instance.load(lang));
          }
          when(repository.getProfile)
              .thenAnswer((_) async => Success(fullProfile));
          await cubit.load();
          await pump(tester, opener(), size: size, padding: padding);
          await tester.tap(find.text('details'));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          // No scroll view at all…
          expect(
              find.descendant(
                  of: find.byType(Dialog), matching: find.byType(Scrollable)),
              findsNothing);
          // …every row inside the visible card…
          final card = tester.getRect(find
              .descendant(
                  of: find.byType(Dialog), matching: find.byType(Material))
              .first);
          final section = find.byType(ProfileInfoSection);
          final drawn = tester.getRect(section);
          expect(drawn.bottom, lessThanOrEqualTo(card.bottom + 0.5),
              reason: 'content runs past the dialog on $name ($lang)');
          // …and never shrunk enough to hurt reading.
          final scale = drawn.height / tester.getSize(section).height;
          expect(scale, greaterThanOrEqualTo(0.95),
              reason: 'shrunk to ${(scale * 100).round()}% on $name ($lang)');
        });
      }
    }

    testWidgets('holds together in Khmer at 200% text', (tester) async {
      await tester.runAsync(() => LocalizationService.instance.load('km'));
      await pump(tester, opener(), textScale: 2.0);
      await tester.tap(find.text('details'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Long content scrolls inside the dialog rather than past the screen.
      final card = find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first;
      expect(tester.getSize(card).height, lessThanOrEqualTo(844));
      // At this size it scrolls rather than shrinking the rep's text back.
      expect(
          find.descendant(
              of: find.byType(Dialog), matching: find.byType(Scrollable)),
          findsOneWidget);
    });
  });

  group('the edit sheet', () {
    testWidgets('cannot save until something changed', (tester) async {
      await pump(tester, opener());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final save = find.widgetWithText(FilledButton, 'No changes to save');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
    });

    testWidgets('offers only the photo — nothing else is editable',
        (tester) async {
      await pump(tester, opener());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Full name'), findsNothing);
      expect(find.text('Job title'), findsNothing);
      expect(find.text('Time zone'), findsNothing);
      expect(find.text('Change photo'), findsWidgets);
    });

    WorkerProfile withPhoto() => WorkerProfile(
          id: _profile.id,
          fullName: _profile.fullName,
          employeeCode: _profile.employeeCode,
          email: _profile.email,
          phone: _profile.phone,
          avatarUrl: 'https://example.invalid/avatar.jpg',
        );

    Future<void> removePhotoAndSave(WidgetTester tester) async {
      await pump(tester, opener(profile: withPhoto()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Change photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();
      expect(find.text('Your photo will be removed when you save.'),
          findsOneWidget);
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
    }

    testWidgets('removing the photo sends only that', (tester) async {
      when(() => repository.updateProfile(any())).thenAnswer((_) async =>
          const Success(WorkerProfile(
              id: 'u',
              fullName: 'Chan Sophea',
              employeeCode: '103424',
              email: 'e',
              phone: '')));
      await removePhotoAndSave(tester);

      final sent = verify(() => repository.updateProfile(captureAny()))
          .captured
          .single as ProfileUpdate;
      expect(sent, const ProfileUpdate(removeAvatar: true));
      // Closed on success.
      expect(find.text('Save Changes'), findsNothing);
    });

    testWidgets('a failed save stays open and says why', (tester) async {
      when(() => repository.updateProfile(any()))
          .thenAnswer((_) async => const Failed(NetworkFailure()));
      await removePhotoAndSave(tester);

      expect(find.textContaining("You're offline"), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });
  });

  test('server refusals map to specific, translated messages', () {
    String messageFor(String code) =>
        profileFailureMessage(ServerFailure(message: 'raw', code: code));

    expect(messageFor(ApiErrorCodes.avatarTooLarge),
        'That photo is larger than 5 MB.');
    expect(messageFor(ApiErrorCodes.avatarExtensionNotAllowed),
        'Choose a JPG, PNG or WEBP photo.');
    // Never the raw, English-only server text.
    expect(messageFor('Something.Unknown'), isNot('raw'));
  });

  test('the photo route\'s refusals map by HTTP status', () {
    // `/users/profile-photo` does not send the old profile-edit codes.
    String messageFor(int status) => profileFailureMessage(
        ServerFailure(message: 'raw', statusCode: status, code: 'X'));

    expect(messageFor(413), 'That photo is larger than 5 MB.');
    expect(messageFor(400), 'Choose a JPG, PNG or WEBP photo.');
    expect(messageFor(429), 'Too many attempts. Wait a moment and try again.');
    expect(messageFor(500), 'Could not update profile');
  });
}
