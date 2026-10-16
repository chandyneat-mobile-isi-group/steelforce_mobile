part of '../add_depot_bottom_sheet.dart';

extension TabletLayoutExtension on _AddDepotBottomSheetState {
  Widget _buildTabletStageBody(AddDepotState state) {
    return switch (_tabletStage) {
      0 => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildSectionCard(
                title: 'add_depot.steps.identity'.tr,
                subtitle: 'Who is the depot (BP header & names)',
                icon: Icons.person_outline_rounded,
                child: _buildIdentityStep(state.errors),
              ),
            ),
            SizedBox(width: _spacing(24)),
            Expanded(
              child: _buildSectionCard(
                title: 'add_depot.steps.address'.tr,
                subtitle: 'Where are they located (Address & GPS)',
                icon: Icons.location_on_outlined,
                child: _buildAddressStep(state.errors),
              ),
            ),
          ],
        ),
      1 => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildSectionCard(
                title: 'add_depot.steps.contact'.tr,
                subtitle: 'How do we reach them (Phones & Contact person)',
                icon: Icons.phone_outlined,
                child: _buildContactStep(state.errors),
              ),
            ),
            SizedBox(width: _spacing(24)),
            Expanded(
              child: _buildSectionCard(
                title: 'add_depot.steps.sales_terms'.tr,
                subtitle: 'Commercial setup (Pricing, Payment & Tax)',
                icon: Icons.receipt_long_outlined,
                child: _buildSalesTermsStep(state.errors),
              ),
            ),
          ],
        ),
      2 => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildSectionCard(
                title: 'add_depot.steps.documents'.tr,
                subtitle: 'Verification documents & business license photos',
                icon: Icons.attach_file_rounded,
                child: _buildDocumentPhotosSection(state.draft, state.errors),
              ),
            ),
            SizedBox(width: _spacing(24)),
            Expanded(
              child: _buildSectionCard(
                title: 'add_depot.remark'.tr,
                subtitle: 'Internal notes & instructions for Sales HQ',
                icon: Icons.description_outlined,
                child: _buildRemarksSection(state.draft),
              ),
            ),
          ],
        ),
      3 => _buildTabletPreviewScreen(state.draft),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required Widget child,
  }) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(widget.isTablet ? 24 : context.rw(16)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(18)),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.primary, size: _fontSize(20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: _fontSize(16),
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: _fontSize(12),
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  void _goToTabletStage(int stage) {
    setState(() => _tabletStage = stage);
    switch (stage) {
      case 0:
        _bloc.add(const GoToStep(BpFormStep.identity));
        break;
      case 1:
        _bloc.add(const GoToStep(BpFormStep.contact));
        break;
      case 2:
        _bloc.add(const GoToStep(BpFormStep.documents));
        break;
      case 3:
        break;
    }
  }

  void _editFromPreview(int targetStage, BpFormStep step) {
    setState(() => _tabletStage = targetStage);
    _bloc.add(GoToStep(step));
  }

  void _handleTabletNext(AddDepotState state) {
    if (_tabletStage == 0) {
      final idErrors = state.draft.validateStep(BpFormStep.identity);
      final addrErrors = state.draft.validateStep(BpFormStep.address);
      if (idErrors.isNotEmpty) {
        _bloc.add(const GoToStep(BpFormStep.identity));
        _bloc.add(const NextStep());
        return;
      }
      if (addrErrors.isNotEmpty) {
        _bloc.add(const GoToStep(BpFormStep.address));
        _bloc.add(const NextStep());
        return;
      }
      _goToTabletStage(1);
    } else if (_tabletStage == 1) {
      final contactErrors = state.draft.validateStep(BpFormStep.contact);
      final termsErrors = state.draft.validateStep(BpFormStep.salesTerms);
      if (contactErrors.isNotEmpty) {
        _bloc.add(const GoToStep(BpFormStep.contact));
        _bloc.add(const NextStep());
        return;
      }
      if (termsErrors.isNotEmpty) {
        _bloc.add(const GoToStep(BpFormStep.salesTerms));
        _bloc.add(const NextStep());
        return;
      }
      _goToTabletStage(2);
    } else if (_tabletStage == 2) {
      final docErrors = state.draft.validateStep(BpFormStep.documents);
      if (docErrors.isNotEmpty) {
        _bloc.add(const GoToStep(BpFormStep.documents));
        _bloc.add(const NextStep());
        return;
      }
      _goToTabletStage(3);
    } else if (_tabletStage == 3) {
      _bloc.add(const SubmitToHQ());
    }
  }

  Widget _buildTabletNavigationButtons(AddDepotState state) {
    final isFirst = _tabletStage == 0;
    final isLast = _tabletStage == 3;
    final isUploadingDoc =
        _tabletStage == 2 && state.draft.attachments.any((a) => a.isUploading);
    final needsCredit =
        SapMasterData.paymentTermNeedsCreditApproval(state.draft.paymentTerm);

    const btnPadding = EdgeInsets.symmetric(vertical: 20);

    return Row(
      children: [
        if (!isFirst) ...[
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: btnPadding,
                side: BorderSide(color: context.appColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                if (_tabletStage == 3) {
                  _goToTabletStage(2);
                } else if (_tabletStage == 2) {
                  _goToTabletStage(1);
                } else if (_tabletStage == 1) {
                  _goToTabletStage(0);
                }
              },
              icon: const Icon(Icons.arrow_back),
              label: Text(
                _tabletStage == 3 ? 'Back to Edit' : 'Previous',
                style: TextStyle(
                  fontSize: _fontSize(14),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: btnPadding,
              backgroundColor: isLast
                  ? context.appColors.success
                  : Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: (state.isBusy || isUploadingDoc)
                ? null
                : () => _handleTabletNext(state),
            icon: isUploadingDoc
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isLast ? Icons.check_circle_outline : Icons.arrow_forward,
                    color: Colors.white,
                  ),
            label: Text(
              isUploadingDoc
                  ? 'add_depot.photo_uploading'.tr
                  : (isLast
                      ? (needsCredit
                          ? 'add_depot.send_for_credit_approval'.tr
                          : 'add_depot.send_to_hq'.tr)
                      : (_tabletStage == 2
                          ? 'Preview & Review'
                          : 'add_depot.next_step'.tr)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: _fontSize(15),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
