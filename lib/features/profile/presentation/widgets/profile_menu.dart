import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// One card holding the profile's destinations, with sign-out at the foot.
///
/// Sign-out lives inside the card, below a gap, rather than floating under it:
/// it reads as the last thing on the account, not as another page to open.
class ProfileMenuCard extends StatelessWidget {
  const ProfileMenuCard({
    super.key,
    required this.tiles,
    required this.logoutLabel,
    required this.onLogout,
  });

  /// Normally [ProfileMenuTile]s, or builders that return one.
  final List<Widget> tiles;
  final String logoutLabel;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(color: colors.border),
        boxShadow: colors.cardShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(AppColors.radius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              tiles[i],
              if (i < tiles.length - 1)
                Divider(
                  height: 1,
                  indent: context.rw(16),
                  endIndent: context.rw(16),
                  color: colors.divider,
                ),
            ],
            Padding(
              padding: EdgeInsets.fromLTRB(context.rw(16), context.rh(8),
                  context.rw(16), context.rh(16)),
              child: FilledButton.tonalIcon(
                onPressed: onLogout,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error.withValues(alpha: 0.10),
                  foregroundColor: scheme.error,
                  minimumSize: Size(double.infinity, context.rh(48)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(Icons.logout_rounded, size: context.rr(18)),
                label: Text(
                  logoutLabel,
                  style: TextStyle(
                    fontSize: context.rsp(14.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row in [ProfileMenuCard]: icon tile, title over a one-line summary of
/// what is behind it, chevron.
///
/// The summary is the current value (the theme, the language, an email), so
/// the rep can check a setting without opening it.
class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leadingSubtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Drawn before [subtitle] — the language flag, today.
  final Widget? leadingSubtitle;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final subtitle = this.subtitle;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: context.rw(16), vertical: context.rh(12)),
          child: Row(
            children: [
              Container(
                width: context.rr(40),
                height: context.rr(40),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: context.rr(20), color: scheme.primary),
              ),
              SizedBox(width: context.rw(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: context.rsp(14.5),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      SizedBox(height: context.rh(2)),
                      Row(
                        children: [
                          if (leadingSubtitle case final lead?) ...[
                            lead,
                            SizedBox(width: context.rw(6)),
                          ],
                          Flexible(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: context.rsp(12.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: context.rw(8)),
              Icon(Icons.chevron_right_rounded,
                  size: context.rr(22), color: colors.iconMuted),
            ],
          ),
        ),
      ),
    );
  }
}
