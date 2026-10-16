import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:steelforce/core/animations/fade_slide_transition.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/inventory_photo_grid.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/inventory_photo_sources.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/inventory_submit_bar.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/inventory_survey_intro_card.dart';
import 'package:steelforce/features/my_visits/presentation/widgets/visit_step_bar.dart';

/// A photo picked for one slot, with its preview bytes.
typedef SurveyShot = ({XFile file, Uint8List preview, DateTime takenAt});

/// The Inventory Availability step: the Add tile takes a photo or uploads
/// several at once, then Submit. Submit needs at least
/// [minPhotos]; the rep moves on only once every photo is saved on the
/// phone.
class InventorySurveyScreen extends StatefulWidget {
  const InventorySurveyScreen({
    super.key,
    required this.depotName,
    required this.capture,
    required this.onPhotosSubmitted,
    required this.onSubmit,
  });

  static const String routeName = 'my-visits-inventory-survey';
  static const int minPhotos = 3;

  /// Enough to cover a depot, few enough to review in one strip.
  static const int maxPhotos = 5;

  final String depotName;
  final ImageCaptureService capture;

  /// Saves the photos. Awaited before [onSubmit]; a throw keeps the rep here
  /// with the photos still on screen.
  final Future<void> Function(List<SurveyShot> shots) onPhotosSubmitted;

  /// Moves to the next step.
  final VoidCallback onSubmit;

  @override
  State<InventorySurveyScreen> createState() => _InventorySurveyScreenState();
}

class _InventorySurveyScreenState extends State<InventorySurveyScreen> {
  final List<SurveyShot> _shots = [];

  /// True while a pick is in progress.
  bool _adding = false;
  bool _saving = false;
  bool _saveFailed = false;

  int get _room => InventorySurveyScreen.maxPhotos - _shots.length;

  Future<void> _add(ImageCaptureSource source) async {
    if (_adding || _saving) return;
    if (_room <= 0) {
      _toast('my_visits.survey.limit');
      return;
    }
    setState(() => _adding = true);
    try {
      final List<XFile> files;
      if (source == ImageCaptureSource.camera) {
        final shot =
            await widget.capture.capture(imageQuality: 70, maxWidth: 1600);
        files = shot == null ? const [] : [shot];
      } else {
        files = await widget.capture.pickMultipleFromGallery(
            imageQuality: 70, maxWidth: 1600, limit: _room);
      }
      final kept = files.take(_room).toList();
      final shots = <SurveyShot>[
        for (final file in kept)
          (
            file: file,
            preview: await file.readAsBytes(),
            takenAt: DateTime.now(),
          ),
      ];
      if (!mounted || shots.isEmpty) return;
      setState(() {
        _shots.addAll(shots);
        _saveFailed = false;
      });
      if (kept.length < files.length) _toast('my_visits.survey.limit');
    } catch (_) {
      if (mounted) _toast('my_visits.survey.photo_failed');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  void _toast(String key) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(key.trParams({'max': InventorySurveyScreen.maxPhotos})),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _chooseSource() async {
    final source = await showModalBottomSheet<ImageCaptureSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text('my_visits.inventory.take_photo'.tr),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImageCaptureSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('my_visits.survey.upload'.tr),
              subtitle: Text('my_visits.survey.upload_hint'.tr),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImageCaptureSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _add(source);
  }

  Future<void> _submit() async {
    final shots = List<SurveyShot>.of(_shots);
    if (shots.length < InventorySurveyScreen.minPhotos || _saving) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await widget.onPhotosSubmitted(shots);
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
    const min = InventorySurveyScreen.minPhotos;
    const max = InventorySurveyScreen.maxPhotos;
    final canAdd = !_saving && _room > 0 && widget.capture.isAvailable;
    final sections = <Widget>[
      const InventorySurveyIntroCard(minPhotos: min, maxPhotos: max),
      InventoryPhotosCard(
        photos: [for (final s in _shots) (id: s.file, bytes: s.preview)],
        minPhotos: min,
        maxPhotos: max,
        onRemove: _saving ? null : (i) => setState(() => _shots.removeAt(i)),
        onAdd: canAdd && !_adding ? _chooseSource : null,
      ),
      if (!widget.capture.isAvailable)
        Text('my_visits.inventory.camera_unavailable'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: context.rsp(13), color: colors.textSecondary)),
      const InventoryPhotoTips(),
    ];

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: colors.canvas,
        appBar: AppBar(
          backgroundColor: colors.canvas,
          scrolledUnderElevation: 0.5,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('my_visits.inventory.title'.tr,
                  style: TextStyle(
                      fontSize: context.rsp(17), fontWeight: FontWeight.w800)),
              Row(
                children: [
                  Icon(Icons.location_on_rounded,
                      size: context.rr(14), color: colors.textSecondary),
                  SizedBox(width: context.rw(4)),
                  Flexible(
                    child: Text(widget.depotName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: context.rsp(12),
                            color: colors.textSecondary)),
                  ),
                ],
              ),
            ],
          ),
          bottom: const VisitStepBar(current: VisitStep.inventory),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  // Capped on a tablet so the cards do not stretch edge to
                  // edge.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: ListView(
                      padding: EdgeInsets.all(context.rw(16)),
                      children: [
                        for (final (i, section) in sections.indexed) ...[
                          if (i > 0) SizedBox(height: context.rh(14)),
                          FadeSlideIn(
                            delay: FadeSlideIn.staggerDelay(i,
                                interval: const Duration(milliseconds: 70)),
                            child: section,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              InventorySubmitBar(
                count: _shots.length,
                minPhotos: min,
                saving: _saving,
                saveFailed: _saveFailed,
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
