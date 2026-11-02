import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// The ✕ in a bottom sheet's header: an explicit way out beside drag-down
/// and tapping the scrim, which not every rep discovers.
///
/// 48dp target, labelled "Close" for screen readers. Pops the sheet's own
/// route, so it never closes a sheet underneath (the Sync Center under one of
/// its detail sheets stays open).
class SheetCloseButton extends StatelessWidget {
  const SheetCloseButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return IconButton(
      onPressed: () => Navigator.of(context).maybePop(),
      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(48),
        backgroundColor: colors.card,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        side: BorderSide(color: colors.border),
      ),
      icon: const Icon(Icons.close_rounded, size: 22),
    );
  }
}
