import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/camera/camera_factory.dart';
import 'package:steelforce/core/camera/mock/mock_image_capture_service.dart';
import 'package:steelforce/core/camera/real_image_capture_service.dart';

/// Which implementation the factory hands out.
///
/// This is the only place in the app allowed to consult the runtime
/// environment about the camera, so it is the only place that can get the
/// safety property wrong: **a physical device must never be given the
/// stand-in**, because that would silently upload placeholder images as
/// depot evidence.
void main() {
  final navigatorKey = GlobalKey<NavigatorState>();

  test('explicit mock resolves to the stand-in', () {
    final service =
        CameraFactory.resolve(navigatorKey: navigatorKey, forceMock: true);

    expect(service, isA<MockImageCaptureService>());
    expect(service.isMock, isTrue);
  });

  test('explicit real resolves to the device camera', () {
    final service =
        CameraFactory.resolve(navigatorKey: navigatorKey, forceMock: false);

    expect(service, isA<RealImageCaptureService>());
    expect(service.isMock, isFalse);
  });

  test('auto on a non-simulator host resolves to the device camera', () {
    // No override: the factory consults CameraConfig, which on this host
    // (macOS, not a simulator) must answer "real".
    final service = CameraFactory.resolve(navigatorKey: navigatorKey);

    expect(service, isA<RealImageCaptureService>());
    expect(service.isMock, isFalse,
        reason: 'a build that is not on a simulator must use the real camera, '
            'or placeholder images reach production uploads');
  });

  test('both implementations satisfy the same interface', () {
    // The whole point of the seam: a feature holding one cannot tell which it
    // has, beyond the developer-indicator flag.
    final mock =
        CameraFactory.resolve(navigatorKey: navigatorKey, forceMock: true);
    final real =
        CameraFactory.resolve(navigatorKey: navigatorKey, forceMock: false);

    expect(mock.isAvailable, isTrue);
    expect(real.isAvailable, isTrue);
    expect(mock.runtimeType, isNot(real.runtimeType));
  });
}
