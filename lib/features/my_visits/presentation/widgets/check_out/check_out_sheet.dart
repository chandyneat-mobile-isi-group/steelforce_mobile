import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_context.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_outcome.dart';
import 'package:steelforce/features/my_visits/domain/entities/no_order_reason.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/cubit/check_out_reasons_cubit.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';

/// Asks how the visit at [visit]'s stop ended: **with an order** (and which)
/// or **without** (and why). Resolves to the rep's choice, or null if they
/// backed out — the visit then stays open.
///
/// The same rules as `POST /visits/check-outs` (`check-in-check-out-mobile.md`
/// §5) are enforced here, because offline the batch push accepts what that
/// endpoint would refuse: at least one order, or a reason, plus a note when the
/// reason needs one.
Future<CheckOutChoice?> showCheckOutSheet(
  BuildContext context, {
  required CheckOutContext visit,
  required CheckOutReasonsCubit reasons,
}) =>
    showAppBottomSheet<CheckOutChoice>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: reasons,
        child: CheckOutSheet(visit: visit),
      ),
    );

class CheckOutSheet extends StatefulWidget {
  const CheckOutSheet({super.key, required this.visit});

  final CheckOutContext visit;

  @override
  State<CheckOutSheet> createState() => _CheckOutSheetState();
}

class _CheckOutSheetState extends State<CheckOutSheet> {
  static const _noteMax = 500;

  late CheckOutOutcome _outcome = widget.visit.orders.isEmpty
      ? CheckOutOutcome.withoutOrder
      : CheckOutOutcome.withOrder;

  /// Every order taken here starts selected (§10): the common case is "yes,
  /// these", and unticking is one tap.
  late final Set<String> _selected = {
    for (final o in widget.visit.orders) o.ref.clientId,
  };

  NoOrderReason? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _noteRequired => _reason?.requiresNote ?? false;

  bool get _valid => switch (_outcome) {
        CheckOutOutcome.withOrder => _selected.isNotEmpty,
        CheckOutOutcome.withoutOrder =>
          _reason != null && (!_noteRequired || _note.text.trim().isNotEmpty),
      };

  void _confirm() {
    if (!_valid) return;
    final choice = switch (_outcome) {
      CheckOutOutcome.withOrder => CheckOutChoice.withOrder([
          for (final o in widget.visit.orders)
            if (_selected.contains(o.ref.clientId)) o.ref,
        ]),
      CheckOutOutcome.withoutOrder => CheckOutChoice.withoutOrder(
          reason: _reason!.code,
          noOrderNote: _note.text.trim().isEmpty ? null : _note.text.trim(),
        ),
    };
    Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final stop = widget.visit.stop;
    final orders = widget.visit.orders;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
              context.rw(20), context.rh(4), context.rw(8), context.rh(4)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'my_visits.check_out.title'.tr,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: context.rsp(18),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: context.rh(2)),
                    Text(
                      context.localized(stop.depot.displayName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: context.rsp(13),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: colors.textSecondary),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                context.rw(16), context.rh(8), context.rw(16), context.rh(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OutcomeOption(
                  icon: Icons.receipt_long_rounded,
                  title: 'my_visits.check_out.with_order'.tr,
                  subtitle: orders.isEmpty
                      ? 'my_visits.check_out.with_order_none'.tr
                      : 'my_visits.check_out.with_order_hint'
                          .trParams({'count': orders.length}),
                  selected: _outcome == CheckOutOutcome.withOrder,
                  enabled: orders.isNotEmpty,
                  onTap: () =>
                      setState(() => _outcome = CheckOutOutcome.withOrder),
                ),
                if (_outcome == CheckOutOutcome.withOrder) ...[
                  SizedBox(height: context.rh(8)),
                  for (final order in orders)
                    _OrderTile(
                      order: order,
                      selected: _selected.contains(order.ref.clientId),
                      onChanged: (on) => setState(() => on
                          ? _selected.add(order.ref.clientId)
                          : _selected.remove(order.ref.clientId)),
                    ),
                ],
                SizedBox(height: context.rh(10)),
                _OutcomeOption(
                  icon: Icons.do_not_disturb_on_outlined,
                  title: 'my_visits.check_out.without_order'.tr,
                  subtitle: 'my_visits.check_out.without_order_hint'.tr,
                  selected: _outcome == CheckOutOutcome.withoutOrder,
                  enabled: true,
                  onTap: () =>
                      setState(() => _outcome = CheckOutOutcome.withoutOrder),
                ),
                if (_outcome == CheckOutOutcome.withoutOrder) ...[
                  SizedBox(height: context.rh(12)),
                  _ReasonPicker(
                    selected: _reason,
                    onSelected: (r) => setState(() => _reason = r),
                  ),
                  SizedBox(height: context.rh(12)),
                  TextField(
                    controller: _note,
                    maxLength: _noteMax,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _noteRequired
                          ? 'my_visits.check_out.note_required_label'.tr
                          : 'my_visits.check_out.note_label'.tr,
                      helperText: _noteRequired
                          ? 'my_visits.check_out.note_required'.tr
                          : null,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              context.rw(16), context.rh(4), context.rw(16), context.rh(12)),
          child: FilledButton.icon(
            onPressed: _valid ? _confirm : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: Text(
              'my_visits.check_out.confirm'.tr,
              style: TextStyle(
                fontSize: context.rsp(15),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One of the two ways a visit can end. Radio semantics: selecting one
/// deselects the other.
class _OutcomeOption extends StatelessWidget {
  const _OutcomeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final accent = enabled ? scheme.primary : colors.iconMuted;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: enabled,
      child: Material(
        color:
            selected ? scheme.primary.withValues(alpha: 0.06) : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? scheme.primary : colors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.rw(14), vertical: context.rh(12)),
              child: Row(
                children: [
                  Container(
                    width: context.rr(40),
                    height: context.rr(40),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accent, size: context.rr(20)),
                  ),
                  SizedBox(width: context.rw(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: enabled
                                ? scheme.onSurface
                                : colors.textSecondary,
                            fontSize: context.rsp(14.5),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: context.rh(2)),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: context.rsp(12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected ? scheme.primary : colors.iconMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.order,
    required this.selected,
    required this.onChanged,
  });

  final VisitOrderOption order;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final time =
        DateFormat.Hm(context.languageCode).format(order.createdAt.toLocal());
    final total =
        NumberFormat.currency(locale: context.languageCode, symbol: r'$')
            .format(order.total);
    return CheckboxListTile(
      value: selected,
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.only(left: context.rw(8)),
      title: Text(
        'my_visits.check_out.order_line'.trParams({
          'time': time,
          'items': order.itemCount,
          'total': total,
        }),
        style: TextStyle(fontSize: context.rsp(13.5)),
      ),
    );
  }
}

/// The server's "no order" reasons as one-tap chips, in its order.
class _ReasonPicker extends StatelessWidget {
  const _ReasonPicker({required this.selected, required this.onSelected});

  final NoOrderReason? selected;
  final ValueChanged<NoOrderReason> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return BlocBuilder<CheckOutReasonsCubit, List<NoOrderReason>?>(
      builder: (context, reasons) {
        if (reasons == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'my_visits.check_out.reason_title'.tr,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: context.rsp(12.5),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: context.rh(8)),
            Wrap(
              spacing: context.rw(8),
              runSpacing: context.rh(8),
              children: [
                for (final reason in reasons)
                  ChoiceChip(
                    label: Text(_label(context, reason)),
                    selected: selected?.code == reason.code,
                    onSelected: (_) => onSelected(reason),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  static String _label(BuildContext context, NoOrderReason reason) {
    final name = reason.name(context.languageCode);
    // The built-in `other` (no list fetched yet) carries no names of its own.
    if (name.isEmpty) return 'my_visits.check_out.other'.tr;
    return name;
  }
}
