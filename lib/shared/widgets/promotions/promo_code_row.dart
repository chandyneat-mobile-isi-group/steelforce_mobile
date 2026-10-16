import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// The promo code plus a copy affordance.
///
/// The copy target is a full-height [InkWell] with real padding rather than the
/// old bare 4pt-padded `Row`, which measured about 60x22 — well under the
/// 48x48 minimum (FS-UX-3) and genuinely hard to hit one-handed while holding
/// a clipboard.
class PromoCodeRow extends StatelessWidget {
  const PromoCodeRow({super.key, required this.code});

  final String code;

  /// Long enough to read a confirmation, short enough not to sit over the next
  /// card while the rep is still comparing two promotions.
  static const _confirmationDuration = Duration(seconds: 2);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(Icons.confirmation_number_rounded,
            size: context.rr(16), color: colors.iconMuted),
        SizedBox(width: context.rw(8)),
        Expanded(
          child: Text(
            code,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: context.rsp(12.5),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'promotions.copy_code'.trParams({'code': code}),
          excludeSemantics: true,
          child: InkWell(
            onTap: () => _copy(context),
            borderRadius: BorderRadius.circular(context.rr(10)),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.rw(12),
                vertical: context.rh(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded,
                      size: context.rr(14), color: scheme.primary),
                  SizedBox(width: context.rw(6)),
                  Text(
                    'promotions.copy'.tr,
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: context.rsp(11.5),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();

    // Floating and short. The old snackbar was full-width and docked, which on
    // this screen covered the next card in the list — the rep copied a code and
    // the thing they were comparing it against disappeared for two seconds.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: _confirmationDuration,
          content: Text('promotions.copied'.trParams({'code': code})),
        ),
      );
  }
}
