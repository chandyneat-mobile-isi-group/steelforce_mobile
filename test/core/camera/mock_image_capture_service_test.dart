import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/camera/mock/mock_camera_asset.dart';
import 'package:steelforce/core/camera/mock/mock_image_capture_service.dart';

/// The stand-in camera's contract.
///
/// The load-bearing property is that it returns the **same type, backed by a
/// real file**, as the device camera does — because every downstream flow
/// (stamping, compression, multipart upload) does `File(result.path)` and must
/// not be able to tell the difference.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this._bytes);

  final Map<String, Uint8List> _bytes;
  final List<String> requested = [];

  @override
  Future<ByteData> load(String key) async {
    requested.add(key);
    final data = _bytes[key];
    if (data == null) throw FlutterError('asset not bundled: $key');
    return ByteData.view(data.buffer);
  }
}

void main() {
  // persistCapturedBytes writes through path_provider on native.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isi_mock_camera_test');
    // path_provider has no implementation under `flutter test`, so its channel
    // is answered with a real temporary directory. The service then writes
    // through exactly the code path it uses on a device.
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

  Uint8List somePng() => Uint8List.fromList(List.filled(64, 0x89));

  _FakeBundle bundleWithAll() => _FakeBundle({
        for (final asset in MockCameraAsset.values) asset.assetPath: somePng(),
      });

  MockImageCaptureService serviceWith(AssetBundle bundle) =>
      MockImageCaptureService(
        navigatorKey: GlobalKey<NavigatorState>(),
        bundle: bundle,
      );

  group('the asset catalogue', () {
    test('every slot points at the shared directory', () {
      for (final asset in MockCameraAsset.values) {
        expect(asset.assetPath, startsWith('${MockCameraAsset.directory}/'));
        expect(asset.assetPath, endsWith(asset.fileName));
      }
    });

    test('there is more than one test image, and they are distinct', () {
      final paths = MockCameraAsset.values.map((a) => a.assetPath).toSet();
      expect(paths.length, MockCameraAsset.values.length);
      expect(paths.length, greaterThan(1));
    });

    test('the fallback is one of the catalogued assets', () {
      expect(MockCameraAsset.values, contains(MockCameraAsset.fallback));
    });
  });

  group('resolving an asset', () {
    test('reads the bundle and returns a file that exists', () async {
      final bundle = bundleWithAll();
      final file = await serviceWith(bundle).resolveAsset(
        MockCameraAsset.storefront,
      );

      expect(bundle.requested, [MockCameraAsset.storefront.assetPath]);
      expect(file.path, isNotEmpty);
      // The bytes must be readable through the same API a real capture uses.
      expect(await file.readAsBytes(), isNotEmpty);
    });

    test('each test image resolves independently', () async {
      final service = serviceWith(bundleWithAll());

      for (final asset in MockCameraAsset.values) {
        final file = await service.resolveAsset(asset);
        expect(await file.readAsBytes(), isNotEmpty, reason: asset.fileName);
      }
    });

    test('two captures do not collide on one filename', () async {
      final service = serviceWith(bundleWithAll());

      final first = await service.resolveAsset(MockCameraAsset.idCard);
      final second = await service.resolveAsset(MockCameraAsset.idCard);

      expect(first.path, isNot(second.path),
          reason: 'a retake must not overwrite the shot before it');
    });
  });

  group('failure is surfaced, not swallowed', () {
    test('a missing asset throws with a diagnosable message', () async {
      // Silently returning null would be indistinguishable from a developer
      // cancelling the camera, which is the worst possible way to learn that
      // pubspec.yaml and the asset folder have drifted apart.
      final service = serviceWith(_FakeBundle(const {}));

      await expectLater(
        service.resolveAsset(MockCameraAsset.storefront),
        throwsA(isA<MockCameraAssetException>().having(
          (e) => e.toString(),
          'message',
          allOf(contains('pubspec.yaml'), contains('storefront.png')),
        )),
      );
    });

    test('an empty asset is treated as invalid', () async {
      final service = serviceWith(_FakeBundle({
        MockCameraAsset.document.assetPath: Uint8List(0),
      }));

      await expectLater(
        service.resolveAsset(MockCameraAsset.document),
        throwsA(isA<MockCameraAssetException>()),
      );
    });
  });

  test('it declares itself as a mock, and as available', () {
    final service = serviceWith(bundleWithAll());

    expect(service.isMock, isTrue);
    expect(service.isAvailable, isTrue);
  });
}
