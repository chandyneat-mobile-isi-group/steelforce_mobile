import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// New Component matching the exact design from the reference image
class KpiInVisitVsAdHocCard extends StatelessWidget {
  const KpiInVisitVsAdHocCard({
    super.key,
    required this.totalOrders,
    required this.inVisitCount,
    required this.inVisitPercentage,
    required this.adHocCount,
    required this.adHocPercentage,
  });

  final int totalOrders;
  final int inVisitCount;
  final int inVisitPercentage;
  final int adHocCount;
  final int adHocPercentage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;

    return Container(
      padding: EdgeInsets.all(context.rw(16)),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(context.rr(16)),
        border: Border.all(color: appColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'In-visit vs Ad-hoc Orders',
            style: TextStyle(
              fontSize: context.rsp(14),
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          SizedBox(height: context.rh(8)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$totalOrders',
                style: TextStyle(
                  fontSize: context.rsp(20),
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface,
                ),
              ),
              SizedBox(width: context.rw(6)),
              Text(
                'TOTAL ORDERS',
                style: TextStyle(
                  fontSize: context.rsp(11),
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(12)),
          // Segmented Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(context.rr(6)),
            child: SizedBox(
              height: context.rh(8),
              child: Row(
                children: [
                  Expanded(
                    flex: inVisitPercentage,
                    child: Container(color: Colors.green.shade600),
                  ),
                  SizedBox(width: context.rw(4)),
                  Expanded(
                    flex: adHocPercentage,
                    child: Container(color: const Color(0xFF5B4EFF)),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: context.rh(14)),
          // Sub-metrics Box
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.rw(12),
              vertical: context.rh(10),
            ),
            decoration: BoxDecoration(
              color: appColors.surfaceSoft,
              borderRadius: BorderRadius.circular(context.rr(12)),
            ),
            child: Row(
              children: [
                // In-visit Column
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(context.rw(6)),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: context.rr(14),
                          color: Colors.green.shade700,
                        ),
                      ),
                      SizedBox(width: context.rw(8)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '$inVisitCount',
                                style: TextStyle(
                                  fontSize: context.rsp(14),
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurface,
                                ),
                              ),
                              SizedBox(width: context.rw(4)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.rw(6),
                                  vertical: context.rh(2),
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(
                                    context.rr(10),
                                  ),
                                ),
                                child: Text(
                                  '$inVisitPercentage%',
                                  style: TextStyle(
                                    fontSize: context.rsp(10),
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'In-visit',
                            style: TextStyle(
                              fontSize: context.rsp(11),
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  height: context.rh(28),
                  width: 1,
                  color: scheme.onSurface.withValues(alpha: 0.12),
                ),
                SizedBox(width: context.rw(12)),
                // Ad-hoc Column
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(context.rw(6)),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.exit_to_app_rounded,
                          size: context.rr(14),
                          color: const Color(0xFF5B4EFF),
                        ),
                      ),
                      SizedBox(width: context.rw(8)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '$adHocCount',
                                style: TextStyle(
                                  fontSize: context.rsp(14),
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurface,
                                ),
                              ),
                              SizedBox(width: context.rw(4)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.rw(6),
                                  vertical: context.rh(2),
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(
                                    context.rr(10),
                                  ),
                                ),
                                child: Text(
                                  '$adHocPercentage%',
                                  style: TextStyle(
                                    fontSize: context.rsp(10),
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Ad-hoc',
                            style: TextStyle(
                              fontSize: context.rsp(11),
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
