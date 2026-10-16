import 'package:flutter/widgets.dart';
import 'package:steelforce/core/camera/camera_mode.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/core/camera/mock/mock_image_capture_service.dart';
import 'package:steelforce/core/camera/real_image_capture_service.dart';
import 'package:steelforce/core/logging/debug_trace.dart';

const _trace = DebugTrace('camera');

/// Chooses the capture implementation for the running environment.
///
/// The single place platform detection is allowed to influence the camera. No
/// feature, screen or bloc may ask whether it is on a simulator — they resolve
/// [ImageCaptureService] from the service locator and use whatever they get.
abstract final class CameraFactory {
  /// Resolves the implementation for the current [CameraConfig].
  ///
  /// [navigatorKey] is only used by the stand-in, which pushes its own screen.
  /// It is required rather than optional so a caller cannot accidentally
  /// construct a mock that silently falls back to a default image because it
  /// had no way to show the picker.
  static ImageCaptureService resolve({
    required GlobalKey<NavigatorState> navigatorKey,
    bool? forceMock,
  }) {
    final useMock = forceMock ?? CameraConfig.useMock;

    _trace.step('factory', useMock ? 'mock camera' : 'real camera', {
      'requested': CameraConfig.requested.name,
      'forced': forceMock != null ? 'call-site' : null,
    });

    return useMock
        ? MockImageCaptureService(navigatorKey: navigatorKey)
        : RealImageCaptureService();
  }
}
