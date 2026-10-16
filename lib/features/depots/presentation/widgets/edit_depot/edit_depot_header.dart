import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/domain/entities/depot.dart';

/// The edit sheet's title row: icon, "Edit Depot Details", which depot, and
/// a close button.
class EditDepotHeader extends StatelessWidget {
  const EditDepotHeader({super.key, required this.depot});

  final Depot depot;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        Container(
          width: context.rr(40),
          height: context.rr(40),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(context.rr(10)),
          ),
          child: Icon(
            Icons.edit_location_alt_rounded,
            color: Colors.orange.shade800,
            size: context.rr(22),
          ),
        ),
        SizedBox(width: context.rw(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Depot Details',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: context.rsp(17),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: context.rh(2)),
              Text(
                depot.depotCode.isNotEmpty
                    ? depot.depotCode
                    : (depot.sapDepotId ?? 'Depot Profile'),
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: context.rsp(12),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close_rounded, color: colors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Why nothing on the sheet can be changed: the depot is closed, which is
/// terminal (the server answers Depot.Closed / 422).
class EditDepotClosedNotice extends StatelessWidget {
  const EditDepotClosedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(context.rr(12)),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(context.rr(12)),
        border: Border.all(
          color: scheme.error.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_clock_rounded,
            color: scheme.error,
            size: context.rr(20),
          ),
          SizedBox(width: context.rw(10)),
          Expanded(
            child: Text(
              'This depot is Closed and immutable. Changes cannot be submitted (Depot.Closed).',
              style: TextStyle(
                color: scheme.error,
                fontSize: context.rsp(12),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
