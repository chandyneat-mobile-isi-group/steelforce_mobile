import 'package:flutter/material.dart';
import 'package:steelforce/core/platform/device/device_insets.dart';
import 'package:steelforce/shared/widgets/keyboard_aware_scroll_view.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/platform/storage/local_files.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/my_visits/domain/entities/depot_stop_info.dart';
import 'package:steelforce/features/my_visits/domain/services/proof_photo_service.dart';

/// What the rep picked before confirming a skip: a reason is always present
/// (validated before the sheet can be dismissed with a result); the photo is
/// supporting evidence and may be omitted.
class SkipVisitResult {
  const SkipVisitResult({required this.reason, this.photoPath});
  final String reason;
  final String? photoPath;
}

const _presetReasons = [
  'Shop closed',
  'Depot not available',
  'No stock needed',
  'Access denied',
];

/// Asks the rep why they're skipping [depot] before the stop dashboard
/// commits anything — a plain confirm button used to submit a hardcoded
/// reason with no way to attach proof. Returns `null` if the rep backs out.
Future<SkipVisitResult?> showSkipVisitDialog(
  BuildContext context, {
  required DepotStopInfo depot,
}) {
  return showModalBottomSheet<SkipVisitResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SkipVisitSheet(depot: depot),
  );
}

class _SkipVisitSheet extends StatefulWidget {
  const _SkipVisitSheet({required this.depot});
  final DepotStopInfo depot;

  @override
  State<_SkipVisitSheet> createState() => _SkipVisitSheetState();
}

class _SkipVisitSheetState extends State<_SkipVisitSheet> {
  String? _reason;
  final _otherController = TextEditingController();
  String? _photoPath;
  bool _capturing = false;

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      final result = await sl<ProofPhotoService>().captureStamped(
        latitude: widget.depot.latitude,
        longitude: widget.depot.longitude,
      );
      if (result != null && mounted) {
        setState(() => _photoPath = result.filePath);
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  bool get _canSubmit =>
      _reason != null &&
      (_reason != 'Other' || _otherController.text.trim().isNotEmpty);

  void _submit() {
    if (!_canSubmit) return;
    final reason = _reason == 'Other' ? _otherController.text.trim() : _reason!;
    Navigator.of(context)
        .pop(SkipVisitResult(reason: reason, photoPath: _photoPath));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    // Scoped read: `viewInsetsOf` rebuilds this sheet on keyboard changes only,
    // where `MediaQuery.of` also subscribed it to size, orientation and
    // text-scale. The sheet keeps its own container and SafeArea rather than
    // adopting AppBottomSheet, because its background is painted *inside* the
    // safe area and moving that would change where the card ends.
    return Padding(
      padding: EdgeInsets.only(bottom: context.deviceInsets.keyboard),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(context.rr(24))),
        ),
        padding: EdgeInsets.fromLTRB(
            context.rw(20), context.rh(12), context.rw(20), context.rh(20)),
        child: SafeArea(
          top: false,
          // Caps the card at 90% of the screen so a short phone with the
          // keyboard up scrolls instead of overflowing.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: context.deviceInsets.screenSize.height * 0.9,
            ),
            child: KeyboardAwareScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: context.rw(36),
                      height: context.rh(4),
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: context.rh(16)),
                  Text(
                    'Skip Visit',
                    style: TextStyle(
                      fontSize: context.rsp(17),
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: context.rh(4)),
                  Text(
                    widget.depot.name,
                    style: TextStyle(
                        fontSize: context.rsp(12.5),
                        color: colors.textSecondary),
                  ),
                  SizedBox(height: context.rh(18)),
                  Text(
                    'Reason',
                    style: TextStyle(
                      fontSize: context.rsp(12.5),
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: context.rh(8)),
                  Wrap(
                    spacing: context.rw(8),
                    runSpacing: context.rh(8),
                    children: _presetReasons.map((r) {
                      final selected = _reason == r;
                      return ChoiceChip(
                        label: Text(r),
                        selected: selected,
                        onSelected: (_) => setState(() => _reason = r),
                        selectedColor: scheme.error.withValues(alpha: 0.14),
                        labelStyle: TextStyle(
                          color: selected ? scheme.error : colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: context.rsp(12),
                        ),
                        backgroundColor: colors.surfaceSoft,
                        side: BorderSide(
                            color: selected ? scheme.error : colors.border),
                      );
                    }).toList(),
                  ),
                  if (_reason == 'Other') ...[
                    SizedBox(height: context.rh(10)),
                    TextField(
                      controller: _otherController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Describe the reason',
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(context.rr(10))),
                      ),
                    ),
                  ],
                  SizedBox(height: context.rh(18)),
                  Text(
                    'Photo (optional)',
                    style: TextStyle(
                      fontSize: context.rsp(12.5),
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: context.rh(8)),
                  GestureDetector(
                    onTap: _capturing ? null : _capturePhoto,
                    child: Container(
                      height: context.rh(110),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: colors.surfaceSoft,
                        borderRadius: BorderRadius.circular(context.rr(12)),
                        border: Border.all(color: colors.border),
                      ),
                      child: _capturing
                          ? Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.2, color: scheme.primary),
                            )
                          : _photoPath != null
                              ? ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(context.rr(12)),
                                  child: localFileImage(
                                    _photoPath!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: context.rh(110),
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt_rounded,
                                        color: scheme.primary,
                                        size: context.rr(24)),
                                    SizedBox(height: context.rh(6)),
                                    Text(
                                      'Take photo',
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: context.rsp(12),
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                  ),
                  SizedBox(height: context.rh(20)),
                  SizedBox(
                    width: double.infinity,
                    height: context.rh(48),
                    child: ElevatedButton(
                      onPressed: _canSubmit ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: colors.border,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(context.rr(12))),
                      ),
                      child: Text(
                        'Submit Skip',
                        style: TextStyle(
                            fontSize: context.rsp(14.5),
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
