import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/features/my_visits/presentation/screens/inventory_visible/inventory_visible_screen.dart';

/// A valid 1x1 PNG, so the preview decodes without reporting an image error.
final Uint8List kPixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class FakeCapture implements ImageCaptureService {
  FakeCapture({this.available = true});

  final bool available;

  /// What the next [capture] returns; null means the rep backed out.
  XFile? next;
  int opens = 0;

  @override
  Future<List<XFile>> pickMultipleFromGallery(
          {int? maxWidth,
          int? maxHeight,
          int? imageQuality,
          int? limit}) async =>
      const [];

  @override
  Future<XFile?> capture({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    bool preferRearCamera = true,
  }) async {
    opens++;
    return next;
  }

  @override
  Future<XFile?> pickFromGallery(
          {int? maxWidth, int? maxHeight, int? imageQuality}) async =>
      null;

  @override
  Future<XFile?> pick(ImageCaptureSource source,
          {int? maxWidth, int? maxHeight, int? imageQuality}) async =>
      null;

  @override
  bool get isAvailable => available;

  @override
  bool get isMock => true;
}

/// The step is one photo of the depot's stock. The camera opens by itself,
/// submit waits for a photo, and the rep moves on only once the photo is
/// saved.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
  });

  late FakeCapture camera;
  late List<XFile> saved;
  late int submits;
  late bool failSave;

  setUp(() {
    camera = FakeCapture()..next = XFile.fromData(kPixelPng, name: 'shot.png');
    saved = [];
    submits = 0;
    failSave = false;
  });

  Future<void> pumpScreen(WidgetTester tester,
      {bool openCameraOnStart = true}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          home: InventoryVisibilityScreen(
            depotName: 'Phnom Penh Depot',
            capture: camera,
            openCameraOnStart: openCameraOnStart,
            onPhotoSubmitted: (photo, _) async {
              if (failSave) throw StateError('disk full');
              saved.add(photo);
            },
            onSubmit: () => submits++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ElevatedButton submitButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton));

  testWidgets('opens the camera on arrival and shows the photo',
      (tester) async {
    await pumpScreen(tester);

    expect(camera.opens, 1);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Retake photo'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('backing out of the camera leaves submit disabled',
      (tester) async {
    camera.next = null;
    await pumpScreen(tester);

    expect(find.text('Take a photo to continue'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);

    // …and the rep can open it again.
    camera.next = XFile.fromData(kPixelPng, name: 'shot.png');
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(camera.opens, 2);
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('submit saves the photo, then moves to the next step',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byType(ElevatedButton));
    // Not pumpAndSettle: once saved, the button keeps its spinner until the
    // caller navigates away, which this harness never does.
    await tester.pump();
    await tester.pump();

    expect(saved, hasLength(1));
    expect(submits, 1);
  });

  testWidgets('a failed save keeps the rep here with the photo',
      (tester) async {
    failSave = true;
    await pumpScreen(tester);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(submits, 0);
    expect(find.text("Couldn't save the photo. Try again."), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('retake replaces the photo instead of adding one',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Retake photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pump();

    expect(camera.opens, 2);
    expect(saved, hasLength(1), reason: 'the step takes exactly one photo');
  });

  testWidgets('no camera: says so and offers no capture button',
      (tester) async {
    camera = FakeCapture(available: false);
    await pumpScreen(tester);

    expect(camera.opens, 0);
    expect(find.text("The camera isn't available on this device."),
        findsOneWidget);
    expect(find.text('Take photo'), findsNothing);
    expect(submitButton(tester).onPressed, isNull);
  });
}
