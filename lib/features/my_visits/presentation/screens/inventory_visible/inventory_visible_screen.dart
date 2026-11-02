import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/camera/image_capture_service.dart';
import 'package:steelforce/core/error/failure_message.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_content_frame.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_action.dart';
import 'package:steelforce/features/app_coach/presentation/services/app_coach.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_keys.dart';
import 'package:steelforce/shared/widgets/brand_wallpaper_background.dart';
import 'package:steelforce/core/assets/app_assets.dart';

/// The Inventory Visibility step: three guided photos of the depot's stock,
/// then on to the next step.
///
/// Photos replaced the per-item High/Medium/Low sheet. The sheet ran on a
/// hardcoded demo catalog that could never be persisted, so a rep spent a
/// minute tapping and nothing was recorded. A photo is real evidence today,
/// and it syncs with the stop's other captures.
///
/// The camera opens on arrival for the first view. Submit stays disabled until
/// all three photos are captured or uploaded. A shut shop can still be
/// photographed, so the gate never forces a rep to make data up.
class InventoryVisibilityScreen extends StatefulWidget {
  const InventoryVisibilityScreen({
    super.key,
    required this.depotName,
    required this.capture,
    this.onPhotosSubmitted,
    this.onPhotoSubmitted,
    required this.onSubmit,
    this.openCameraOnStart = true,
  }) : assert(onPhotosSubmitted != null || onPhotoSubmitted != null);

  /// `RouteSettings.name` for this screen — the resume-dispatcher key that
  /// lets "Continue Working" rebuild it after a checked-in stop with no
  /// further progress (see `resume_workflow_dispatcher.dart`).
  static const String routeName = 'my-visits-inventory-visibility';

  final String depotName;

  /// Resolved by the caller, so the device camera and the simulator stand-in
  /// take the identical path through this screen.
  final ImageCaptureService capture;

  /// Saves all three photos. Awaited before [onSubmit], so the rep never
  /// leaves until every capture is safely stored. A throw keeps the photos
  /// visible so the failed upload can be retried.
  final Future<void> Function(List<InventoryPhotoCapture> photos)?
      onPhotosSubmitted;

  /// Backwards-compatible callback for existing embedders. New callers should
  /// persist the complete list atomically through [onPhotosSubmitted].
  final Future<void> Function(XFile photo, DateTime takenAt)? onPhotoSubmitted;

  /// Moves to the next step.
  final VoidCallback onSubmit;

  /// Off in tests that need to pump the empty state first.
  final bool openCameraOnStart;

  @override
  State<InventoryVisibilityScreen> createState() =>
      _InventoryVisibilityScreenState();
}

typedef InventoryPhotoCapture = ({XFile photo, DateTime takenAt});

class _InventoryVisibilityScreenState extends State<InventoryVisibilityScreen> {
  static const _photoCount = 3;
  static const _photoTitles = [
    'my_visits.inventory.guide.overview_title',
    'my_visits.inventory.guide.storage_title',
    'my_visits.inventory.guide.product_title',
  ];
  static const _photoHints = [
    'my_visits.inventory.guide.overview_hint',
    'my_visits.inventory.guide.storage_hint',
    'my_visits.inventory.guide.product_hint',
  ];
  static const _photoIcons = [
    Icons.warehouse_outlined,
    Icons.view_in_ar_outlined,
    Icons.inventory_2_outlined,
  ];
  static const _guideImages = [
    AppImages.inventoryGuideOverview,
    AppImages.inventoryGuideStorage,
    AppImages.inventoryGuideProduct,
  ];

  final List<XFile?> _photos = List<XFile?>.filled(_photoCount, null);
  final List<Uint8List?> _previews = List<Uint8List?>.filled(_photoCount, null);
  final List<DateTime?> _takenAt = List<DateTime?>.filled(_photoCount, null);
  int? _capturingSlot;
  bool _saving = false;
  bool _saveFailed = false;

  /// The server's reason for the last failed save, when it gave one.
  String? _saveError;

  @override
  void initState() {
    super.initState();
    // This app's "survey" step: the lesson waits here for the photo.
    AppCoach.notify(CoachAction.openVisitSurvey);
    if (widget.openCameraOnStart && widget.capture.isAvailable) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _acquirePhoto(0, ImageCaptureSource.camera));
    }
  }

  Future<void> _acquirePhoto(int index, ImageCaptureSource source) async {
    if (_capturingSlot != null || _saving) return;
    setState(() => _capturingSlot = index);
    try {
      final shot = await widget.capture.pick(
        source,
        imageQuality: 70,
        maxWidth: 1600,
      );
      // Backing out of the camera or gallery keeps existing captures.
      if (shot == null) return;
      final bytes = await shot.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photos[index] = shot;
        _previews[index] = bytes;
        _takenAt[index] = DateTime.now();
        _saveFailed = false;
      });
    } catch (_) {
      // Permission denied or no camera: the slot keeps its retry affordance.
    } finally {
      if (mounted) setState(() => _capturingSlot = null);
    }
  }

  Future<void> _submit() async {
    if (_photos.any((photo) => photo == null) ||
        _takenAt.any((takenAt) => takenAt == null) ||
        _saving) {
      return;
    }
    final captures = [
      for (var i = 0; i < _photoCount; i++)
        (photo: _photos[i]!, takenAt: _takenAt[i]!),
    ];
    HapticFeedback.mediumImpact();
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      final saveAll = widget.onPhotosSubmitted;
      if (saveAll != null) {
        await saveAll(captures);
      } else {
        for (final capture in captures) {
          await widget.onPhotoSubmitted!(capture.photo, capture.takenAt);
        }
      }
    } catch (error) {
      AppCoach.notify(CoachAction.submitVisitSurveyFailed);
      if (mounted) {
        setState(() {
          _saving = false;
          _saveFailed = true;
          _saveError = error is Failure ? error.userMessage : null;
        });
      }
      return;
    }
    if (!mounted) return;
    widget.onSubmit();
    // After the save landed and the flow moved on — never on the tap.
    AppCoach.notify(CoachAction.submitVisitSurveySucceeded);
  }

  Future<void> _showPhotoSource(int index) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              context.rh(4),
              context.pagePadding,
              context.rh(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: Text('my_visits.inventory.take_photo'.tr),
                  onTap: () {
                    Navigator.pop(sheet);
                    _acquirePhoto(index, ImageCaptureSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text('my_visits.inventory.upload_photo'.tr),
                  onTap: () {
                    Navigator.pop(sheet);
                    _acquirePhoto(index, ImageCaptureSource.gallery);
                  },
                ),
              ],
            ),
          ),
        ),
      );

  void _showFullImage(int index) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullScreenPhotoViewer(
          preview: _previews[index],
          assetPath: _guideImages[index],
          title: _photoTitles[index].tr,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final completedCount = _previews.whereType<Uint8List>().length;
    final allPhotosReady = completedCount == _photoCount;

    return Scaffold(
      backgroundColor: context.appColors.canvas,
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
      body: BrandWallpaperBody(
          style: BrandWallpaperStyle.vivid,
          child: SafeArea(
            // Three short rows read badly stretched across a landscape
            // tablet; cap the column like the other form screens.
            child: ResponsiveContentFrame(
              maxWidth: 760,
              child: Column(
                children: [
                  _InventoryGuideBanner(completed: completedCount),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.all(context.rw(16)),
                      itemCount: _photoCount,
                      separatorBuilder: (_, __) =>
                          SizedBox(height: context.rh(12)),
                      itemBuilder: (context, index) => _InventoryPhotoCard(
                        index: index,
                        title: _photoTitles[index].tr,
                        hint: _photoHints[index].tr,
                        icon: _photoIcons[index],
                        guideImage: _guideImages[index],
                        preview: _previews[index],
                        busy: _capturingSlot == index,
                        canAcquire: widget.capture.isAvailable,
                        onViewImage: () => _showFullImage(index),
                        onCamera: () =>
                            _acquirePhoto(index, ImageCaptureSource.camera),
                        onGallery: () =>
                            _acquirePhoto(index, ImageCaptureSource.gallery),
                        onRetake: () => _showPhotoSource(index),
                        saving: _saving,
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
                            _saveError ?? 'my_visits.inventory.save_failed'.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: context.rsp(11.5),
                              fontWeight: FontWeight.w700,
                              color: scheme.error,
                            ),
                          ),
                          SizedBox(height: context.rh(8)),
                        ],
                        Padding(
                          padding: EdgeInsets.only(bottom: context.rh(10)),
                          child: Row(
                            children: [
                              Icon(
                                allPhotosReady
                                    ? Icons.check_circle_rounded
                                    : Icons.photo_library_outlined,
                                color: allPhotosReady
                                    ? colors.success
                                    : colors.iconMuted,
                                size: context.rr(18),
                              ),
                              SizedBox(width: context.rw(8)),
                              Expanded(
                                child: Text(
                                  'my_visits.inventory.photo_progress'
                                      .trParams({
                                    'count': '$completedCount',
                                    'total': '$_photoCount',
                                  }),
                                  style: TextStyle(
                                    fontSize: context.rsp(12),
                                    fontWeight: FontWeight.w700,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        CoachKeys.wrap(
                          CoachKeys.visitSurveySubmit,
                          child: ElevatedButton.icon(
                            onPressed:
                                allPhotosReady && !_saving ? _submit : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                              disabledBackgroundColor: colors.border,
                              disabledForegroundColor: colors.textDisabled,
                              minimumSize:
                                  Size(double.infinity, context.rh(48)),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(context.rr(12))),
                            ),
                            icon: _saving
                                ? SizedBox.square(
                                    dimension: context.rr(18),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: scheme.onPrimary),
                                  )
                                : const Icon(Icons.check_circle_rounded),
                            label: Text(
                              allPhotosReady
                                  ? 'my_visits.inventory.submit'.tr
                                  : 'my_visits.inventory.photos_needed'.tr,
                              style: TextStyle(
                                  fontSize: context.rsp(15),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )),
    );
  }
}

class _InventoryGuideBanner extends StatelessWidget {
  const _InventoryGuideBanner({required this.completed});

  final int completed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
        context.rw(16),
        context.rh(10),
        context.rw(16),
        0,
      ),
      padding: EdgeInsets.all(context.rw(12)),
      // Solid, like the photo cards: over the vivid wallpaper a translucent
      // tint left dark text on bright blue.
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(14)),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
        boxShadow: colors.cardShadow,
      ),
      child: Row(
        children: [
          Icon(Icons.photo_camera_back_outlined,
              color: scheme.primary, size: context.rr(22)),
          SizedBox(width: context.rw(10)),
          Expanded(
            child: Text(
              'my_visits.inventory.instruction'.tr,
              style: TextStyle(
                fontSize: context.rsp(12),
                height: 1.35,
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: context.rw(8)),
          Text(
            '$completed/3',
            style: TextStyle(
              fontSize: context.rsp(12),
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryPhotoCard extends StatelessWidget {
  const _InventoryPhotoCard({
    required this.index,
    required this.title,
    required this.hint,
    required this.icon,
    required this.guideImage,
    required this.preview,
    required this.busy,
    required this.canAcquire,
    required this.onViewImage,
    required this.onCamera,
    required this.onGallery,
    required this.onRetake,
    required this.saving,
  });

  final int index;
  final String title;
  final String hint;
  final IconData icon;
  final String guideImage;
  final Uint8List? preview;
  final bool busy;
  final bool canAcquire;
  final VoidCallback onViewImage;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRetake;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final hasPhoto = preview != null;
    return AnimatedContainer(
      duration: AppDurations.medium,
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.all(context.rw(12)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(18)),
        border: Border.all(
          color:
              hasPhoto ? colors.success.withValues(alpha: 0.48) : colors.border,
          width: hasPhoto ? 1.4 : 1,
        ),
        boxShadow: colors.cardShadow,
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: title,
            hint: 'my_visits.inventory.view_full_screen_hint'.tr,
            child: InkWell(
              onTap: onViewImage,
              borderRadius: BorderRadius.circular(context.rr(12)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(context.rr(12)),
                child: SizedBox(
                  width: context.rw(98),
                  height: context.rh(92),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      preview != null
                          ? Image.memory(preview!, fit: BoxFit.cover)
                          : _GuideIllustration(
                              icon: icon,
                              image: guideImage,
                              step: index + 1,
                            ),
                      Positioned(
                        right: context.rw(5),
                        bottom: context.rh(5),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(context.rr(4)),
                            child: Icon(
                              Icons.zoom_in_rounded,
                              size: context.rr(15),
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: context.rw(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: context.rsp(13),
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    if (hasPhoto)
                      Icon(Icons.check_circle_rounded,
                          color: colors.success, size: context.rr(18)),
                  ],
                ),
                SizedBox(height: context.rh(4)),
                Text(
                  hint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.rsp(11.5),
                    height: 1.3,
                    color: colors.textSecondary,
                  ),
                ),
                SizedBox(height: context.rh(6)),
                if (busy)
                  SizedBox(
                    height: context.rh(34),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox.square(
                        dimension: context.rr(20),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  )
                else if (hasPhoto)
                  TextButton.icon(
                    onPressed: saving ? null : onRetake,
                    icon: Icon(Icons.refresh_rounded, size: context.rr(17)),
                    label: Text('my_visits.inventory.retake'.tr),
                    style: TextButton.styleFrom(
                      minimumSize: Size(0, context.rh(34)),
                      padding: EdgeInsets.symmetric(horizontal: context.rw(8)),
                    ),
                  )
                else if (canAcquire)
                  Wrap(
                    spacing: context.rw(4),
                    children: [
                      TextButton.icon(
                        onPressed: saving ? null : onCamera,
                        icon: Icon(Icons.photo_camera_outlined,
                            size: context.rr(16)),
                        label: Text('my_visits.inventory.take_photo'.tr),
                        style: TextButton.styleFrom(
                          minimumSize: Size(0, context.rh(34)),
                          padding:
                              EdgeInsets.symmetric(horizontal: context.rw(6)),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: saving ? null : onGallery,
                        icon: Icon(Icons.upload_rounded, size: context.rr(16)),
                        label: Text('my_visits.inventory.upload_photo'.tr),
                        style: TextButton.styleFrom(
                          minimumSize: Size(0, context.rh(34)),
                          padding:
                              EdgeInsets.symmetric(horizontal: context.rw(6)),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'my_visits.inventory.camera_unavailable'.tr,
                    style: TextStyle(
                      fontSize: context.rsp(11),
                      color: colors.textHint,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FullScreenPhotoViewer extends StatelessWidget {
  const _FullScreenPhotoViewer({
    required this.preview,
    required this.assetPath,
    required this.title,
  });

  final Uint8List? preview;
  final String assetPath;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(title),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            clipBehavior: Clip.none,
            child: preview == null
                ? Image.asset(
                    assetPath,
                    fit: BoxFit.contain,
                    errorBuilder: _imageError,
                  )
                : Image.memory(
                    preview!,
                    fit: BoxFit.contain,
                    errorBuilder: _imageError,
                  ),
          ),
        ),
      );

  static Widget _imageError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) =>
      const Icon(
        Icons.broken_image_outlined,
        color: Colors.white70,
        size: 48,
      );
}

class _GuideIllustration extends StatelessWidget {
  const _GuideIllustration({
    required this.icon,
    required this.image,
    required this.step,
  });

  final IconData icon;
  final String image;
  final int step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          image,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => ColoredBox(
            color: scheme.primary.withValues(alpha: 0.08),
            child: Icon(icon, size: context.rr(42), color: scheme.primary),
          ),
        ),
        Positioned(
          right: context.rw(6),
          top: context.rh(6),
          child: CircleAvatar(
            radius: context.rr(11),
            backgroundColor: scheme.primary,
            child: Text(
              '$step',
              style: TextStyle(
                fontSize: context.rsp(10),
                fontWeight: FontWeight.w800,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
