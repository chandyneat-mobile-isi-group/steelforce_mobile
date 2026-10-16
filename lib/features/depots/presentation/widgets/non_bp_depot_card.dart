import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/data/datasources/non_bp_depot_demo_data.dart';

/// One non-bp-depot in the list.
///
/// **The linked SAP depot is the loudest thing on the card after the name.**
/// On a depot card that space carries the depot code, because a depot
/// is its own commercial entity. A non-bp-depot is not — the only reason the
/// record exists is the party it trades through, and a rep who cannot see that
/// at a glance has to open the record to learn the one fact that makes it
/// useful.
class NonBpDepotCard extends StatelessWidget {
  const NonBpDepotCard({super.key, required this.nonBpDepot, this.onTap});

  final NonBpDepotDemo nonBpDepot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(context.rr(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.rr(8)),
                      decoration: BoxDecoration(
                        color: colors.surfaceSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        nonBpDepot.kind.icon,
                        size: context.rr(18),
                        color: colors.textSecondary,
                      ),
                    ),
                    SizedBox(width: context.rw(10)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nonBpDepot.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: context.rsp(14),
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: context.rh(3)),
                          Text(
                            nonBpDepot.kind.label,
                            style: TextStyle(
                              fontSize: context.rsp(11),
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.rh(10)),

                // The link. Given its own tinted block rather than another grey
                // line of metadata, because it is the field that decides where
                // this party's volume is counted.
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rw(10),
                    vertical: context.rh(8),
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link_rounded,
                        size: context.rr(14),
                        color: scheme.primary,
                      ),
                      SizedBox(width: context.rw(6)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buys through',
                              style: TextStyle(
                                fontSize: context.rsp(9.5),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: colors.textSecondary,
                              ),
                            ),
                            SizedBox(height: context.rh(1)),
                            Text(
                              '${nonBpDepot.linkedDepotCode} · '
                              '${nonBpDepot.linkedDepotName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: context.rsp(11.5),
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: context.rh(10)),

                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: context.rr(13),
                      color: colors.textSecondary,
                    ),
                    SizedBox(width: context.rw(4)),
                    Expanded(
                      child: Text(
                        nonBpDepot.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: context.rsp(11.5),
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    SizedBox(width: context.rw(8)),
                    Icon(
                      Icons.phone_outlined,
                      size: context.rr(13),
                      color: colors.textSecondary,
                    ),
                    SizedBox(width: context.rw(4)),
                    Text(
                      nonBpDepot.phone,
                      style: TextStyle(
                        fontSize: context.rsp(11.5),
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
