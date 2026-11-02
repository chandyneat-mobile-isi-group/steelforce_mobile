part of '../depot_detail_screen.dart';

/// One pill per option, splitting the width evenly so every one stays on
/// screen; a long (Khmer) label wraps instead of scrolling away.
///
/// [nested] is the row under another row (Business Profile's cards): a
/// tinted selection instead of a filled one, so it reads as one level down.
class _PillRow<T> extends StatelessWidget {
  const _PillRow({
    required this.items,
    required this.labelKey,
    required this.selected,
    required this.onChanged,
    this.nested = false,
  });

  final List<T> items;
  final String Function(T) labelKey;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool nested;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items) ...[
              if (item != items.first) SizedBox(width: context.rw(6)),
              Expanded(child: _pill(context, item)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, T item) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final on = item == selected;
    final fill = !on
        ? colors.card
        : nested
            ? scheme.primary.withValues(alpha: 0.12)
            : scheme.primary;
    final text = !on
        ? colors.textSecondary
        : nested
            ? scheme.primary
            : scheme.onPrimary;
    return Semantics(
      button: true,
      selected: on,
      child: Material(
        color: fill,
        shape: StadiumBorder(
          side: BorderSide(color: on ? scheme.primary : colors.border),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () {
            if (on) return;
            HapticFeedback.selectionClick();
            onChanged(item);
          },
          child: ConstrainedBox(
            // A comfortable touch target at any text scale.
            constraints: BoxConstraints(minHeight: nested ? 36 : 40),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.rw(nested ? 6 : 10),
                vertical: context.rh(nested ? 6 : 8),
              ),
              child: Center(
                child: Text(
                  labelKey(item).tr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: text,
                    fontSize: context.rsp(nested ? 12 : 12.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
