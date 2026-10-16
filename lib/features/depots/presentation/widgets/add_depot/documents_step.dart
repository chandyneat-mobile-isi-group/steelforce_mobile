part of '../add_depot_bottom_sheet.dart';

extension DocumentsStepExtension on _AddDepotBottomSheetState {
  // ===========================================================================
  // STEP 5 — Documents & review
  // ===========================================================================
  Widget _buildPhotoTile(
    String kind,
    String labelKey,
    IconData icon,
    BpDepotDraft draft,
    Map<String, String> errors, {
    bool required = true,
  }) {
    final attachment = draft.getAttachment(kind);
    final isAttached = attachment != null;
    final isUploading = attachment?.isUploading == true;
    final isUploaded = attachment?.isUploaded == true;
    final hasUploadError = attachment?.uploadError != null && !isUploaded;

    String subtitle;
    if (isUploading) {
      subtitle = 'add_depot.photo_uploading'.tr;
    } else if (isUploaded) {
      subtitle = 'add_depot.photo_uploaded'.tr;
    } else if (hasUploadError) {
      subtitle = 'add_depot.photo_upload_failed'.tr;
    } else if (isAttached) {
      subtitle = 'add_depot.photo_attached'.tr;
    } else {
      subtitle = 'add_depot.photo_tap'.tr;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionTile(
          label: labelKey.tr + (required ? ' *' : ''),
          sub: subtitle,
          icon: icon,
          // Captured counts as done: photographs are sent after the rep
          // confirms, so "uploaded" is never reached while the form is open.
          completed: isUploaded || (isAttached && !hasUploadError),
          isUploading: isUploading,
          hasError: hasUploadError,
          onTap: () {
            if (isUploading) return;
            if (hasUploadError) {
              _bloc.add(RetryUploadAttachment(kind));
            } else {
              unawaited(_capturePhoto(kind));
            }
          },
        ),
        if (errors[kind] != null)
          _errorText('add_depot.error.photo_required'.tr),
      ],
    );
  }

  Widget _buildDocumentPhotosSection(
    BpDepotDraft draft,
    Map<String, String> errors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _twoCol(
          _buildPhotoTile(
            'outlet_front',
            'add_depot.photo_front',
            Icons.storefront_rounded,
            draft,
            errors,
          ),
          _buildPhotoTile(
            'outlet_inside',
            'add_depot.photo_inside',
            Icons.store_rounded,
            draft,
            errors,
          ),
        ),
        _gap(8),
        _twoCol(
          _buildPhotoTile(
            'id_card',
            'add_depot.photo_id',
            Icons.badge_rounded,
            draft,
            errors,
          ),
          _buildPhotoTile(
            'patent_tax',
            'add_depot.photo_patent',
            Icons.receipt_long_rounded,
            draft,
            errors,
            required: false,
          ),
        ),
        if (draft.taxClass == '1') ...[
          _gap(8),
          _buildPhotoTile(
            'vat_cert',
            'add_depot.photo_vat',
            Icons.verified_rounded,
            draft,
            errors,
          ),
        ],
      ],
    );
  }

  Widget _buildRemarksSection(BpDepotDraft draft) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('add_depot.remark'.tr),
        _text(
          _remarkCtrl,
          'add_depot.remark_hint'.tr,
          maxLines: 4,
          onChanged: (v) => _edit((d) => d.remark = v),
        ),
        SizedBox(height: _spacing(16)),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'add_depot.credit_notice'.tr,
                  style: TextStyle(
                    fontSize: _fontSize(12),
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsStep(Map<String, String> errors) {
    final draft = _bloc.state.draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDocumentPhotosSection(draft, errors),
        _gap(8),
        _text(
          _remarkCtrl,
          'add_depot.remark_hint'.tr,
          label: 'add_depot.remark'.tr,
          icon: Icons.notes_rounded,
          compact: true,
          maxLines: 2,
          onChanged: (v) => _edit((d) => d.remark = v),
        ),
      ],
    );
  }

  Future<void> _capturePhoto(String kind) async {
    // Camera only — the point is on-site evidence, not a gallery pick.
    // Optimized compression (<=1024px / ~120-180KB, 65% quality) for rapid upload.
    final XFile? photo = await sl<ImageCaptureService>().capture(
      imageQuality: 65,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (photo == null || !mounted) return;
    _bloc.add(AttachmentAdded(BpAttachment(kind: kind, localPath: photo.path)));
  }

  /// Collapsed recap with an edit pencil per step, so a typo does not mean
  /// walking back through five screens.
}
