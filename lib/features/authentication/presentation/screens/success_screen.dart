import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/authentication/presentation/widgets/login/gradient_button.dart';
import 'package:steelforce/shared/widgets/aurora_background.dart';
import 'package:steelforce/shared/widgets/glass_card.dart';

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({
    super.key,
    required this.title,
    this.subtitle,
    required this.buttonLabel,
    required this.onContinue,
    this.icon = Icons.check_circle_outline,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String? subtitle;
  final String buttonLabel;
  final VoidCallback onContinue;
  final IconData icon;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final maxCardWidth = context.responsive(
      compact: 420.0,
      medium: 520.0,
      expanded: 600.0,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(context.pagePadding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxCardWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _SuccessBadge(icon: icon),
                          SizedBox(height: context.rh(22)),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: context.rsp(26),
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                          if (subtitle != null) ...[
                            SizedBox(height: context.rh(8)),
                            Text(
                              subtitle!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: context.appColors.textSecondary,
                                fontSize: context.rsp(15),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: context.rh(28)),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GradientButton(
                              label: buttonLabel,
                              onPressed: onContinue,
                            ),
                            if (secondaryLabel != null) ...[
                              SizedBox(height: context.rh(12)),
                              Center(
                                child: TextButton(
                                  onPressed: onSecondary,
                                  child: Text(
                                    secondaryLabel!,
                                    style: TextStyle(
                                      color: context.appColors.info,
                                      fontSize: context.rsp(14),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final size = context.rr(84);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
        border: Border.all(
          color:
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Icon(
        icon,
        size: context.rr(42),
        color: Theme.of(context).colorScheme.secondary,
      ),
    );
  }
}
