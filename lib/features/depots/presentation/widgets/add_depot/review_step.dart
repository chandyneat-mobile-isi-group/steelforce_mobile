part of '../add_depot_bottom_sheet.dart';

extension ReviewStepExtension on _AddDepotBottomSheetState {
  Widget _buildReviewStep(Map<String, String> errors) {
    final draft = _bloc.state.draft;

    Widget buildAnimatedCard({
      required BpFormStep step,
      required String value,
      required int index,
      required IconData icon,
    }) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Interval(index * 0.1, 1.0, curve: Curves.easeOutCubic),
        builder: (context, anim, child) {
          return Transform.translate(
            offset: Offset(0, 30 * (1 - anim)),
            child: Opacity(opacity: anim, child: child),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isTablet ? 16 : context.rw(12),
            vertical: widget.isTablet ? 12 : context.rh(8),
          ),
          decoration: BoxDecoration(
            color: context.appColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appColors.border, width: 1.1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.titleKey.tr,
                      style: TextStyle(
                        fontSize: _fontSize(11),
                        color: context.appColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value.isEmpty ? '—' : value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: _fontSize(12.5),
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.edit_rounded,
                  size: _fontSize(18),
                  color: context.appColors.textHint,
                ),
                onPressed: () => _bloc.add(GoToStep(step)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildAnimatedCard(
          step: BpFormStep.identity,
          value: '${draft.registrationType.labelKey.tr} · ${draft.nameEn}\n'
              '${draft.nameKh}',
          index: 0,
          icon: Icons.person_rounded,
        ),
        buildAnimatedCard(
          step: BpFormStep.address,
          value: [
            if (draft.street.isNotEmpty || draft.houseNumber.isNotEmpty)
              '${draft.houseNumber} ${draft.street}'.trim(),
            if (draft.geoAddress != null &&
                draft.geoAddress != GeoAddress.empty)
              draft.geoAddress!.format(
                LocalizationService.instance.currentLanguageCode,
              )
            else ...[
              if (draft.districtCode != null) draft.districtCode!,
              if (draft.cityCode != null) draft.cityCode!,
            ],
            if (draft.postalCode.isNotEmpty) draft.postalCode,
          ].where((s) => s.isNotEmpty).join(', '),
          index: 1,
          icon: Icons.location_on_rounded,
        ),
        buildAnimatedCard(
          step: BpFormStep.contact,
          // The person and their number on one line. Showing the mobile alone
          // let a rep confirm a number without ever re-reading whose it is —
          // and the name and role are what make it callable.
          value: [
            draft.contactPersonName.trim(),
            draft.contactPersonRole?.trim() ?? '',
            draft.mobilePhone.trim(),
          ].where((s) => s.isNotEmpty).join(' · '),
          index: 2,
          icon: Icons.phone_rounded,
        ),
        buildAnimatedCard(
          step: BpFormStep.salesTerms,
          value: [
            draft.depotGroup ?? '—',
            draft.paymentTerm ?? '—',
          ].join(' · '),
          index: 3,
          icon: Icons.storefront_rounded,
        ),
        buildAnimatedCard(
          step: BpFormStep.salesPerformance,
          value: _surveySummary(draft.salesSurvey),
          index: 4,
          icon: Icons.insights_rounded,
        ),
        buildAnimatedCard(
          step: BpFormStep.documents,
          value: [
            'add_depot.documents_attached'
                .trParams({'count': '${draft.attachments.length}'}),
            if (draft.remark.isEmpty)
              ''
            else
              'add_depot.remark_line'.trParams({'remark': draft.remark}),
          ].join('\n'),
          index: 5,
          icon: Icons.attach_file_rounded,
        ),
      ],
    );
  }

  /// "Steel, Construction materials · $12,000.00 / month" — what the depot
  /// sells and how much, the two answers a reviewer checks first.
  String _surveySummary(DepotSalesSurvey survey) {
    if (survey.productLines.isEmpty) return '';
    final lines = survey.productLines
        .map((l) => 'add_depot.survey.line.${l.name}'.tr)
        .join(', ');
    final total = NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 2)
        .format(survey.totalMonthlySales);
    return '$lines\n${'add_depot.survey.per_month'.trParams({
          'amount': total
        })}';
  }
}
