part of '../add_depot_bottom_sheet.dart';

extension MobileLayoutExtension on _AddDepotBottomSheetState {
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
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
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
                  color: Colors.white.withValues(alpha: 0.9),
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
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Text(
            stepText,
            style: TextStyle(
              color: Colors.white,
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
                      : Colors.white,
                  border: Border.all(
                    color: step.index <= state.currentStep.index
                        ? Colors.transparent
                        : const Color(0xFFE2E8F0),
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
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : Text(
                          '${step.number}',
                          style: TextStyle(
                            color: step.index == state.currentStep.index
                                ? Colors.white
                                : const Color(0xFF94A3B8),
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
                      : const Color(0xFFE2E8F0),
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
          'Please provide depot identity details',
        ),
      BpFormStep.address => (
          Icons.location_on_rounded,
          'add_depot.steps.address'.tr,
          'Please provide the depot\'s address information',
        ),
      BpFormStep.contact => (
          Icons.phone_in_talk_rounded,
          'add_depot.steps.contact'.tr,
          'Please provide depot contact details',
        ),
      BpFormStep.salesTerms => (
          Icons.storefront_rounded,
          'add_depot.steps.sales_terms'.tr,
          'Please configure business and payment terms',
        ),
      BpFormStep.documents => (
          Icons.folder_shared_rounded,
          'add_depot.steps.documents'.tr,
          'Please provide required verification documents',
        ),
      BpFormStep.review => (
          Icons.assignment_turned_in_rounded,
          'add_depot.review_title'.tr,
          'Please review all information before submission',
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
            child: Icon(icon, color: Colors.white, size: 16),
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
                    color: const Color(0xFF64748B),
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
                  side: const BorderSide(color: Color(0xFFDBEAFE), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  backgroundColor: Colors.white,
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
                  'Back',
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isLast
                      ? [const Color(0xFF10B981), const Color(0xFF059669)]
                      : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (isLast
                            ? const Color(0xFF10B981)
                            : const Color(0xFF2563EB))
                        .withValues(alpha: 0.3),
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
                    : () => _bloc
                        .add(isLast ? const SubmitToHQ() : const NextStep()),
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
        ],
      ),
    );
  }
}
