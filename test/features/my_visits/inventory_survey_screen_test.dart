import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/my_visits/presentation/screens/inventory_visible/inventory_survey_screen.dart';

import 'inventory_visibility_test.dart' show kPixelPng;

/// Camera returns one photo; the gallery returns [galleryCount] at a time,
/// trimmed to the caller's limit as the real picker does.
class _Picker implements ImageCaptureService {
  int galleryCount = 3;
  int? lastLimit;

  XFile _file(String name) => XFile.fromData(kPixelPng, name: name);

  @override
  Future<XFile?> capture(
          {int? maxWidth,
          int? maxHeight,
          int? imageQuality,
          bool preferRearCamera = true}) async =>
      _file('camera.png');

  @override
  Future<List<XFile>> pickMultipleFromGallery(
      {int? maxWidth, int? maxHeight, int? imageQuality, int? limit}) async {
    lastLimit = limit;
    final count = limit == null ? galleryCount : galleryCount.clamp(0, limit);
    return [for (var i = 0; i < count; i++) _file('g$i.png')];
  }

  @override
  Future<XFile?> pickFromGallery(
          {int? maxWidth, int? maxHeight, int? imageQuality}) async =>
      _file('one.png');

  @override
  Future<XFile?> pick(ImageCaptureSource source,
          {int? maxWidth, int? maxHeight, int? imageQuality}) =>
      source == ImageCaptureSource.camera ? capture() : pickFromGallery();

  @override
  bool get isAvailable => true;

  @override
  bool get isMock => true;
}

/// Upload several photos at once or take them one by one; Submit once there
/// are at least three, up to the maximum.
void main() {
  late _Picker picker;
  late List<List<SurveyShot>> saved;
  late int submits;
  late bool failSave;

  setUp(() {
    picker = _Picker();
    saved = [];
    submits = 0;
    failSave = false;
  });

  Future<void> pumpScreen(WidgetTester tester,
      {String language = 'en', double width = 390}) async {
    await tester.runAsync(() => LocalizationService.instance.load(language));
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        home: InventorySurveyScreen(
          depotName: 'Mekong Steel Depot',
          capture: picker,
          onPhotosSubmitted: (shots) async {
            if (failSave) throw StateError('disk full');
            saved.add(shots);
          },
          onSubmit: () => submits++,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Through the Add tile, the only way in: it opens the camera/gallery
  /// sheet.
  Future<void> add(WidgetTester tester, {required bool upload}) async {
    final tile = find.bySemanticsLabel('my_visits.survey.add_photos'.tr);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.text(upload
        ? 'my_visits.survey.upload'.tr
        : 'my_visits.inventory.take_photo'.tr));
    await tester.pumpAndSettle();
  }

  Finder removeButtons() => find.byTooltip('my_visits.survey.remove'.tr);

  ElevatedButton submitButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton));

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byType(ElevatedButton));
    // Frames, not a settle: the saving spinner runs until the route is
    // replaced, which the app's navigation does and this harness does not.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('three uploaded at once are enough to submit', (tester) async {
    await pumpScreen(tester);
    expect(submitButton(tester).onPressed, isNull);

    await add(tester, upload: true);
    expect(removeButtons(), findsNWidgets(3));
    expect(submitButton(tester).onPressed, isNotNull);

    await submit(tester);
    expect(saved.single, hasLength(3));
    expect(submits, 1);
  });

  testWidgets('one photo is not enough; more than three is fine',
      (tester) async {
    await pumpScreen(tester);
    await add(tester, upload: false);
    expect(removeButtons(), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);

    picker.galleryCount = 4;
    await add(tester, upload: true);
    expect(removeButtons(), findsNWidgets(5));

    await tester.tap(removeButtons().first);
    await tester.pumpAndSettle();
    expect(removeButtons(), findsNWidgets(4));

    await submit(tester);
    expect(saved.single, hasLength(4));
  });

  testWidgets('the gallery is asked only for what still fits', (tester) async {
    await pumpScreen(tester);
    picker.galleryCount = 4;
    await add(tester, upload: true);
    await add(tester, upload: true);
    expect(picker.lastLimit, InventorySurveyScreen.maxPhotos - 4);
    expect(removeButtons(), findsNWidgets(InventorySurveyScreen.maxPhotos));
  });

  testWidgets('no separate upload or camera buttons on the page',
      (tester) async {
    await pumpScreen(tester);
    expect(find.text('my_visits.survey.upload'.tr), findsNothing);
    expect(find.text('my_visits.inventory.take_photo'.tr), findsNothing);
  });

  testWidgets('a full set hides the add controls', (tester) async {
    await pumpScreen(tester);
    picker.galleryCount = InventorySurveyScreen.maxPhotos;
    await add(tester, upload: true);
    expect(
        find.bySemanticsLabel('my_visits.survey.add_photos'.tr), findsNothing);
  });

  testWidgets('a failed save keeps the rep here with the photos',
      (tester) async {
    failSave = true;
    await pumpScreen(tester);
    await add(tester, upload: true);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(submits, 0);
    expect(find.text('my_visits.inventory.save_failed'.tr), findsOneWidget);
    expect(removeButtons(), findsNWidgets(3));
  });

  for (final language in ['en', 'km']) {
    testWidgets('fits a 320pt phone ($language)', (tester) async {
      await pumpScreen(tester, language: language, width: 320);
      picker.galleryCount = 5;
      await add(tester, upload: true);
      expect(tester.takeException(), isNull);
    });
  }
}
