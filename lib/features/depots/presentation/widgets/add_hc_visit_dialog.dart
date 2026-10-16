import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';

/// Displays a confirmation dialog asking the user if they want to add
/// the given depot as an HC (Ad-hoc) visit.
///
/// Returns the optional note if confirmed, or `null` if cancelled.
Future<String?> showAddHcVisitDialog(
  BuildContext context, {
  required Depot depot,
  void Function(String? note)? onConfirmed,
}) async {
  final result = await showDialog<String?>(
    context: context,
    barrierDismissible: true,
    builder: (dialogCtx) => AddHcVisitDialog(depot: depot),
  );

  // The success snackbar that used to fire here has been removed, and its
  // absence is the point: this dialog only collects a confirmation. Whether
  // the visit was actually added is decided by the server — it can be refused,
  // or queued because there is no signal — and only the caller knows. Saying
  // "added to HC visits" the moment the rep tapped Confirm told them a visit
  // existed when nothing had been sent anywhere.
  //
  // `addDepotToTodayVisits` reports the real outcome.
  if (result != null && context.mounted) onConfirmed?.call(result);

  return result;
}

class AddHcVisitDialog extends StatefulWidget {
  const AddHcVisitDialog({
    super.key,
    required this.depot,
  });

  final Depot depot;

  @override
  State<AddHcVisitDialog> createState() => _AddHcVisitDialogState();
}

class _AddHcVisitDialogState extends State<AddHcVisitDialog> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;
    final depot = widget.depot;
    final isClosed = depot.status == DepotStatus.closed;

    final primaryName = depot.shopName.isNotEmpty
        ? depot.shopName
        : (depot.enName?.isNotEmpty == true
            ? depot.enName!
            : context.localized(depot.displayName));
    final secondaryName =
        depot.khName?.isNotEmpty == true ? depot.khName : null;

    final locationParts = [
      if (depot.address.isNotEmpty) depot.address,
      if (depot.district.isNotEmpty) depot.district,
      if (depot.province.isNotEmpty) depot.province,
    ];
    final locationText = locationParts.join(', ');

    final contactParts = [
      if (depot.ownerName.isNotEmpty) depot.ownerName,
      if (depot.phone.isNotEmpty) depot.phone,
    ];
    final contactText = contactParts.join(' • ');

    final todayFormatted = DateFormat('EEE, d MMM yyyy').format(DateTime.now());

    return Dialog(
      backgroundColor: colors.card,
      elevation: 12,
      insetPadding: EdgeInsets.symmetric(
        horizontal: context.rw(20),
        vertical: context.rh(24),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.rr(20)),
        side: BorderSide(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.rw(420)),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.rr(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon and Title
              Center(
                child: Container(
                  width: context.rr(56),
                  height: context.rr(56),
                  decoration: BoxDecoration(
                    color: scheme.secondary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_location_alt_rounded,
                    color: scheme.secondary,
                    size: context.rr(28),
                  ),
                ),
              ),
              SizedBox(height: context.rh(14)),
              Text(
                'Add HC Visit',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: context.rsp(18),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: context.rh(6)),
              Text(
                'Do you want to add this depot to your HC (Ad-hoc) visits for today?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: context.rsp(13),
                  height: 1.35,
                ),
              ),
              SizedBox(height: context.rh(16)),

              // Terminal status warning
              if (isClosed) ...[
                Container(
                  padding: EdgeInsets.all(context.rr(12)),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(context.rr(12)),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cancel_outlined,
                          color: Colors.red, size: 20),
                      SizedBox(width: context.rw(10)),
                      Expanded(
                        child: Text(
                          'This depot is closed (terminal status). HC visits cannot be scheduled for closed depots.',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: context.rsp(12),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: context.rh(14)),
              ],

              // Depot Information Card
              Container(
                padding: EdgeInsets.all(context.rr(14)),
                decoration: BoxDecoration(
                  color: colors.surfaceSoft,
                  borderRadius: BorderRadius.circular(context.rr(14)),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(context.rr(8)),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(context.rr(10)),
                          ),
                          child: Icon(
                            Icons.storefront_rounded,
                            size: context.rr(20),
                            color: scheme.primary,
                          ),
                        ),
                        SizedBox(width: context.rw(10)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                primaryName,
                                style: TextStyle(
                                  fontSize: context.rsp(14),
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              if (secondaryName != null) ...[
                                SizedBox(height: context.rh(2)),
                                Text(
                                  secondaryName,
                                  style: TextStyle(
                                    fontSize: context.rsp(12),
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.rh(10)),
                    Wrap(
                      spacing: context.rw(6),
                      runSpacing: context.rh(4),
                      children: [
                        if (depot.depotCode.isNotEmpty)
                          _InfoChip(
                            label: depot.depotCode,
                            icon: Icons.tag_rounded,
                            color: scheme.primary,
                          ),
                        if (depot.sapDepotId != null &&
                            depot.sapDepotId!.isNotEmpty &&
                            depot.sapDepotId != depot.depotCode)
                          _InfoChip(
                            label: 'SAP: ${depot.sapDepotId}',
                            icon: Icons.cloud_done_outlined,
                            color: Colors.blueGrey,
                          ),
                        _InfoChip(
                          label: 'Today: $todayFormatted',
                          icon: Icons.calendar_today_rounded,
                          color: scheme.secondary,
                        ),
                      ],
                    ),
                    if (locationText.isNotEmpty) ...[
                      SizedBox(height: context.rh(10)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: context.rr(15),
                            color: colors.textSecondary,
                          ),
                          SizedBox(width: context.rw(6)),
                          Expanded(
                            child: Text(
                              locationText,
                              style: TextStyle(
                                fontSize: context.rsp(12),
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (contactText.isNotEmpty) ...[
                      SizedBox(height: context.rh(6)),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: context.rr(15),
                            color: colors.textSecondary,
                          ),
                          SizedBox(width: context.rw(6)),
                          Expanded(
                            child: Text(
                              contactText,
                              style: TextStyle(
                                fontSize: context.rsp(12),
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: context.rh(14)),

              // Note Input (Optional)
              Text(
                'Visit Objective / Note (Optional)',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: context.rsp(12),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: context.rh(6)),
              TextField(
                controller: _noteController,
                enabled: !isClosed,
                maxLines: 2,
                minLines: 1,
                style: TextStyle(
                  fontSize: context.rsp(13),
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText:
                      'e.g. Follow-up on quotation, collect payment, inspect stock...',
                  hintStyle: TextStyle(
                    fontSize: context.rsp(12),
                    color: colors.textSecondary.withValues(alpha: 0.7),
                  ),
                  filled: true,
                  fillColor: colors.surfaceSoft,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: context.rw(12),
                    vertical: context.rh(10),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.rr(10)),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.rr(10)),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.rr(10)),
                    borderSide: BorderSide(color: scheme.primary, width: 1.5),
                  ),
                ),
              ),
              SizedBox(height: context.rh(20)),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: context.rh(12)),
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.rr(12)),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: context.rsp(13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: context.rw(12)),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isClosed
                          ? null
                          : () {
                              final note = _noteController.text.trim();
                              Navigator.of(context).pop(note);
                            },
                      icon:
                          const Icon(Icons.add_location_alt_rounded, size: 18),
                      label: Text(
                        'Add Visit',
                        style: TextStyle(
                          fontSize: context.rsp(13),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.secondary,
                        foregroundColor: scheme.onSecondary,
                        disabledBackgroundColor: colors.surfaceSoft,
                        disabledForegroundColor:
                            colors.textSecondary.withValues(alpha: 0.5),
                        padding: EdgeInsets.symmetric(vertical: context.rh(12)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.rr(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(8),
        vertical: context.rh(4),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(context.rr(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: context.rr(12), color: color),
          SizedBox(width: context.rw(4)),
          Text(
            label,
            style: TextStyle(
              fontSize: context.rsp(11),
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
