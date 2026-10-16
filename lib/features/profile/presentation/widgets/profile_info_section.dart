import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/profile/domain/entities/worker_profile.dart';
import 'package:steelforce/core/theme/app_colors.dart';

/// Everything `/auth/me` says about the employee, grouped the way a person
/// reads it — except permissions and feature flags, which are the app's
/// business, not theirs.
///
/// A field the server did not supply is left out rather than shown as an
/// empty row. The preferred language is not shown here: it follows the app
/// language the rep picks in Settings.
class ProfileInfoSection extends StatelessWidget {
  const ProfileInfoSection({
    super.key,
    required this.profile,
    this.compact = false,
  });

  final WorkerProfile profile;

  /// Short values two to a line, with tighter spacing — the dialog layout, so
  /// the whole profile fits on one portrait screen without scrolling. The
  /// default list layout is for the tablet, where there is room.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final gap = SizedBox(height: context.rh(compact ? 6 : 14));
    final statusText =
        profile.isActive ? 'profile.active'.tr : 'profile.inactive'.tr;
    final statusColor = profile.isActive ? colors.success : colors.warning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Group(
          compact: compact,
          icon: Icons.person_rounded,
          title: 'profile.section_contact'.tr,
          rows: [
            _Row(Icons.email_rounded, 'profile.email'.tr, profile.email,
                stacked: true, wide: true),
            if (profile.phone.isNotEmpty)
              _Row(Icons.phone_rounded, 'profile.phone'.tr, profile.phone,
                  stacked: true),
          ],
        ),
        gap,
        _Group(
          compact: compact,
          icon: Icons.work_rounded,
          title: 'profile.section_work'.tr,
          rows: [
            if (profile.department case final v?)
              _Row(Icons.apartment_rounded, 'profile.department'.tr, v,
                  stacked: true),
            if (profile.territoryCode case final v?)
              _Row(Icons.map_rounded, 'profile.territory'.tr, v, stacked: true),
            if (profile.position case final v?)
              _Row(Icons.badge_rounded, 'profile.job_title'.tr, v, wide: true),
            if (profile.depotCode case final v?)
              _Row(Icons.warehouse_rounded, 'profile.depot'.tr, v,
                  stacked: true),
            if (profile.lineManager case final v?)
              _Row(Icons.supervisor_account_rounded, 'profile.line_manager'.tr,
                  v,
                  stacked: true, wide: true),
          ],
          // The note explains the rows above it, so it sits inside their card.
          footer: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: context.rh(1)),
                child: Icon(Icons.info_outline_rounded,
                    size: context.rr(15), color: colors.textSecondary),
              ),
              SizedBox(width: context.rw(8)),
              Expanded(
                child: Text(
                  'profile.managed_note'.tr,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: context.rsp(11.5),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        gap,
        _Group(
          compact: compact,
          icon: Icons.verified_user_rounded,
          iconColor: colors.success,
          title: 'profile.section_account'.tr,
          // Compact: the status rides in the title strip, saving a whole line
          // — part of what keeps the dialog on one screen.
          trailing: compact
              ? MergeSemantics(
                  child: Semantics(
                    label: 'profile.status'.tr,
                    child: _StatusPill(text: statusText, color: statusColor),
                  ),
                )
              : null,
          rows: [
            if (!compact)
              _Row(
                profile.isActive
                    ? Icons.check_circle_rounded
                    : Icons.pause_circle_rounded,
                'profile.status'.tr,
                statusText,
                accent: statusColor,
                pill: true,
              ),
            if (profile.lastLoginAt case final at?)
              _Row(Icons.login_rounded, 'profile.last_sign_in'.tr,
                  _formatDateTime(context, at),
                  wide: true),
            if (profile.temporaryPasswordExpiresAt case final at?)
              _Row(Icons.timer_outlined, 'profile.temp_password_expires'.tr,
                  _formatDateTime(context, at),
                  accent: colors.warning, wide: true),
            if (profile.passwordExpiresAt case final at?)
              _Row(Icons.lock_clock_rounded, 'profile.password_expires'.tr,
                  _formatDate(context, at),
                  wide: true),
          ],
        ),
      ],
    );
  }

  static String _formatDateTime(BuildContext context, DateTime at) {
    final locale = Localizations.localeOf(context).languageCode;
    try {
      return DateFormat.yMMMd(locale).add_jm().format(at.toLocal());
    } catch (_) {
      return DateFormat.yMMMd().add_jm().format(at.toLocal());
    }
  }

  static String _formatDate(BuildContext context, DateTime at) {
    final locale = Localizations.localeOf(context).languageCode;
    try {
      return DateFormat.yMMMd(locale).format(at.toLocal());
    } catch (_) {
      return DateFormat.yMMMd().format(at.toLocal());
    }
  }
}

class _Row {
  const _Row(
    this.icon,
    this.label,
    this.value, {
    this.accent,
    this.stacked = false,
    this.pill = false,
    this.wide = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;

  /// Label above value — for values that run long (an email, a job title).
  /// Otherwise label left, value right.
  final bool stacked;

  /// Value drawn as a tinted badge, in [accent] — the account status.
  final bool pill;

  /// In the compact grid, takes the whole line instead of half — for a value
  /// too long to share one (an email).
  final bool wide;
}

/// A card with a tinted title band, its rows, and an optional footer.
class _Group extends StatelessWidget {
  const _Group({
    required this.icon,
    required this.title,
    required this.rows,
    this.iconColor,
    this.footer,
    this.trailing,
    this.compact = false,
  });

  final bool compact;

  /// Drawn at the end of the title strip.
  final Widget? trailing;
  final IconData icon;
  final Color? iconColor;
  final String title;
  final List<_Row> rows;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty && trailing == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final radius = BorderRadius.circular(AppColors.radius);

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: radius,
        border: Border.all(color: colors.border),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: scheme.primary.withValues(alpha: 0.06),
              padding: EdgeInsets.symmetric(
                  horizontal: context.rw(compact ? 14 : 16),
                  vertical: context.rh(compact ? 6 : 12)),
              child: Row(
                children: [
                  Icon(icon,
                      size: context.rr(compact ? 18 : 20),
                      color: iconColor ?? scheme.primary),
                  SizedBox(width: context.rw(12)),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: context.rsp(compact ? 14 : 15),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (trailing case final t?) t,
                ],
              ),
            ),
            if (rows.isEmpty)
              const SizedBox.shrink()
            else if (compact)
              Padding(
                padding: EdgeInsets.fromLTRB(context.rw(14), context.rh(8),
                    context.rw(14), context.rh(8)),
                child: _CompactGrid(rows: rows),
              )
            else
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: context.rw(16), vertical: context.rh(4)),
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++)
                      _InfoTile(row: rows[i], showDivider: i < rows.length - 1),
                  ],
                ),
              ),
            if (footer case final f?)
              Padding(
                padding: EdgeInsets.fromLTRB(
                    context.rw(compact ? 14 : 16),
                    0,
                    context.rw(compact ? 14 : 16),
                    context.rh(compact ? 10 : 14)),
                child: f,
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.row, required this.showDivider});

  final _Row row;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final accent = row.accent ?? scheme.primary;
    final iconSize = context.rr(40);

    final label = Text(
      row.label,
      style: TextStyle(
        color: colors.textSecondary,
        fontSize: context.rsp(12.5),
      ),
    );
    final valueStyle = TextStyle(
      color: scheme.onSurface,
      fontSize: context.rsp(14),
      fontWeight: FontWeight.w700,
    );

    final Widget value;
    if (row.pill) {
      value = Container(
        padding: EdgeInsets.symmetric(
            horizontal: context.rw(10), vertical: context.rh(3)),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          row.value,
          style: TextStyle(
            color: accent,
            fontSize: context.rsp(12.5),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    } else {
      value = Text(row.value,
          textAlign: row.stacked ? TextAlign.start : TextAlign.end,
          // Label-left rows keep the value on one line — a job title that
          // wrapped under itself read as two values.
          maxLines: row.stacked ? null : 1,
          overflow: row.stacked ? null : TextOverflow.ellipsis,
          style: valueStyle);
    }

    return MergeSemantics(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: context.rh(10)),
            child: Row(
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(row.icon, size: context.rr(19), color: accent),
                ),
                SizedBox(width: context.rw(14)),
                if (row.stacked)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label,
                        SizedBox(height: context.rh(2)),
                        value,
                      ],
                    ),
                  )
                else ...[
                  Flexible(flex: 2, child: label),
                  SizedBox(width: context.rw(12)),
                  // The value takes most of the line, so a job title or a
                  // date fits on one line beside its short label.
                  Expanded(
                    flex: 5,
                    child:
                        Align(alignment: Alignment.centerRight, child: value),
                  ),
                ],
              ],
            ),
          ),
          // Starts under the text, not under the icon.
          if (showDivider)
            Divider(
              height: 1,
              indent: iconSize + context.rw(14),
              color: colors.divider,
            ),
        ],
      ),
    );
  }
}

/// Rows two to a line, each a small icon beside its label and value.
/// A [_Row.wide] row takes the whole line.
class _CompactGrid extends StatelessWidget {
  const _CompactGrid({required this.rows});

  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final columnGap = context.rw(12);
    return LayoutBuilder(
      builder: (context, box) {
        final half = (box.maxWidth - columnGap) / 2;
        return Wrap(
          spacing: columnGap,
          runSpacing: context.rh(8),
          children: [
            for (final row in rows)
              SizedBox(
                width: row.wide ? box.maxWidth : half,
                child: _GridCell(row: row),
              ),
          ],
        );
      },
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({required this.row});

  final _Row row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final accent = row.accent ?? scheme.primary;
    final iconBox = context.rr(30);

    final Widget value = row.pill
        ? Container(
            margin: EdgeInsets.only(top: context.rh(2)),
            padding: EdgeInsets.symmetric(
                horizontal: context.rw(8), vertical: context.rh(1)),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              row.value,
              style: TextStyle(
                color: accent,
                fontSize: context.rsp(12),
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : Text(
            row.value,
            maxLines: row.wide && !row.stacked ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            textAlign:
                row.wide && !row.stacked ? TextAlign.end : TextAlign.start,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: context.rsp(13.5),
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          );

    final iconCircle = Container(
      width: iconBox,
      height: iconBox,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(row.icon, size: context.rr(16), color: accent),
    );
    final label = Text(
      row.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: colors.textSecondary,
        fontSize: context.rsp(11.5),
      ),
    );

    // A full-width row that is not stacked reads as one line: label left,
    // value right — the account dates.
    if (row.wide && !row.stacked) {
      return MergeSemantics(
        child: Row(
          children: [
            iconCircle,
            SizedBox(width: context.rw(10)),
            Flexible(flex: 2, child: label),
            SizedBox(width: context.rw(8)),
            Expanded(
              flex: 5,
              child: Align(alignment: Alignment.centerRight, child: value),
            ),
          ],
        ),
      );
    }

    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconCircle,
          SizedBox(width: context.rw(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                SizedBox(height: context.rh(1)),
                value,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.rw(10), vertical: context.rh(2)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: context.rsp(12),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
