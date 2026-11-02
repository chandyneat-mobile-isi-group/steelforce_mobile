import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:steelforce/core/assets/app_assets.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/platform/device/device_identity.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// The foot of the guest panel: "A member of" and the ISI Steel mark, with
/// the app version quietly under it.
class GuestLandingFooter extends StatelessWidget {
  const GuestLandingFooter({super.key});

  /// Width ÷ height of the ISI Steel artwork.
  static const _isiRatio = 1101.1 / 400;

  /// `1.0.0+1` → `1.0.0`: the build number means nothing to a rep.
  static String get _version => DeviceIdentity.appVersion.split('+').first;

  @override
  Widget build(BuildContext context) {
    final logo = context.rr(26);
    final memberOf = 'shell.guest.member_of'.tr;

    return Column(
      children: [
        Semantics(
          label: '$memberOf ISI Steel',
          excludeSemantics: true,
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: context.rw(10),
            runSpacing: context.rh(6),
            children: [
              Text(
                memberOf,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: context.rsp(14),
                ),
              ),
              SvgPicture.asset(
                AppLogos.isiSteelLight,
                height: logo,
                width: logo * _isiRatio,
              ),
            ],
          ),
        ),
        SizedBox(height: context.rh(8)),
        Text(
          'shell.guest.version'.trParams({'version': _version}),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: context.rsp(12),
          ),
        ),
      ],
    );
  }
}
