import 'package:flutter/material.dart';
import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Tells whoever is holding a demo build which account signs in, and offers
/// to type it for them.
///
/// Shown only by a demo build — `LoginForm` renders it when it is given a
/// fill callback, which the login screen passes only in demo mode. Light ink
/// on the screen's always-dark base, like the rest of the form.
///
/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
class DemoSignInHint extends StatelessWidget {
  const DemoSignInHint({super.key, required this.onFill});

  final VoidCallback onFill;

  @override
  Widget build(BuildContext context) {
    final accent = context.appColors.info;
    const ink = Colors.white;

    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        context.rw(12),
        context.rh(10),
        context.rw(12),
        context.rh(2),
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(context.rr(12)),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      // The action sits under the text rather than beside it, so a long
      // Khmer line or a large text scale wraps instead of overflowing.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: context.rr(18), color: ink),
          SizedBox(width: context.rw(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'auth.demo.hint'.trParams({
                    'phone': DemoSeed.signInPhone,
                    'password': DemoSeed.signInPassword,
                  }),
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.88),
                    fontSize: context.rsp(13),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextButton(
                  onPressed: onFill,
                  style: TextButton.styleFrom(
                    foregroundColor: ink,
                    minimumSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    'auth.demo.fill'.tr,
                    style: TextStyle(
                      fontSize: context.rsp(13),
                      fontWeight: FontWeight.w700,
                    ),
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
