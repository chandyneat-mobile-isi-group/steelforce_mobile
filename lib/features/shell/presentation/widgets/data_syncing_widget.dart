import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:steelforce/core/localization/localization_services.dart';

class DataSyncIndicator extends StatefulWidget {
  const DataSyncIndicator({super.key});

  @override
  State<DataSyncIndicator> createState() => _DataSyncIndicatorState();
}

class _DataSyncIndicatorState extends State<DataSyncIndicator> {
  bool _isSyncing = true;

  @override
  void initState() {
    super.initState();
    _startSyncTimer();
  }

  void _startSyncTimer() {
    // Waits for 5 seconds, then changes the state
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(
            milliseconds: 300), // Smoothly animates size/color shifts
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          // Background shifts color slightly when done if you want, or stays transparent
          color: _isSyncing
              ? Colors.white.withValues(alpha: 0.85)
              : const Color.fromARGB(255, 0, 187, 6).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(32.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Dynamic Icon/Indicator Area
            _isSyncing
                ? SizedBox(
                    width: 18.w,
                    height: 18.h,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  )
                : Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20.r,
                  ),
            SizedBox(width: 12.w),

            // Dynamic Text Area
            Text(
              _isSyncing ? 'sync.syncing_data'.tr : 'sync.data_sent'.tr,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _isSyncing ? Colors.black87 : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
