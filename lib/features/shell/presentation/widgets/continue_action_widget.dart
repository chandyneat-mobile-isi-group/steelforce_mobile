import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:steelforce/core/localization/localization_services.dart';

class ContinueActionCard extends StatelessWidget {
  final String title;
  final int currentStop;
  final int totalStops;
  final double distanceKm;
  final VoidCallback onTakeOrderTap;

  const ContinueActionCard({
    super.key,
    this.title = 'Mekong Hardware',
    this.currentStop = 3,
    this.totalStops = 8,
    this.distanceKm = 1.2,
    required this.onTakeOrderTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: 12.w, vertical: 6.h), // Reduced outer layout padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section Header: Scaled down
          Padding(
            padding: EdgeInsets.only(left: 4.w, bottom: 6.h),
            child: Text(
              'shell.continue_last_action'.tr,
              style: TextStyle(
                fontSize: 14.sp, // Reduced from 11
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: const Color(0xFF7A869A),
              ),
            ),
          ),

          // Main Bento Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                  16.r), // Reduced radius to match smaller scale
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 16.h), // Reduced inner card padding
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Left Pin Icon Container: Shrunk from 46x46 down to 36x36
                  Container(
                    width: 36.r,
                    height: 36.r,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF4F5F7),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.location_on_rounded,
                        color: const Color(0xFFFF3B30),
                        size: 18.r, // Shrunk from 22
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w), // Reduced spacing

                  // 2. Middle Content Area
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14.sp, // Shrunk from 16
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF091E42),
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 3.h), // Tighter gap

                        // Meta Info Row
                        Row(
                          children: [
                            Text(
                              'shell.stop_of'.trParams({
                                'current': currentStop,
                                'total': totalStops
                              }),
                              style: TextStyle(
                                fontSize: 11.sp, // Shrunk from 13
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF6B778C),
                              ),
                            ),
                            Container(
                              margin: EdgeInsets.symmetric(horizontal: 5.w),
                              width: 3.r, // Smaller separator dot
                              height: 3.r,
                              decoration: const BoxDecoration(
                                color: Color(0xFFC1C7D0),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(
                              '${distanceKm}km',
                              style: TextStyle(
                                fontSize: 11.sp, // Shrunk from 13
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0052CC),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10.w),

                  // 3. Right CTA Button: Compressed layout footprint from 84x84 down to 64x64
                  GestureDetector(
                    onTap: onTakeOrderTap,
                    child: Container(
                      width: 100.w,
                      height: 40.h,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFF8A00),
                            Color(0xFFFF5C00),
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(14.r), // Tighter corners
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFFF5C00).withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            color: Colors.white,
                            size: 18.r, // Shrunk from 24
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'shell.take_order'.tr,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.sp, // Shrunk from 11
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
