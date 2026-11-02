part of '../add_depot_bottom_sheet.dart';

/// Tablet header and step progress. Split out of tablet_layout.dart for size.
extension _TabletHeaderExtension on _AddDepotBottomSheetState {
  // ===========================================================================
  // Tablet Header & Progress
  // ===========================================================================
  Widget _buildTabletFormHeader(AddDepotState state) {
    final stageTitles = [
      (
        title: 'add_depot.tablet.stage_general'.tr,
        subtitle: 'add_depot.subtitle'.tr,
      ),
      (
        title: 'add_depot.tablet.stage_contact'.tr,
        subtitle: 'add_depot.tablet.stage_contact_subtitle'.tr,
      ),
      (
        title: 'add_depot.steps.documents'.tr,
        subtitle: 'add_depot.tablet.stage_documents_subtitle'.tr,
      ),
      (
        title: 'add_depot.tablet.stage_review'.tr,
        subtitle: 'add_depot.tablet.stage_review_subtitle'.tr,
      ),
    ];
    final current = stageTitles[_tabletStage.clamp(0, 3)];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (widget.isFullScreen) ...[
          _buildExitButton(onBrand: false),
          const SizedBox(width: 12),
        ],
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
            'add_depot.step_indicator'.trParams({
              'current': '${_tabletStage + 1}',
              'total': '4',
            }),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
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
      'add_depot.tablet.progress_general'.tr,
      'add_depot.tablet.progress_contact'.tr,
      'add_depot.tablet.progress_documents'.tr,
      'add_depot.tablet.progress_preview'.tr,
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
