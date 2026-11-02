import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/error/failure_message.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/depots/data/models/bp_depot_form_data.dart';
import 'package:steelforce/features/depots/presentation/bloc/supplying_depot_picker_cubit.dart';
import 'package:steelforce/shared/widgets/app_bottom_sheet.dart';

/// Picks the depots a Non-BP depot buys from. Returns SAP customer number →
/// display name, or null when dismissed.
Future<Map<String, String>?> showSupplyingDepotPicker(
  BuildContext context, {
  required Map<String, String> selected,
}) =>
    showAppBottomSheet<Map<String, String>>(
      context: context,
      builder: (_) => BlocProvider(
        create: (_) => sl<SupplyingDepotPickerCubit>()..search(''),
        child: _SupplyingDepotPicker(initial: selected),
      ),
    );

class _SupplyingDepotPicker extends StatefulWidget {
  const _SupplyingDepotPicker({required this.initial});

  final Map<String, String> initial;

  @override
  State<_SupplyingDepotPicker> createState() => _SupplyingDepotPickerState();
}

class _SupplyingDepotPickerState extends State<_SupplyingDepotPicker> {
  late final Map<String, String> _selected = {...widget.initial};
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300),
        () => context.read<SupplyingDepotPickerCubit>().search(value));
  }

  void _toggle(String code, String name) => setState(() {
        if (_selected.remove(code) != null) return;
        if (_selected.length < BpDepotDraft.maxSupplyingDepots) {
          _selected[code] = name;
        }
      });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'add_depot.supplying_depots.title'.tr,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'add_depot.supplying_depots.hint'.tr,
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: _onQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'add_depot.supplying_depots.search'.tr,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: BlocBuilder<SupplyingDepotPickerCubit,
                SupplyingDepotPickerState>(
              builder: (context, state) => switch (state) {
                SupplyingDepotPickerLoading() =>
                  const Center(child: CircularProgressIndicator()),
                SupplyingDepotPickerEmpty() =>
                  _Message('add_depot.supplying_depots.empty'.tr),
                SupplyingDepotPickerFailure(:final failure) =>
                  _Message(failure.userMessage),
                SupplyingDepotPickerLoaded(:final depots) => ListView.builder(
                    itemCount: depots.length,
                    itemBuilder: (context, i) {
                      final depot = depots[i];
                      final code = depot.sapDepotId!.trim();
                      final name = context.localized(depot.displayName);
                      return CheckboxListTile(
                        value: _selected.containsKey(code),
                        onChanged: (_) => _toggle(code, name),
                        // The name alone; the code is what is sent.
                        title: Text(name, maxLines: 2),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      );
                    },
                  ),
              },
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_selected),
            child: Text('add_depot.supplying_depots.done'
                .trParams({'count': '${_selected.length}'})),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.appColors.textSecondary),
          ),
        ),
      );
}
