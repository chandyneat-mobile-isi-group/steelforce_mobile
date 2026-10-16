import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Explains an empty directory without conflating it with a loading failure.
class DepotEmptyState extends StatelessWidget {
  const DepotEmptyState({
    super.key,
    required this.hasActiveSearchOrFilter,
    this.onClearSearchOrFilter,
    this.lookupCode,
    this.onLookupCode,
    this.isLookingUp = false,
  });

  final bool hasActiveSearchOrFilter;
  final VoidCallback? onClearSearchOrFilter;

  /// The code-shaped query to offer a server lookup for, or null when the
  /// search does not look like a depot number.
  ///
  /// The offer is deliberately gated on an explicit action and a code-shaped
  /// term: `GET /depots/by-code` can reach the ERP, so it must never sit on
  /// the keystroke path the way local search does.
  final String? lookupCode;
  final VoidCallback? onLookupCode;
  final bool isLookingUp;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.rr(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: context.rr(48),
              color: colors.textSecondary,
            ),
            SizedBox(height: context.rh(12)),
            Text(
              'depots.no_depots'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(16),
                fontWeight: FontWeight.w800,
              ),
            ),
            if (hasActiveSearchOrFilter) ...[
              SizedBox(height: context.rh(6)),
              Text(
                'depots.no_matches'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: context.rsp(13),
                ),
              ),
              // A depot created in SAP since the last nightly sync is
              // invisible to local search but findable by code, so a rep who
              // typed a full number gets one explicit way to ask the server.
              if (lookupCode != null && onLookupCode != null) ...[
                SizedBox(height: context.rh(16)),
                if (isLookingUp)
                  Text(
                    'depots.lookup_searching'.tr,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(13),
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: onLookupCode,
                    icon: const Icon(Icons.cloud_download_outlined, size: 18),
                    label: Text(
                      'depots.lookup_code'.trParams({'code': lookupCode!}),
                    ),
                  ),
              ],
              if (onClearSearchOrFilter != null) ...[
                SizedBox(height: context.rh(16)),
                TextButton(
                  onPressed: onClearSearchOrFilter,
                  child: Text('common.clear_search'.tr),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
