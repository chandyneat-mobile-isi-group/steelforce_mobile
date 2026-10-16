import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/repositories/ad_hoc_visit_repository.dart';

/// An ad hoc request that has not reached the server yet.
///
/// **Deliberately not a stop card.** There is no stop id until the server
/// issues one, so there is nothing to check in to — an optimistic card the rep
/// could tap and that did nothing would be worse than an honest wait. This
/// says what it is: "Adding Toul Kork Yard…", untappable, with a spinner.
class PendingAdHocCard extends StatelessWidget {
  const PendingAdHocCard({super.key, required this.request});

  final PendingAdHocVisit request;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: context.rh(12)),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: context.rw(16), vertical: context.rh(14)),
        decoration: BoxDecoration(
          color: colors.surfaceSoft,
          borderRadius: BorderRadius.circular(context.rr(16)),
          // Dashed-looking muted border rather than the solid card border:
          // this is provisional, and it should not read as a finished row.
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: context.rr(20),
              height: context.rr(20),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
            SizedBox(width: context.rw(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'my_visits.ad_hoc.pending_title'
                        .trParams({'name': request.depotName}),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: context.rsp(13.5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: context.rh(3)),
                  Text(
                    // Says *why* it is waiting when we know, and otherwise
                    // that it will go out on its own. Never the raw error
                    // code, which means nothing to a rep.
                    request.lastErrorCode == null
                        ? 'my_visits.ad_hoc.pending_hint'.tr
                        : 'my_visits.ad_hoc.pending_retry'.tr,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(11.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
