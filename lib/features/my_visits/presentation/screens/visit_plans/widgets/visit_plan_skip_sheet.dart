import 'package:flutter/material.dart';
import 'package:steelforce/core/error/failure_message.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/platform/device/device_insets.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/presentation/screens/visit_plans/widgets/visit_plan_skip_reasons.dart';
import 'package:steelforce/shared/widgets/keyboard_aware_scroll_view.dart';

/// Asks why [plan] is being skipped and sends it through [submit], which
/// returns the failure or null. Styled as the stop dashboard's skip sheet. A
/// refusal is shown in the sheet, which stays open. Resolves true once the
/// visit is skipped.
///
/// The rep picks one of the preset reasons — no free text. No photo slot: the
/// skip endpoint takes a reason only, and a photo would be thrown away.
Future<bool> showVisitPlanSkipSheet(
  BuildContext context, {
  required VisitPlan plan,
  required Future<Failure?> Function(String reason) submit,
}) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SkipSheet(plan: plan, submit: submit),
  );
  return done ?? false;
}

class _SkipSheet extends StatefulWidget {
  const _SkipSheet({required this.plan, required this.submit});

  final VisitPlan plan;
  final Future<Failure?> Function(String reason) submit;

  @override
  State<_SkipSheet> createState() => _SkipSheetState();
}

class _SkipSheetState extends State<_SkipSheet> {
  String? _choice;
  bool _sending = false;
  Failure? _failure;

  bool get _canSend => !_sending && _choice != null;

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _failure = null;
    });
    final failure = await widget.submit(_choice!);
    if (!mounted) return;
    if (failure == null) return Navigator.of(context).pop(true);
    setState(() {
      _sending = false;
      _failure = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    TextStyle heading() => TextStyle(
        fontSize: context.rsp(12.5),
        fontWeight: FontWeight.w700,
        color: colors.textPrimary);

    return Padding(
      padding: EdgeInsets.only(bottom: context.deviceInsets.keyboard),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(context.rr(24))),
        ),
        padding: EdgeInsets.fromLTRB(
            context.rw(20), context.rh(12), context.rw(20), context.rh(20)),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: context.deviceInsets.screenSize.height * 0.9),
            child: KeyboardAwareScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: context.rw(36),
                      height: context.rh(4),
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: context.rh(16)),
                  Text('my_visits.skip_visit.title'.tr,
                      style: TextStyle(
                          fontSize: context.rsp(17),
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary)),
                  SizedBox(height: context.rh(4)),
                  Text(
                      widget.plan.displayName ??
                          'my_visits.plans.field.null_value'.tr,
                      style: TextStyle(
                          fontSize: context.rsp(12.5),
                          color: colors.textSecondary)),
                  SizedBox(height: context.rh(18)),
                  Text('my_visits.skip_visit.reason'.tr, style: heading()),
                  SizedBox(height: context.rh(8)),
                  VisitPlanSkipReasons(
                    selected: _choice,
                    onSelected: _sending
                        ? null
                        : (value) => setState(() {
                              _choice = value;
                              _failure = null;
                            }),
                  ),
                  if (_failure case final failure?) ...[
                    SizedBox(height: context.rh(10)),
                    Text(failure.userMessage,
                        style: TextStyle(
                            color: scheme.error, fontSize: context.rsp(12.5))),
                  ],
                  SizedBox(height: context.rh(20)),
                  SizedBox(
                    width: double.infinity,
                    height: context.rh(48),
                    child: ElevatedButton(
                      onPressed: _canSend ? _send : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: colors.border,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(context.rr(12))),
                      ),
                      child: _sending
                          ? SizedBox.square(
                              dimension: context.rr(20),
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2.2, color: Colors.white))
                          : Text('my_visits.skip_visit.submit'.tr,
                              style: TextStyle(
                                  fontSize: context.rsp(14.5),
                                  fontWeight: FontWeight.w800)),
                    ),
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
