part of 'add_depot_bloc.dart';

enum DepotFormStep { shopDetails, contactPerson, locationAndPapers }

enum AddDepotStatus { initial, filling, submitting, success, failure }

class AddDepotState {
  AddDepotState({
    this.currentStep = DepotFormStep.shopDetails,
    this.status = AddDepotStatus.initial,
    this.depotCode = '',
    this.shopName = '',
    this.shopType = '',
    this.ownerName = '',
    this.addressLine1 = '',
    this.city = '',
    this.contactName = '',
    this.contactRole = '',
    this.contactPhone = '',
    this.gpsLocation = '',
    this.latitude,
    this.longitude,
    this.businessLicencePath = '',
    this.taxPaperPath = '',
    this.errorMessage,
  });

  final DepotFormStep currentStep;
  final AddDepotStatus status;

  final String depotCode;
  final String shopName;
  final String shopType;
  final String ownerName;
  final String addressLine1;
  final String city;

  final String contactName;
  final String contactRole;
  final String contactPhone;

  final String gpsLocation;

  /// Null when no fix was captured. Sent as a pair or not at all.
  final double? latitude;
  final double? longitude;

  final String businessLicencePath;
  final String taxPaperPath;

  /// Server-supplied and already localised, so it can go straight to the user.
  final String? errorMessage;

  /// The create payload.
  ///
  /// Compliance documents ([businessLicencePath], [taxPaperPath]) are **not**
  /// included: `POST /mobile/depots` takes no file fields, and there is no
  /// documented upload endpoint to attach them to. They stay captured in the
  /// form so nothing the rep did is lost, but pretending they were transmitted
  /// would be worse than plainly not sending them.
  DepotDraft toDraft() => DepotDraft(
        depotCode: depotCode.trim(),
        shopName: shopName.trim(),
        type: shopType,
        phone: contactPhone.trim(),
        addressLine1: addressLine1.trim(),
        city: city.trim(),
        ownerName: ownerName.trim().isEmpty ? null : ownerName.trim(),
        // Both or neither — `DepotDraft.toJson` omits the pair unless a real
        // fix was captured.
        latitude: latitude,
        longitude: longitude,
        contacts: [
          if (contactName.trim().isNotEmpty)
            DepotContactDraft(
              name: contactName.trim(),
              phone: contactPhone.trim(),
              position: contactRole.isEmpty ? null : contactRole,
              // The only contact captured, so it is the primary one.
              isPrimary: true,
            ),
        ],
      );

  AddDepotState copyWith({
    DepotFormStep? currentStep,
    AddDepotStatus? status,
    String? depotCode,
    String? shopName,
    String? shopType,
    String? ownerName,
    String? addressLine1,
    String? city,
    String? contactName,
    String? contactRole,
    String? contactPhone,
    String? gpsLocation,
    // Wrapped so clearing a failed fix back to null is expressible — a plain
    // `double?` cannot distinguish "unchanged" from "set to null".
    double? Function()? latitude,
    double? Function()? longitude,
    String? businessLicencePath,
    String? taxPaperPath,
    String? Function()? errorMessage,
  }) {
    return AddDepotState(
      currentStep: currentStep ?? this.currentStep,
      status: status ?? this.status,
      depotCode: depotCode ?? this.depotCode,
      shopName: shopName ?? this.shopName,
      shopType: shopType ?? this.shopType,
      ownerName: ownerName ?? this.ownerName,
      addressLine1: addressLine1 ?? this.addressLine1,
      city: city ?? this.city,
      contactName: contactName ?? this.contactName,
      contactRole: contactRole ?? this.contactRole,
      contactPhone: contactPhone ?? this.contactPhone,
      gpsLocation: gpsLocation ?? this.gpsLocation,
      latitude: latitude == null ? this.latitude : latitude(),
      longitude: longitude == null ? this.longitude : longitude(),
      businessLicencePath: businessLicencePath ?? this.businessLicencePath,
      taxPaperPath: taxPaperPath ?? this.taxPaperPath,
      errorMessage: errorMessage == null ? this.errorMessage : errorMessage(),
    );
  }
}
