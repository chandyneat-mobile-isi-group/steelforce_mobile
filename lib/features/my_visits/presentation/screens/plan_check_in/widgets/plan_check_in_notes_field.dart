import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_check_in.dart';

/// Optional notes sent with the check-in (`notes`, up to 1,000 characters).
/// Kept in the screen's controller, so a refused check-in keeps them.
class PlanCheckInNotesField extends StatelessWidget {
  const PlanCheckInNotesField({
    super.key,
    required this.controller,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        enabled: enabled,
        minLines: 2,
        maxLines: 4,
        maxLength: PlanCheckInRequest.maxNotesLength,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'my_visits.plans.check_in.notes.label'.tr,
          hintText: 'my_visits.plans.check_in.notes.hint'.tr,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.rr(12))),
        ),
      );
}
