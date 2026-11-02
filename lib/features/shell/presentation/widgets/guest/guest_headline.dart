import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';

/// The pitch, one job per line: "Visit depots. / Take orders. / Hit your
/// target." The middle line is in the lifted Apex Blue, as in the wordmark.
class GuestHeadline extends StatelessWidget {
  const GuestHeadline({super.key, this.fontSize = 36});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    TextSpan line(String key, Color color, {bool last = false}) => TextSpan(
          text: last ? key.tr : '${key.tr}\n',
          style: TextStyle(color: color),
        );

    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: context.rsp(fontSize),
          fontWeight: FontWeight.w800,
          height: 1.18,
          letterSpacing: -0.5,
        ),
        children: [
          line('shell.guest.headline_visit', Colors.white),
          line('shell.guest.headline_order', AppColors.apexOnDark),
          line('shell.guest.headline_target', Colors.white, last: true),
        ],
      ),
    );
  }
}
