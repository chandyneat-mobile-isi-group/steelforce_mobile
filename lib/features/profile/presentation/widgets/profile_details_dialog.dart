import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:steelforce/features/profile/presentation/bloc/profile_state.dart';
import 'package:steelforce/features/profile/presentation/widgets/profile_info_section.dart';

/// Everything `/auth/me` says about the rep, in a dialog over the profile
/// menu on a phone. A tablet shows the same section inline and never opens
/// this.
///
/// Shares the profile screen's cubit, so a refresh that lands while it is
/// open shows here too.
Future<void> showProfileDetailsDialog(BuildContext context) {
  final cubit = context.read<ProfileCubit>();
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: const _ProfileDetailsDialog(),
    ),
  );
}

class _ProfileDetailsDialog extends StatelessWidget {
  const _ProfileDetailsDialog();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final screen = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);

    return Dialog(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      // Clear of the status bar and home indicator, so the dialog can use
      // the rest of the screen's height.
      insetPadding: EdgeInsets.fromLTRB(
        context.rw(16),
        safe.top + context.rh(8),
        context.rw(16),
        safe.bottom + context.rh(8),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        // Wider on a tablet, where type is scaled up and a narrow dialog
        // wraps Khmer onto extra lines; capped so rows never run edge to edge.
        constraints: BoxConstraints(
          maxWidth: context.responsive(
              compact: 520.0, medium: 640.0, expanded: 680.0),
          maxHeight: screen.height,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                  context.rw(16), context.rh(8), context.rw(4), context.rh(2)),
              child: Row(
                children: [
                  Container(
                    width: context.rr(34),
                    height: context.rr(34),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_rounded,
                        color: scheme.primary, size: context.rr(19)),
                  ),
                  SizedBox(width: context.rw(12)),
                  Expanded(
                    child: Text(
                      'profile.my_details'.tr,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: context.rsp(17),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    icon: Icon(Icons.close_rounded,
                        color: colors.textSecondary, size: context.rr(24)),
                  ),
                ],
              ),
            ),
            Flexible(
              child: BlocBuilder<ProfileCubit, ProfileState>(
                builder: (context, state) => switch (state) {
                  ProfileLoaded(:final profile) => _OneScreen(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(context.rw(12),
                            context.rh(4), context.rw(12), context.rh(12)),
                        child:
                            ProfileInfoSection(profile: profile, compact: true),
                      ),
                    ),
                  _ => Padding(
                      padding: EdgeInsets.all(context.rh(32)),
                      child: Center(
                        child: CircularProgressIndicator(color: scheme.primary),
                      ),
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps the details on one screen, with no scrolling.
///
/// The compact layout is sized to fit portrait phones as they are; on the
/// smallest (360×640) a few pixels can remain, and those are taken by
/// scaling the content down slightly rather than adding a scroll bar for a
/// sliver of content.
///
/// The exception is large accessibility text: shrinking it back down would
/// undo the setting the rep chose, so above [_maxTextScaleToFit] it scrolls.
class _OneScreen extends StatelessWidget {
  const _OneScreen({required this.child});

  static const _maxTextScaleToFit = 1.3;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final largeText =
        MediaQuery.textScalerOf(context).scale(10) / 10 > _maxTextScaleToFit;
    if (largeText) return SingleChildScrollView(child: child);

    return LayoutBuilder(
      // FittedBox lays its child out unconstrained; the fixed width keeps the
      // grid at the dialog's width so only the height decides the scale.
      builder: (context, box) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(width: box.maxWidth, child: child),
      ),
    );
  }
}
