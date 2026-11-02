import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// The areas a signed-in rep works in, as quiet pills under the headline.
///
/// A guest can see what is behind the sign-in but not open it: every pill
/// calls [onRequireLogin]. They wrap onto a second line when the language or
/// text size needs it.
class GuestAreaChips extends StatelessWidget {
  const GuestAreaChips({super.key, required this.onRequireLogin});

  final VoidCallback onRequireLogin;

  static List<String> get labels => [
        'shell.guest.area_visits'.tr,
        'shell.guest.depots'.tr,
        'shell.guest.area_quotes_orders'.tr,
      ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.rw(8),
      runSpacing: context.rh(8),
      children: [
        for (final label in labels)
          _AreaChip(label: label, onTap: onRequireLogin),
      ],
    );
  }
}

class _AreaChip extends StatelessWidget {
  const _AreaChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    return Semantics(
      button: true,
      label: 'shell.login_required_label'.trParams({'feature': label}),
      excludeSemantics: true,
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.rw(13),
              vertical: context.rh(7),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: context.rsp(14),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
