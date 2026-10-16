part of '../add_depot_bottom_sheet.dart';

/// Tablet header and step progress. Split out of tablet_layout.dart for size.
extension _TabletHeaderExtension on _AddDepotBottomSheetState {
  // ===========================================================================
  // Tablet Header & Progress
  // ===========================================================================
  Widget _buildTabletFormHeader(AddDepotState state) {
    final stageTitles = [
      (
        title:
            '${'add_depot.steps.identity'.tr} & ${'add_depot.steps.address'.tr}',
        subtitle: 'add_depot.subtitle'.tr,
      ),
      (
        title:
            '${'add_depot.steps.contact'.tr} & ${'add_depot.steps.sales_terms'.tr}',
        subtitle:
            'Configure contact details, commercial pricing & tax classification',
      ),
      (
        title: 'add_depot.steps.documents'.tr,
        subtitle: 'Upload required verification photos and internal remarks',
      ),
      (
        title: '${'add_depot.review'.tr} & ${'add_depot.send_to_hq'.tr}',
        subtitle:
            'Verify all registered depot information before final submission',
      ),
    ];
    final current = stageTitles[_tabletStage.clamp(0, 3)];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  current.title,
                  key: ValueKey(current.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: _fontSize(22),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                current.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                  fontSize: _fontSize(13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: context.appColors.surfaceSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.appColors.border),
          ),
          child: Text(
            'Step ${_tabletStage + 1} / 4',
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontSize: _fontSize(13),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletStepProgress(AddDepotState state) {
    final stages = [
      '1. General & Location',
      '2. Contact & Terms',
      '3. Documents & Notes',
      '4. Preview & Submit',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: context.appColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < stages.length; i++) ...[
            Expanded(
              child: InkWell(
                onTap: i < _tabletStage ? () => _goToTabletStage(i) : null,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _tabletStage
                              ? Theme.of(context).colorScheme.primary
                              : i < _tabletStage
                                  ? context.appColors.success
                                  : context.appColors.border,
                        ),
                        child: i < _tabletStage
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: i == _tabletStage
                                      ? Colors.white
                                      : context.appColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          stages[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: _fontSize(12.5),
                            fontWeight: i == _tabletStage
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: i == _tabletStage
                                ? Theme.of(context).colorScheme.primary
                                : i < _tabletStage
                                    ? context.appColors.textPrimary
                                    : context.appColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (i < stages.length - 1)
              Container(
                width: 16,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: i < _tabletStage
                    ? context.appColors.success
                    : context.appColors.border,
              ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // Tablet Stages Body (2-Step Columns & Preview)
  // ===========================================================================
}
