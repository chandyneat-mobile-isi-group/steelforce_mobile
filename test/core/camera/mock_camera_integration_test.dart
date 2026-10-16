import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/core/camera/mock/mock_camera_asset.dart';
import 'package:steelforce/core/camera/mock/mock_camera_screen.dart';
import 'package:steelforce/core/camera/mock/mock_image_capture_service.dart';
import 'package:steelforce/features/order/domain/services/image_search_service.dart';
import 'package:steelforce/features/order/presentation/services/image_picker_search_service.dart';

/// A mock image must travel the *same* downstream flow as a real one.
///
/// This is the requirement the whole seam exists for: if a feature can tell
/// where its pixels came from, the simulator stops being a useful place to
/// test that feature. So the checks here are deliberately at the feature's own
/// boundary, not the camera's.
class _StubBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.view(Uint8List.fromList(List.filled(128, 0x89)).buffer);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isi_camera_integration');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  MockImageCaptureService mockCamera(GlobalKey<NavigatorState> key) =>
      MockImageCaptureService(navigatorKey: key, bundle: _StubBundle());

  group('the feature cannot tell where the pixels came from', () {
    test('visual product search resolves a keyword from a mock image',
        () async {
      // ImagePickerSearchService owns the matching logic. It is unchanged by
      // the swap — it just receives an XFile from somewhere else now.
      final service = ImagePickerSearchService(
        mockCamera(GlobalKey<NavigatorState>()),
      );

      final keyword = await service.matchQuery(ImageSearchSource.camera);

      expect(keyword, isNotNull);
      expect(keyword, isNotEmpty,
          reason: 'the mock image must drive the same matching a real photo '
              'would, not a special-cased branch');
    });

    test('the returned file behaves like a camera file', () async {
      final XFile? file =
          await mockCamera(GlobalKey<NavigatorState>()).capture();

      expect(file, isA<XFile>());
      // Every downstream flow does one of these three things.
      expect(await file!.readAsBytes(), isNotEmpty); // proof-photo stamping
      expect(File(file.path).existsSync(), isTrue); // multipart upload
      expect(file.path, isNotEmpty); // drawing-upload copy
    });

    test('gallery and camera both yield a usable file', () async {
      final service = mockCamera(GlobalKey<NavigatorState>());

      for (final source in ImageCaptureSource.values) {
        final file = await service.pick(source);
        expect(await file!.readAsBytes(), isNotEmpty, reason: source.name);
      }
    });
  });

  group('the mock camera screen', () {
    Future<void> pump(WidgetTester tester,
        {required ValueChanged<MockCameraAsset?> onPop}) async {
      // Mirrors `app.dart`: the whole app runs inside ScreenUtilInit, and this
      // screen uses the responsive helpers. Without it ScreenUtil's fields are
      // unset and the widget throws before it renders.
      //
      // No explicit theme: the screen resolves `AppThemeColors` with a
      // fallback, so it must render correctly without the extension present.
      await tester.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await Navigator.of(context)
                    .push<MockCameraAsset>(MaterialPageRoute(
                  builder: (_) =>
                      const MockCameraScreen(source: ImageCaptureSource.camera),
                ));
                onPop(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('frames, shoots, then confirms — like a camera',
        (tester) async {
      MockCameraAsset? popped;
      await pump(tester, onPop: (v) => popped = v);

      // Framing: a shutter, no confirm yet.
      expect(find.text('Use photo'), findsNothing);
      expect(find.bySemanticsLabel('Capture'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Capture'));
      await tester.pumpAndSettle();

      // Captured: retake and confirm appear.
      expect(find.text('Retake'), findsOneWidget);
      await tester.tap(find.text('Use photo'));
      await tester.pumpAndSettle();

      expect(popped, MockCameraAsset.fallback);
    });

    testWidgets('retake returns to framing', (tester) async {
      await pump(tester, onPop: (_) {});

      await tester.tap(find.bySemanticsLabel('Capture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retake'));
      await tester.pumpAndSettle();

      expect(find.text('Use photo'), findsNothing);
      expect(find.bySemanticsLabel('Capture'), findsOneWidget);
    });

    /// The selector is a horizontal list, so later chips are off-screen at
    /// phone width and not built until scrolled to.
    Future<void> revealChip(WidgetTester tester, String label) async {
      await tester.scrollUntilVisible(
        find.text(label),
        60,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a different test image can be selected', (tester) async {
      MockCameraAsset? popped;
      await pump(tester, onPop: (v) => popped = v);

      await revealChip(tester, MockCameraAsset.idCard.label);
      await tester.tap(find.text(MockCameraAsset.idCard.label));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Capture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use photo'));
      await tester.pumpAndSettle();

      expect(popped, MockCameraAsset.idCard);
    });

    testWidgets('cancelling returns null, exactly as the real picker does',
        (tester) async {
      var called = false;
      MockCameraAsset? popped;
      await pump(tester, onPop: (v) {
        called = true;
        popped = v;
      });

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(called, isTrue);
      expect(popped, isNull,
          reason: 'every caller already handles null as "user backed out"');
    });

    testWidgets('the mock-mode indicator is visible', (tester) async {
      await pump(tester, onPop: (_) {});

      // A developer must never mistake this for the real camera.
      expect(find.textContaining('MOCK CAMERA'), findsOneWidget);
    });

    testWidgets('every test image is offered', (tester) async {
      await pump(tester, onPop: (_) {});

      for (final asset in MockCameraAsset.values) {
        await revealChip(tester, asset.label);
        expect(find.text(asset.label), findsOneWidget, reason: asset.label);
      }
    });
  });
}
