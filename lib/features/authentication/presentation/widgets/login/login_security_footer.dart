import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/platform/device/device_identity.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/authentication/presentation/widgets/auth_ink.dart';

/// "Secure & Trusted" on the left, the build on the right, split by a
/// hairline — quiet, one line of weight, no action. Sits under the sign-in
/// card, on the backdrop.
///
/// The version is [DeviceIdentity.appVersion], the same value the backend is
/// told at sign-in, so what a rep reads off this screen is what support sees.
class LoginSecurityFooter extends StatelessWidget {
  const LoginSecurityFooter({super.key});

  static const developer = 'isi-group-developer';

  static String get version => DeviceIdentity.appVersion.split('+').first;

  @override
  Widget build(BuildContext context) {
    final muted = AuthInk.muted;
    final small = TextStyle(color: muted, fontSize: context.rsp(12));

    return IntrinsicHeight(
      child: Row(
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: AuthInk.accent,
            size: context.rr(32),
          ),
          SizedBox(width: context.rw(12)),
          Expanded(
            flex: 3,
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'auth.secure_trusted'.tr,
                    style: TextStyle(
                      color: AuthInk.text,
                      fontSize: context.rsp(14),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text('auth.data_priority'.tr, style: small),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: context.rw(14), vertical: context.rh(4)),
            child: VerticalDivider(
              width: 1,
              thickness: 1,
              color: AuthInk.hairline,
            ),
          ),
          // One line, never truncated: the version is the half support asks
          // for. On a narrow screen it shrinks rather than wraps or clips.
          Flexible(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Text('$developer  ·  $version', maxLines: 1, style: small),
            ),
          ),
        ],
      ),
    );
  }
}
