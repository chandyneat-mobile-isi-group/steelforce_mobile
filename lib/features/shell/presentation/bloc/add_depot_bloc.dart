import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/depots/domain/entities/depot_draft.dart';
import 'package:steelforce/features/depots/domain/usecases/create_depot.dart';

part 'add_depot_event.dart';
part 'add_depot_state.dart';

/// Registers a new shop against `POST /api/v1/mobile/depots`.
///
/// This used to be a three-step form that ended in a two-second delay and a
/// success screen — nothing was ever sent. It also required the rep to pick a
/// *won lead* first, so a shop that had never been in the pipeline could not be
/// added at all. Both are gone: the form submits directly.
///
/// The created depot lands in `Draft` and cannot trade until someone
/// holding `depots.approve` activates it, so success here means "registered
/// and awaiting approval", not "ready to sell to".
class AddDepotBloc extends Bloc<AddDepotEvent, AddDepotState> {
  AddDepotBloc({required CreateDepot createDepot})
      : _createDepot = createDepot,
        super(AddDepotState()) {
    on<UpdateShopDetails>((event, emit) {
      emit(state.copyWith(
        depotCode: event.depotCode,
        shopName: event.shopName,
        shopType: event.shopType,
        ownerName: event.ownerName,
        addressLine1: event.addressLine1,
        city: event.city,
      ));
    });

    on<UpdateContactDetails>((event, emit) {
      emit(state.copyWith(
        contactName: event.name,
        contactRole: event.role,
        contactPhone: event.phone,
      ));
    });

    on<UpdateLocationAndPapers>((event, emit) {
      emit(state.copyWith(
        gpsLocation: event.gpsLocation,
        latitude: () => event.latitude,
        longitude: () => event.longitude,
        businessLicencePath: event.businessLicencePath,
        taxPaperPath: event.taxPaperPath,
      ));
    });

    on<NextStep>((event, emit) {
      if (state.currentStep == DepotFormStep.shopDetails) {
        emit(state.copyWith(currentStep: DepotFormStep.contactPerson));
      } else if (state.currentStep == DepotFormStep.contactPerson) {
        emit(state.copyWith(currentStep: DepotFormStep.locationAndPapers));
      }
    });

    on<PreviousStep>((event, emit) {
      if (state.currentStep == DepotFormStep.locationAndPapers) {
        emit(state.copyWith(currentStep: DepotFormStep.contactPerson));
      } else if (state.currentStep == DepotFormStep.contactPerson) {
        emit(state.copyWith(currentStep: DepotFormStep.shopDetails));
      }
    });

    on<SubmitToHQ>((event, emit) async {
      emit(state.copyWith(
        status: AddDepotStatus.submitting,
        errorMessage: () => null,
      ));

      final result = await _createDepot(state.toDraft());

      result.when(
        success: (_) => emit(state.copyWith(status: AddDepotStatus.success)),
        // The message is server-supplied and already localised against the
        // `Accept-Language` header, so it is safe to show. A duplicate code
        // (`Depot.DuplicateCode`) and a failed GPS fix
        // (`Depot.CoordinatesMissing`) both arrive here with copy written
        // for the user.
        failure: (f) => emit(state.copyWith(
          status: AddDepotStatus.failure,
          errorMessage: () => f.message,
        )),
      );
    });
  }

  final CreateDepot _createDepot;
}
