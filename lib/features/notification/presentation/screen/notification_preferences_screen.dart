import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/responsive/responsive_content_frame.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/notification/domain/entities/notification_preferences.dart';
import 'package:steelforce/features/notification/presentation/bloc/notification_preferences_cubit.dart';

/// The notification settings screen
/// (`docs/feature/notification/README.md` §13).
///
/// ## Built from the server's answer, not from a list in the app
///
/// Every row comes from the `categories` array the API returned. §13 is explicit
/// about why: a category added server-side stays invisible until the app is
/// rebuilt otherwise. So this screen renders a category code it has never heard
/// of, using the server's own `displayName`, rather than filtering it out.
///
/// ## Locked rows are shown disabled, never hidden
///
/// A rep should be able to *see* what they are receiving even when they cannot
/// stop it. Hiding the seven locked categories would leave a settings screen
/// that appears to control everything while quietly omitting most of what
/// actually arrives.
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  late final NotificationPreferencesCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = GetIt.instance<NotificationPreferencesCubit>()..load();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocProvider.value(
      value: _cubit,
      child: LocalizedBuilder(
        builder: (context) => Scaffold(
          backgroundColor: colors.canvas,
          appBar: AppBar(
            title: Text(
              'notifications.settings.title'.tr,
              style: TextStyle(
                fontSize: context.rsp(17),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          body: ResponsiveContentFrame(
            child: BlocConsumer<NotificationPreferencesCubit,
                NotificationPreferencesState>(
              listenWhen: (previous, current) =>
                  previous.errorMessage != current.errorMessage &&
                  current.errorMessage != null,
              listener: (context, state) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.errorMessage!)),
                );
                context.read<NotificationPreferencesCubit>().acknowledgeError();
              },
              builder: (context, state) {
                if (state.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.loadFailed) {
                  return _LoadFailed(onRetry: _cubit.load);
                }
                return _Content(state: state);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state});

  final NotificationPreferencesState state;

  @override
  Widget build(BuildContext context) {
    final preferences = state.preferences;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        context.rh(12),
        context.pagePadding,
        context.rh(24),
      ),
      children: [
        _QuietHoursSection(preferences: preferences, saving: state.saving),
        SizedBox(height: context.rh(20)),
        _SectionTitle('notifications.settings.categories'.tr),
        SizedBox(height: context.rh(8)),
        if (preferences.categories.isEmpty)
          // Not an error. §13: a rep who has never opened this screen still gets
          // a full response, so an empty list means the server sent one — which
          // is worth saying plainly rather than rendering as a blank page.
          _EmptyCategories()
        else
          for (final category in preferences.categories)
            _CategoryRow(preference: category, disabled: state.saving),
      ],
    );
  }
}

/// Quiet hours and the digest time.
///
/// Read-only display plus a clear/set control. The window **defers, it never
/// drops** (§13): a P2 raised at 22:00 is delivered when the window ends, and P1
/// ignores the window entirely — a route cancelled at midnight for an 06:00
/// start has to wake somebody. That is stated on screen, because a rep who
/// believes quiet hours silence everything will not trust an alarm that fires
/// anyway.
class _QuietHoursSection extends StatelessWidget {
  const _QuietHoursSection({required this.preferences, required this.saving});

  final NotificationPreferences preferences;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cubit = context.read<NotificationPreferencesCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('notifications.settings.quiet_hours'.tr),
        SizedBox(height: context.rh(8)),
        Container(
          padding: EdgeInsets.all(context.rw(14)),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      preferences.hasQuietHours
                          ? 'notifications.settings.quiet_hours_range'
                              .trParams({
                              'start': _hhmm(preferences.quietHoursStart!),
                              'end': _hhmm(preferences.quietHoursEnd!),
                            })
                          : 'notifications.settings.quiet_hours_off'.tr,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: context.rsp(14),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => _editWindow(context, cubit, preferences),
                    child: Text(
                      preferences.hasQuietHours
                          ? 'common.edit'.tr
                          : 'notifications.settings.set'.tr,
                      style: TextStyle(fontSize: context.rsp(12)),
                    ),
                  ),
                  if (preferences.hasQuietHours)
                    TextButton(
                      onPressed: saving ? null : () => cubit.setQuietHours(),
                      child: Text(
                        'common.clear'.tr,
                        style: TextStyle(fontSize: context.rsp(12)),
                      ),
                    ),
                ],
              ),
              if (preferences.hasQuietHours) ...[
                SizedBox(height: context.rh(4)),
                Text(
                  // `quietDays: []` means **every day**, not "no days" (§13).
                  // Rendering the empty list as "no days selected" would be the
                  // exact inversion the spec warns about.
                  preferences.quietEveryDay
                      ? 'notifications.settings.quiet_every_day'.tr
                      : preferences.quietDays.join(', '),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: context.rsp(12),
                  ),
                ),
              ],
              SizedBox(height: context.rh(8)),
              Text(
                'notifications.settings.quiet_hours_note'.tr,
                style: TextStyle(
                  color: colors.textHint,
                  fontSize: context.rsp(11.5),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Collects **both** ends of the window, or neither.
  ///
  /// §13: one without the other answers
  /// `400 Notification.QuietHoursIncomplete`. Backing out of the second picker
  /// therefore abandons the whole edit rather than saving a half-set window —
  /// the cubit would refuse it anyway, and refusing here means the rep never
  /// sees an error for something the UI could simply not have asked.
  Future<void> _editWindow(
    BuildContext context,
    NotificationPreferencesCubit cubit,
    NotificationPreferences preferences,
  ) async {
    final start = await showTimePicker(
      context: context,
      initialTime: _parse(preferences.quietHoursStart) ??
          const TimeOfDay(hour: 20, minute: 0),
      helpText: 'notifications.settings.quiet_start'.tr,
    );
    if (start == null || !context.mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: _parse(preferences.quietHoursEnd) ??
          const TimeOfDay(hour: 7, minute: 0),
      helpText: 'notifications.settings.quiet_end'.tr,
    );
    if (end == null) return;

    // A window that wraps midnight (20:00 → 07:00) is normal and handled
    // server-side, so no validation compares the two.
    await cubit.setQuietHours(start: _format(start), end: _format(end));
  }

  static TimeOfDay? _parse(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// `HH:mm:ss` — the wire format §13 uses.
  static String _format(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:00';

  /// Drops the seconds for display.
  static String _hhmm(String value) {
    final parts = value.split(':');
    return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : value;
  }
}

/// One category row: enabled, and whether it may push.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.preference, required this.disabled});

  final NotificationCategoryPreference preference;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cubit = context.read<NotificationPreferencesCubit>();
    final locked = preference.isLocked;

    return Container(
      margin: EdgeInsets.only(bottom: context.rh(8)),
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(14),
        vertical: context.rh(10),
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // The **server's** label, not a local translation: this is
                      // the one surface that must render a category the app has
                      // never heard of (§13).
                      preference.displayName,
                      style: TextStyle(
                        color:
                            locked ? colors.textSecondary : colors.textPrimary,
                        fontSize: context.rsp(13.5),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (locked) ...[
                      SizedBox(height: context.rh(2)),
                      Text(
                        // The explanation §13 requires beside a disabled toggle.
                        // A switch that simply will not move, with no reason
                        // given, reads as a broken control.
                        'notifications.settings.locked'.tr,
                        style: TextStyle(
                          color: colors.textHint,
                          fontSize: context.rsp(11),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: preference.isEnabled,
                onChanged: locked || disabled
                    ? null
                    : (value) => cubit.toggleCategory(
                          preference.category,
                          isEnabled: value,
                        ),
              ),
            ],
          ),
          // `pushEnabled: false` with `isEnabled: true` is a supported, normal
          // combination meaning "inbox only" (§13), so it gets its own control
          // rather than being folded into the switch above.
          if (preference.isEnabled)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'notifications.settings.push'.tr,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(12),
                    ),
                  ),
                ),
                Switch(
                  value: preference.pushEnabled,
                  onChanged: locked || disabled
                      ? null
                      : (value) => cubit.toggleCategory(
                            preference.category,
                            pushEnabled: value,
                          ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          color: context.appColors.textPrimary,
          fontSize: context.rsp(14),
          fontWeight: FontWeight.w800,
        ),
      );
}

class _EmptyCategories extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: context.rh(24)),
        child: Text(
          'notifications.settings.no_categories'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.appColors.textHint,
            fontSize: context.rsp(12.5),
          ),
        ),
      );
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.rw(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: context.rr(40), color: colors.iconMuted),
            SizedBox(height: context.rh(12)),
            Text(
              'notifications.settings.load_failed'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: context.rsp(13),
                height: 1.4,
              ),
            ),
            SizedBox(height: context.rh(16)),
            FilledButton(
              onPressed: onRetry,
              child: Text('common.retry'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
