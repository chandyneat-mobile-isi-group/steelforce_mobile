part of '../add_depot_bottom_sheet.dart';

extension MobileLayoutExtension on _AddDepotBottomSheetState {
  /// Back to the Depots screen. Safe at any step: the wizard keeps its
  /// draft, so reopening the form resumes where the rep left off.
  Widget _buildExitButton({required bool onBrand}) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: () => Navigator.of(context).maybePop(),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(48),
        backgroundColor: onBrand
            ? Colors.white.withValues(alpha: 0.18)
            : context.appColors.surfaceSoft,
        foregroundColor: onBrand ? Colors.white : scheme.onSurface,
        side: onBrand ? null : BorderSide(color: context.appColors.border),
      ),
      icon: const Icon(Icons.arrow_back_rounded, size: 22),
    );
  }

  // ===========================================================================
  // Phone Header + progress
  // ===========================================================================
  Widget _buildFormHeader(AddDepotState state) {
    final title = 'depots.add'.tr;
    final stepText = 'add_depot.step_indicator'
        .tr
        .replaceAll('{current}', '${state.currentStep.number}')
        .replaceAll('{total}', '${BpFormStep.values.length}');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isFullScreen)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _buildExitButton(onBrand: false),
                ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.appColors.textPrimary,
                  fontSize: _fontSize(19),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'add_depot.subtitle'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.appColors.textSecondary,
                  fontSize: _fontSize(11.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isTablet ? 16 : context.rw(12),
            vertical: widget.isTablet ? 8 : context.rh(5),
          ),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            stepText,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: _fontSize(11.5),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  /// Step progress indicator on the white sheet background.
  Widget _buildStepProgress(AddDepotState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          for (final step in BpFormStep.values) ...[
            GestureDetector(
              onTap: step.index < state.currentStep.index
                  ? () => _bloc.add(GoToStep(step))
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: step.index <= state.currentStep.index
                      ? Theme.of(context).colorScheme.primary
                      : context.appColors.card,
                  border: Border.all(
                    color: step.index <= state.currentStep.index
                        ? Colors.transparent
                        : context.appColors.border,
                    width: 1.5,
                  ),
                  boxShadow: step.index == state.currentStep.index
                      ? [
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.35),
                            blurRadius: 6,
                            spreadRadius: 1,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: step.index < state.currentStep.index
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 14)
                      : Text(
                          '${step.number}',
                          style: TextStyle(
                            color: step.index == state.currentStep.index
                                ? Theme.of(context).colorScheme.onPrimary
                                : context.appColors.textHint,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                          ),
                        ),
                ),
              ),
            ),
            if (step != BpFormStep.values.last)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: step.index < state.currentStep.index
                      ? Theme.of(context).colorScheme.primary
                      : context.appColors.border,
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Section Header with circular blue icon and title/description
  Widget _buildSectionHeader(AddDepotState state) {
    final (icon, title, subtitle) = switch (state.currentStep) {
      BpFormStep.identity => (
          Icons.person_rounded,
          'add_depot.steps.identity'.tr,
          'add_depot.section_hint.identity'.tr,
        ),
      BpFormStep.address => (
          Icons.location_on_rounded,
          'add_depot.steps.address'.tr,
          'add_depot.section_hint.address'.tr,
        ),
      BpFormStep.contact => (
          Icons.phone_in_talk_rounded,
          'add_depot.steps.contact'.tr,
          'add_depot.section_hint.contact'.tr,
        ),
      BpFormStep.salesTerms => (
          Icons.storefront_rounded,
          'add_depot.steps.sales_terms'.tr,
          'add_depot.section_hint.sales_terms'.tr,
        ),
      BpFormStep.salesPerformance => (
          Icons.insights_rounded,
          'add_depot.steps.sales_performance'.tr,
          'add_depot.section_hint.sales_performance'.tr,
        ),
      BpFormStep.documents => (
          Icons.folder_shared_rounded,
          'add_depot.steps.documents'.tr,
          'add_depot.section_hint.documents'.tr,
        ),
      BpFormStep.review => (
          Icons.assignment_turned_in_rounded,
          'add_depot.review_title'.tr,
          'add_depot.section_hint.review'.tr,
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: Theme.of(context).colorScheme.onPrimary, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: _fontSize(14),
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _fontSize(11),
                    color: context.appColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Navigation
  // ===========================================================================
  Widget _buildNavigationButtons(AddDepotState state) {
    final isFirst = state.isFirstStep;
    final isLast = state.isLastStep;
    final needsCredit =
        SapMasterData.paymentTermNeedsCreditApproval(state.draft.paymentTerm);
    final isUploadingDoc = state.currentStep == BpFormStep.documents &&
        state.draft.attachments.any((a) => a.isUploading);

    final btnPadding = widget.isTablet
        ? const EdgeInsets.symmetric(vertical: 14)
        : EdgeInsets.symmetric(vertical: context.rh(10));

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          if (!isFirst) ...[
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: btnPadding,
                  side: BorderSide(
                      color: context.appColors.surfaceStrong, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: context.appColors.card,
                ),
                onPressed: isUploadingDoc
                    ? null
                    : () => _bloc.add(const PreviousStep()),
                icon: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: _fontSize(16),
                ),
                label: Text(
                  'common.back'.tr,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: _fontSize(13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: isFirst ? 1 : 2,
            child: CoachKeys.wrap(
              CoachKeys.depotFormNext,
              child: DecoratedBox(
                // Apex Blue to move on; Sustainable Green to send — the
                // same pair as the tablet layout.
                decoration: BoxDecoration(
                  color: isLast
                      ? context.appColors.success
                      : Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (isLast
                              ? context.appColors.success
                              : Theme.of(context).colorScheme.primary)
                          .withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: btnPadding,
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: (state.isBusy || isUploadingDoc)
                      ? null
                      : () {
                          _coach.advanceRequested();
                          _bloc.add(
                              isLast ? const SubmitToHQ() : const NextStep());
                        },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isUploadingDoc) ...[
                        SizedBox(
                          width: _fontSize(14),
                          height: _fontSize(14),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'add_depot.photo_uploading'.tr,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: _fontSize(13),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ] else ...[
                        Text(
                          isLast
                              ? (needsCredit
                                  ? 'add_depot.send_for_credit_approval'.tr
                                  : 'add_depot.send_to_hq'.tr)
                              : 'add_depot.next_step'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: _fontSize(13),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          isLast
                              ? Icons.check_circle_outline
                              : Icons.arrow_forward,
                          color: Colors.white,
                          size: _fontSize(16),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
