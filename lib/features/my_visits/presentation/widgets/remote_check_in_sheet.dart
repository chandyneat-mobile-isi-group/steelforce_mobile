import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Collects the rep's written reason for checking in away from the stop's pin.
///
/// ## Why the reason is mandatory rather than optional
///
/// The geofence is the only evidence that a visit happened where it claims to.
/// Letting a rep step past it with a tap would remove that evidence and leave
/// nothing in its place. A reason does not prove the rep was there — nothing on
/// the device can — but it makes the override *attributable*: a supervisor
/// reading "gate is 200 m from the office pin" and one reading nothing at all
/// are in very different positions.
///
/// So the CTA stays disabled until the text clears
/// `FraudPolicy.minOverrideReasonLength`. That threshold is deliberately short.
/// A rep standing in a yard in the sun is not going to write an essay, and a
/// limit that fights them produces "aaaaaaaaaa", which is worse than a short
/// honest sentence.
///
/// ## Why the presets are prefills, not choices
///
/// The four common cases are one tap, but each one *fills the field* rather
/// than submitting. The rep can add the specific detail — which gate, which
/// building — and that detail is the part worth having. A fixed dropdown would
/// have collected four strings forever.
///
/// Returns the trimmed reason, or null if the rep backed out.
class RemoteCheckInSheet extends StatefulWidget {
  const RemoteCheckInSheet({
    super.key,
    required this.blockedReason,
    required this.distanceMeters,
    required this.minLength,
    this.title,
    this.intro,
    this.presets,
    this.icon,
  });

  /// What the validator objected to, shown verbatim so the rep is answering
  /// the actual objection rather than a paraphrase of it.
  final String blockedReason;

  /// Metres from the depot's pin, for the rep's own orientation. Also the
  /// number that goes to the server on the check-in row either way.
  ///
  /// Null when nothing was measured (the no-GPS path) — the line is omitted
  /// rather than printing "NaN m" or a made-up "0 m".
  final double? distanceMeters;

  final int minLength;

  /// Overrides for the no-GPS variant. Defaults are the out-of-area copy.
  final String? title;
  final String? intro;
  final List<String>? presets;
  final IconData? icon;

  /// Prefills for "Check in without GPS" — the situations that actually
  /// produce no fix.
  static const noGpsPresets = <String>[
    'No GPS signal inside the building',
    'Location stayed on "searching" for a long time',
    'Inside a warehouse with a metal roof',
    'Phone GPS not working today',
  ];

  static Future<String?> show(
    BuildContext context, {
    required String blockedReason,
    required double? distanceMeters,
    required int minLength,
    String? title,
    String? intro,
    List<String>? presets,
    IconData? icon,
  }) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        // A slightly longer, eased entrance than the default snap.
        sheetAnimationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 360),
          reverseDuration: Duration(milliseconds: 240),
        ),
        builder: (_) => RemoteCheckInSheet(
          blockedReason: blockedReason,
          distanceMeters: distanceMeters,
          minLength: minLength,
          title: title,
          intro: intro,
          presets: presets,
          icon: icon,
        ),
      );

  @override
  State<RemoteCheckInSheet> createState() => _RemoteCheckInSheetState();
}

class _RemoteCheckInSheetState extends State<RemoteCheckInSheet> {
  // TODO(i18n): these read from `.tr` once the keys land in en/km. Written as
  // literals rather than key strings on purpose — a missing key renders as the
  // key itself, and `my_visits.checkin.override.title` on a rep's screen is
  // worse than untranslated English.
  static const _title = 'Check in from here?';
  static const _bodyPrefix = "You're not at the recorded location for this "
      'stop. You can still check in, but you need to say why.';
  static const _fieldLabel = 'Reason (required)';
  static const _hint = 'e.g. depot gate is 200 m from the pin on the map';
  static const _confirm = 'Check in anyway';
  static const _cancel = 'Go back';

  /// Prefills, not choices — see the class doc.
  static const _presets = <String>[
    'Depot entrance is far from the recorded pin',
    'No GPS signal inside the warehouse',
    'Depot pin on the map is wrong',
    'Met the depot at a different location',
  ];

  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Rebuilds the CTA's enabled state as the rep types, so the button
    // explains itself by changing rather than by rejecting a tap.
    _controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  String get _reason => _controller.text.trim();
  bool get _valid => _reason.length >= widget.minLength;
  int get _remaining => widget.minLength - _reason.length;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      // Lifts the sheet clear of the keyboard, which otherwise covers the
      // field this sheet exists to collect.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(context.rr(20))),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.rw(20),
              context.rh(12),
              context.rw(20),
              context.rh(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: context.rw(40),
                    height: context.rh(4),
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                SizedBox(height: context.rh(16)),
                Row(
                  children: [
                    Container(
                      width: context.rr(36),
                      height: context.rr(36),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widget.icon ?? Icons.wrong_location_outlined,
                          color: colors.warning, size: context.rr(20)),
                    ),
                    SizedBox(width: context.rw(8)),
                    Expanded(
                      child: Text(
                        widget.title ?? _title,
                        style: TextStyle(
                          fontSize: context.rsp(16),
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.rh(8)),
                Text(
                  widget.intro ?? _bodyPrefix,
                  style: TextStyle(
                    fontSize: context.rsp(12.5),
                    color: colors.textSecondary,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: context.rh(10)),
                Container(
                  padding: EdgeInsets.all(context.rw(10)),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(context.rr(10)),
                  ),
                  child: Text(
                    // The validator's own words plus the measured distance.
                    // The rep is answering a specific objection, and the
                    // number is what makes "the pin is wrong" checkable later.
                    widget.distanceMeters == null ||
                            widget.distanceMeters!.isNaN
                        ? widget.blockedReason
                        : '${widget.blockedReason}\n'
                            '${widget.distanceMeters!.round()} m from the recorded location.',
                    style: TextStyle(
                      fontSize: context.rsp(11.5),
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: context.rh(14)),
                Wrap(
                  spacing: context.rw(8),
                  runSpacing: context.rh(8),
                  children: [
                    for (final preset in widget.presets ?? _presets)
                      _PresetChip(
                        label: preset,
                        selected: _reason == preset,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _controller.text = preset;
                          _controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: _controller.text.length),
                          );
                        },
                      ),
                  ],
                ),
                SizedBox(height: context.rh(12)),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: _fieldLabel,
                    hintText: _hint,
                    // Counts down only while short, then goes quiet. A
                    // permanent counter reads as a target to hit.
                    helperText:
                        _valid ? null : '$_remaining more characters needed',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.rr(12)),
                    ),
                  ),
                ),
                SizedBox(height: context.rh(14)),
                SizedBox(
                  height: context.rh(48),
                  child: ElevatedButton.icon(
                    onPressed: _valid
                        ? () => Navigator.of(context).pop(_reason)
                        : null,
                    icon: Icon(Icons.how_to_reg_rounded, size: context.rr(20)),
                    label: Text(
                      _confirm,
                      style: TextStyle(
                        fontSize: context.rsp(14.5),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      disabledBackgroundColor: colors.border,
                      disabledForegroundColor: colors.textDisabled,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.rr(12)),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: context.rh(6)),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    _cancel,
                    style: TextStyle(
                      fontSize: context.rsp(13),
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A preset that visibly lights up when its text is what's in the field, so
/// the rep can see which one they picked (and that editing it un-picks it).
class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
              horizontal: context.rw(12), vertical: context.rh(7)),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.12)
                : colors.surfaceSoft,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.55)
                  : colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: selected
                    ? Padding(
                        padding: EdgeInsets.only(right: context.rw(4)),
                        child: Icon(Icons.check_rounded,
                            size: context.rr(14), color: scheme.primary),
                      )
                    : const SizedBox.shrink(),
              ),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: context.rsp(11),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? scheme.primary : colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
