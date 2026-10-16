import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// The Inventory Visibility step: one photo of the depot's stock, then on to
/// the next step.
///
/// A photo replaced the per-item High/Medium/Low sheet. The sheet ran on a
/// hardcoded demo catalog that could never be persisted, so a rep spent a
/// minute tapping and nothing was recorded. A photo is real evidence today,
/// and it syncs with the stop's other captures.
///
/// The camera opens on arrival, because taking the photo is the whole task.
/// Submit stays disabled until there is a photo. A shut shop can still be
/// photographed, so the gate never forces a rep to make data up.
class InventoryVisibilityScreen extends StatefulWidget {
  const InventoryVisibilityScreen({
    super.key,
    required this.depotName,
    required this.capture,
    required this.onPhotoSubmitted,
    required this.onSubmit,
    this.openCameraOnStart = true,
  });

  /// `RouteSettings.name` for this screen — the resume-dispatcher key that
  /// lets "Continue Working" rebuild it after a checked-in stop with no
  /// further progress (see `resume_workflow_dispatcher.dart`).
  static const String routeName = 'my-visits-inventory-visibility';

  final String depotName;

  /// Resolved by the caller, so the device camera and the simulator stand-in
  /// take the identical path through this screen.
  final ImageCaptureService capture;

  /// Saves the photo. Awaited before [onSubmit], so the rep never leaves
  /// this step until the photo is safely stored on the phone. A throw keeps
  /// the rep here with the photo still on screen.
  final Future<void> Function(XFile photo, DateTime takenAt) onPhotoSubmitted;

  /// Moves to the next step.
  final VoidCallback onSubmit;

  /// Off in tests that need to pump the empty state first.
  final bool openCameraOnStart;

  @override
  State<InventoryVisibilityScreen> createState() =>
      _InventoryVisibilityScreenState();
}

class _InventoryVisibilityScreenState extends State<InventoryVisibilityScreen> {
  XFile? _photo;
  Uint8List? _preview;
  DateTime? _takenAt;
  bool _capturing = false;
  bool _saving = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.openCameraOnStart && widget.capture.isAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _takePhoto());
    }
  }

  Future<void> _takePhoto() async {
    if (_capturing || _saving) return;
    setState(() => _capturing = true);
    try {
      final shot = await widget.capture.capture(
        imageQuality: 70,
        maxWidth: 1600,
      );
      // Backing out of the camera keeps any photo already taken.
      if (shot == null) return;
      final bytes = await shot.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = shot;
        _preview = bytes;
        _takenAt = DateTime.now();
        _saveFailed = false;
      });
    } catch (_) {
      // Permission denied or no camera: the empty state offers another try.
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _submit() async {
    final photo = _photo;
    final takenAt = _takenAt;
    if (photo == null || takenAt == null || _saving) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await widget.onPhotoSubmitted(photo, takenAt);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveFailed = true;
        });
      }
      return;
    }
    if (!mounted) return;
    widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final hasPhoto = _preview != null;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${'my_visits.inventory.title'.tr} (${'my_visits.inventory.required'.tr})',
              style: TextStyle(
                  fontSize: context.rsp(16), fontWeight: FontWeight.w800),
            ),
            Text(
              widget.depotName,
              style: TextStyle(
                  fontSize: context.rsp(11.5), color: colors.textSecondary),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                  horizontal: context.rw(16), vertical: context.rh(10)),
              color: scheme.primary.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Icon(Icons.photo_camera_rounded,
                      color: scheme.primary, size: context.rr(20)),
                  SizedBox(width: context.rw(10)),
                  Expanded(
                    child: Text(
                      'my_visits.inventory.instruction'.tr,
                      style: TextStyle(
                          fontSize: context.rsp(12),
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(context.rw(16)),
                child: AnimatedSwitcher(
                  duration: AppDurations.fast,
                  child: hasPhoto
                      ? _PhotoPreview(
                          key: const ValueKey('preview'),
                          bytes: _preview!,
                          onRetake: _saving ? null : _takePhoto,
                        )
                      : _EmptyPhoto(
                          key: const ValueKey('empty'),
                          busy: _capturing,
                          available: widget.capture.isAvailable,
                          onTakePhoto: _takePhoto,
                        ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(context.rw(16)),
              decoration: BoxDecoration(
                color: colors.card,
                border: Border(top: BorderSide(color: colors.border)),
                boxShadow: colors.cardShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_saveFailed) ...[
                    Text(
                      'my_visits.inventory.save_failed'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: context.rsp(11.5),
                        fontWeight: FontWeight.w700,
                        color: scheme.error,
                      ),
                    ),
                    SizedBox(height: context.rh(8)),
                  ],
                  ElevatedButton.icon(
                    onPressed: hasPhoto && !_saving ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      disabledBackgroundColor: colors.border,
                      disabledForegroundColor: colors.textDisabled,
                      minimumSize: Size(double.infinity, context.rh(48)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.rr(12))),
                    ),
                    icon: _saving
                        ? SizedBox.square(
                            dimension: context.rr(18),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: scheme.onPrimary),
                          )
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(
                      hasPhoto
                          ? 'my_visits.inventory.submit'.tr
                          : 'my_visits.inventory.photo_needed'.tr,
                      style: TextStyle(
                          fontSize: context.rsp(15),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown before a photo exists: the rep backed out of the camera, or it
/// could not open.
class _EmptyPhoto extends StatelessWidget {
  const _EmptyPhoto({
    super.key,
    required this.busy,
    required this.available,
    required this.onTakePhoto,
  });

  final bool busy;
  final bool available;
  final VoidCallback onTakePhoto;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.rw(20)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(14)),
        border: Border.all(color: colors.border),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_outlined,
              size: context.rr(48), color: colors.iconMuted),
          SizedBox(height: context.rh(12)),
          Text(
            available
                ? 'my_visits.inventory.photo_empty'.tr
                : 'my_visits.inventory.camera_unavailable'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.rsp(13),
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          SizedBox(height: context.rh(16)),
          if (available)
            OutlinedButton.icon(
              onPressed: busy ? null : onTakePhoto,
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.primary,
                minimumSize: Size(context.rw(180), context.rh(48)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.rr(12))),
              ),
              icon: const Icon(Icons.photo_camera_rounded),
              label: Text('my_visits.inventory.take_photo'.tr),
            ),
        ],
      ),
    );
  }
}

/// The captured photo with a way to take it again.
class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    super.key,
    required this.bytes,
    required this.onRetake,
  });

  final Uint8List bytes;
  final VoidCallback? onRetake;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.rr(14)),
            child: Container(
              width: double.infinity,
              color: colors.card,
              child: Semantics(
                image: true,
                label: 'my_visits.inventory.photo_label'.tr,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        SizedBox(height: context.rh(12)),
        OutlinedButton.icon(
          onPressed: onRetake,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(double.infinity, context.rh(48)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.rr(12))),
          ),
          icon: const Icon(Icons.replay_rounded),
          label: Text('my_visits.inventory.retake'.tr),
        ),
      ],
    );
  }
}
