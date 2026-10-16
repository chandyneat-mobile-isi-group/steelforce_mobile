import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/depots/domain/entities/depot_code_lookup.dart';
import 'package:steelforce/features/depots/domain/entities/portal_depot.dart';
import 'package:steelforce/features/depots/domain/usecases/lookup_depot_by_code.dart';

/// Resolves a depot number the local book does not have.
///
/// Its own cubit rather than an event on `DepotsBloc` because it is the one
/// depot read that leaves the device. Keeping it separate makes that obvious
/// at the call site and keeps the browse path — which must stay local and free
/// — unable to trigger it by accident.
sealed class DepotCodeLookupState extends Equatable {
  const DepotCodeLookupState();
  @override
  List<Object?> get props => const [];
}

final class CodeLookupIdle extends DepotCodeLookupState {
  const CodeLookupIdle();
}

final class CodeLookupInProgress extends DepotCodeLookupState {
  const CodeLookupInProgress(this.code);
  final String code;
  @override
  List<Object?> get props => [code];
}

/// Found. [depot] carries the platform `id`, which is what the mobile detail
/// endpoint takes — so the caller can open the depot immediately.
final class CodeLookupFound extends DepotCodeLookupState {
  const CodeLookupFound(this.depot);
  final PortalDepot depot;
  @override
  List<Object?> get props => [depot];
}

/// Neither the platform nor SAP has this code. **The only state in which
/// offering to register the shop is safe.**
final class CodeLookupAbsent extends DepotCodeLookupState {
  const CodeLookupAbsent(this.code);
  final String code;
  @override
  List<Object?> get props => [code];
}

/// The ERP could not be reached. Distinct from [CodeLookupAbsent] on purpose:
/// the depot may well exist, and inviting a registration here would create a
/// duplicate business partner in SAP.
final class CodeLookupUnavailable extends DepotCodeLookupState {
  const CodeLookupUnavailable();
}

/// A transport or authorisation failure — not an answer about the code.
final class CodeLookupFailed extends DepotCodeLookupState {
  const CodeLookupFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class DepotCodeLookupCubit extends Cubit<DepotCodeLookupState> {
  DepotCodeLookupCubit(this._lookup) : super(const CodeLookupIdle());

  final LookupDepotByCode _lookup;

  /// Looks [code] up on the server.
  ///
  /// Only ever called from an explicit action on a full code — never from the
  /// keystroke path, because this can reach the ERP.
  Future<void> lookup(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;

    emit(CodeLookupInProgress(trimmed));
    final result = await _lookup(trimmed);

    emit(
      result.when(
        success: (outcome) => switch (outcome) {
          DepotCodeFound(:final depot) => CodeLookupFound(depot),
          DepotCodeAbsent() => CodeLookupAbsent(trimmed),
          DepotCodeUnavailable() => const CodeLookupUnavailable(),
        },
        failure: (failure) => CodeLookupFailed(failure.message),
      ),
    );
  }

  void reset() => emit(const CodeLookupIdle());
}

/// Whether [query] is worth spending a server round trip on.
///
/// A depot number, not a name fragment. SAP numbers are ten digits
/// (`6100000017`) and platform codes look like `BP-202608-00002` or
/// `ISI-PP0005`, so this asks for something code-shaped and long enough to be
/// unambiguous — a rep typing a shop name must never trigger a call that can
/// reach the ERP.
bool looksLikeDepotCode(String query) {
  final trimmed = query.trim();
  if (trimmed.length < 6) return false;
  return RegExp(r'^[A-Za-z0-9][A-Za-z0-9\-_/]*$').hasMatch(trimmed) &&
      RegExp(r'\d').hasMatch(trimmed);
}
