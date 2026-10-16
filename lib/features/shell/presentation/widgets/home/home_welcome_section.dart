import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/pending_sync_badge.dart';

/// The greeting over the home hero: time-of-day salutation, the rep's name
/// beside a gold accent bar, and the pending-sync badge on the right.
class HomeWelcomeSection extends StatelessWidget {
  const HomeWelcomeSection({super.key, required this.fullName});

  /// The signed-in rep, not a fixture. This once read 'Sokha Novel' for
  /// every user — the same class of bug as the profile screen's "Alex Morgan".
  final String fullName;

  // Traditional gold accent palette.
  static const Color _goldLight = Color(0xFFF3E5AB);
  static const Color _goldPrimary = Color(0xFFD4AF37);
  static const Color _goldDark = Color(0xFF996515);

  static String _greetingKey(int hour) {
    if (hour < 12) return 'common.good_morning';
    if (hour < 17) return 'common.good_afternoon';
    return 'common.good_evening';
  }

  @override
  Widget build(BuildContext context) {
    final greetingKey = _greetingKey(DateTime.now().hour);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          context.pagePadding, context.rh(4), context.pagePadding, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: context.rw(3.5),
                  height: context.rh(32),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2.r),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_goldLight, _goldPrimary, _goldDark],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _goldPrimary.withValues(alpha: 0.5),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        greetingKey.tr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: context.rsp(13),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        fullName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: context.rsp(19),
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PendingSyncBadge(),
            ],
          ),
        ],
      ),
    );
  }
}
