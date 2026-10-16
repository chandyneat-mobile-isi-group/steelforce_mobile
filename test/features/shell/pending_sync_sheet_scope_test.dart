import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks the assumption `showPendingSyncSheet` relies on to fall back to its
/// own cubits: `context.read` reports a missing provider as
/// [ProviderNotFoundException] (`BlocProvider.of` does not).
void main() {
  testWidgets('context.read throws ProviderNotFoundException off-scope',
      (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(Builder(builder: (context) {
      captured = context;
      return const SizedBox();
    }));

    expect(() => captured.read<Cubit<int>>(),
        throwsA(isA<ProviderNotFoundException>()));
  });
}
