import 'package:flutter/material.dart';
import 'package:steelforce/core/camera/camera_mode.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/core/camera/mock/mock_camera_asset.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// The stand-in camera, shaped like a camera.
///
/// A plain asset picker would have been less code, but it would also have been
/// a different interaction from the one it replaces: the real flow is
/// *frame → capture → the image comes back*, and a developer verifying a
/// capture path needs to exercise that, not a list. So this previews a shot,
/// takes it, lets it be retaken, and returns on confirm.
///
/// Developer-facing scaffolding: the strings are English-only on purpose, since
/// this screen cannot be reached on a physical device under the default
/// configuration.
class MockCameraScreen extends StatefulWidget {
  const MockCameraScreen({super.key, required this.source});

  /// Which affordance the caller asked for. Only changes the wording — both
  /// paths return the same kind of image, exactly as the real picker does.
  final ImageCaptureSource source;

  @override
  State<MockCameraScreen> createState() => _MockCameraScreenState();
}

enum _Stage { framing, captured }

class _MockCameraScreenState extends State<MockCameraScreen> {
  MockCameraAsset _selected = MockCameraAsset.fallback;
  _Stage _stage = _Stage.framing;

  /// Set when an asset fails to decode, so the screen shows the failure rather
  /// than an empty frame the developer has to guess at.
  Object? _previewError;

  void _capture() => setState(() => _stage = _Stage.captured);

  void _retake() => setState(() {
        _stage = _Stage.framing;
        _previewError = null;
      });

  void _confirm() => Navigator.of(context).pop(_selected);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      // Camera black rather than the app surface: the point is that this reads
      // as a viewfinder at a glance.
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _header(colors),
            Expanded(child: _viewfinder()),
            _controls(colors),
          ],
        ),
      ),
    );
  }

  Widget _header(AppThemeColors colors) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(12),
        vertical: context.rh(8),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: 'Cancel',
            // Null is what the real picker returns when the user backs out, so
            // every caller's existing cancel path already handles this.
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              widget.source == ImageCaptureSource.camera
                  ? 'Camera'
                  : 'Photo library',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: context.rsp(16),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Balances the close button so the title stays centred.
          SizedBox(width: context.rw(48)),
        ],
      ),
    );
  }

  Widget _viewfinder() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rw(16)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(context.rr(14)),
            child: ColoredBox(
              color: const Color(0xFF141414),
              child: _preview(),
            ),
          ),
          if (_stage == _Stage.framing) const _ViewfinderFrame(),
          Positioned(
            left: 0,
            right: 0,
            bottom: context.rh(10),
            child: Center(child: _modeBadge()),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    if (_previewError != null) return _errorState();

    return Image.asset(
      _selected.assetPath,
      fit: BoxFit.contain,
      // A missing asset means pubspec.yaml and the folder have drifted apart.
      // Shown, not swallowed — otherwise it looks like an empty viewfinder.
      errorBuilder: (context, error, stack) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _previewError = error);
        });
        return _errorState();
      },
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.rr(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined,
                color: Colors.white70, size: context.rr(40)),
            SizedBox(height: context.rh(12)),
            Text(
              'Could not load ${_selected.fileName}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: context.rsp(14)),
            ),
            SizedBox(height: context.rh(6)),
            Text(
              'Check that ${MockCameraAsset.directory}/ is listed under '
              'assets in pubspec.yaml — Flutter does not recurse into '
              'subdirectories.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white54, fontSize: context.rsp(11.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeBadge() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(12),
        vertical: context.rh(5),
      ),
      decoration: BoxDecoration(
        color: Colors.amber.shade700.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        CameraConfig.isForced
            ? 'MOCK CAMERA · forced'
            : 'MOCK CAMERA · simulator',
        style: TextStyle(
          color: Colors.black,
          fontSize: context.rsp(10.5),
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _controls(AppThemeColors colors) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        context.rw(16),
        context.rh(12),
        context.rw(16),
        context.rh(16),
      ),
      color: Colors.black,
      child: Column(
        children: [
          _assetStrip(),
          SizedBox(height: context.rh(14)),
          if (_stage == _Stage.framing)
            _ShutterButton(onPressed: _previewError == null ? _capture : null)
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _retake,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: EdgeInsets.symmetric(vertical: context.rh(14)),
                    ),
                    label: const Text('Retake'),
                  ),
                ),
                SizedBox(width: context.rw(12)),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.success,
                      padding: EdgeInsets.symmetric(vertical: context.rh(14)),
                    ),
                    label: const Text('Use photo'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// The test-image selector. Horizontal so it stays one row at any width, and
  /// disabled once a shot is taken — the real camera does not let you change
  /// what you photographed after the fact either.
  Widget _assetStrip() {
    final locked = _stage == _Stage.captured;

    return SizedBox(
      height: context.rh(34),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: MockCameraAsset.values.length,
        separatorBuilder: (_, __) => SizedBox(width: context.rw(8)),
        itemBuilder: (context, index) {
          final asset = MockCameraAsset.values[index];
          final selected = asset == _selected;
          return Opacity(
            opacity: locked && !selected ? 0.35 : 1,
            child: ChoiceChip(
              label: Text(asset.label),
              selected: selected,
              onSelected: locked
                  ? null
                  : (_) => setState(() {
                        _selected = asset;
                        _previewError = null;
                      }),
              labelStyle: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontSize: context.rsp(11.5),
                fontWeight: FontWeight.w700,
              ),
              backgroundColor: const Color(0xFF242424),
              selectedColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
            ),
          );
        },
      ),
    );
  }
}

/// The corner brackets that make a black rectangle read as a viewfinder.
class _ViewfinderFrame extends StatelessWidget {
  const _ViewfinderFrame();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.all(context.rr(22)),
        child: CustomPaint(painter: _CornerPainter()),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const len = 26.0;
    void corner(Offset o, double dx, double dy) {
      canvas.drawLine(o, o.translate(len * dx, 0), paint);
      canvas.drawLine(o, o.translate(0, len * dy), paint);
    }

    corner(Offset.zero, 1, 1);
    corner(Offset(size.width, 0), -1, 1);
    corner(Offset(0, size.height), 1, -1);
    corner(Offset(size.width, size.height), -1, -1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The shutter: a ring around a filled disc, as every camera app draws it.
class _ShutterButton extends StatelessWidget {
  const _ShutterButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final size = context.rr(66);

    return Semantics(
      button: true,
      label: 'Capture',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled ? Colors.white : Colors.white30,
              width: 3.5,
            ),
          ),
          child: Center(
            child: Container(
              width: size * 0.76,
              height: size * 0.76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled ? Colors.white : Colors.white24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
