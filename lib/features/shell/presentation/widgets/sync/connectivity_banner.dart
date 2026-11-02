import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/network/connectivity/connectivity_cubit.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/shell/presentation/bloc/work_mode_cubit.dart';

/// A calm, always-visible-when-offline banner styled with steel accent framing,
/// dual-bordered icon avatar, and subtle corner watermarks.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilt on the mode too: with no signal, switching mode leaves the
    // connectivity status offline either way, but the message must change.
    return BlocBuilder<WorkModeCubit, WorkModeState>(
      bloc: sl<WorkModeCubit>(),
      builder: (context, mode) =>
          BlocBuilder<ConnectivityCubit, ConnectivityStatus>(
        builder: (context, status) {
          if (status == ConnectivityStatus.online) {
            return const SizedBox.shrink();
          }
          final colors = context.appColors;

          return Container(
            decoration: BoxDecoration(
              color: colors.surfaceSoft,
              borderRadius: BorderRadius.circular(context.rr(16)),
              border: Border.all(
                color: AppColors.steelRim,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10.r,
                  offset: Offset(0, context.rh(4)),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(context.rr(15)),
              child: Stack(
                children: [
                  // Top-Left Corner Decorative Circle Watermark
                  Positioned(
                    top: -context.rr(20),
                    left: -context.rr(20),
                    child: Container(
                      width: context.rr(50),
                      height: context.rr(50),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.slate.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  // Bottom-Right Corner Decorative Circle Watermark
                  Positioned(
                    bottom: -context.rr(20),
                    right: -context.rr(20),
                    child: Container(
                      width: context.rr(50),
                      height: context.rr(50),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.slate.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  // Main Banner Content
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: context.rw(14), vertical: context.rh(12)),
                    child: Row(
                      children: [
                        // Dual-Bordered Circular Icon Badge
                        Container(
                          padding: EdgeInsets.all(context.rr(8)),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.slate.withValues(alpha: 0.12),
                            border: Border.all(
                              color: AppColors.steelRim.withValues(alpha: 0.8),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 4.r,
                                offset: Offset(0, context.rh(2)),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.cloud_off_rounded,
                            color: colors.slate,
                            size: context.rsp(20),
                          ),
                        ),
                        SizedBox(width: context.rw(12)),
                        Expanded(
                          child: Text(
                            mode.isOffline
                                ? 'work_mode.banner'.tr
                                : 'sync.offline_banner'.tr,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: context.rsp(13),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
