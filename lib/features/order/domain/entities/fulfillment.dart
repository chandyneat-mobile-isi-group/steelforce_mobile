/// How an order line reaches the outlet.
///
/// These four types were declared inside `sku_widget.dart` with a comment
/// asking to be replaced by real entities once they existed. They are that
/// replacement: the widget now renders them, the cart persists them, and the
/// quotation/sales-order line codec carries them to SAP. Nothing about the
/// shape changed, so the widget's rendering is untouched.
///
/// [PickupLocation] is deliberately *not* the same concept as a SKU's
/// `warehouseCode`. The warehouse is where the stock physically is (SAP master
/// data, on every product row); pickup location is what the depot agreed to
/// (a commercial term captured by the rep). The repository does not infer one
/// from the other, because SAP has published no plant→factory/branch mapping —
/// see the gaps section of the engineering report.
library;

import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:steelforce/core/utils/typedefs.dart';

enum ShipmentMethod { pickup, delivery }

enum PickupLocation { factory, branch }

enum DeliveryAddressOption { defaultAddress, newAddress }

/// The fulfillment terms captured for one order line.
///
/// Immutable and JSON-round-trippable so it survives the cart table, the
/// quotation `lines_json` blob and the sales-order conversion without any of
/// the three needing to know its internals.
class ShipmentSelection extends Equatable {
  const ShipmentSelection({
    required this.method,
    this.pickupLocation,
    this.deliveryAddressOption,
    this.newAddress,
    this.newPhone,
  });

  final ShipmentMethod method;
  final PickupLocation? pickupLocation;
  final DeliveryAddressOption? deliveryAddressOption;
  final String? newAddress;
  final String? newPhone;

  /// Whether the rep has answered everything this method needs. A delivery to
  /// a new address is only complete once both address *and* phone are present —
  /// a driver with one and not the other cannot complete the drop.
  bool get isComplete {
    if (method == ShipmentMethod.pickup) return pickupLocation != null;
    if (deliveryAddressOption == null) return false;
    if (deliveryAddressOption == DeliveryAddressOption.defaultAddress) {
      return true;
    }
    return (newAddress?.trim().isNotEmpty ?? false) &&
        (newPhone?.trim().isNotEmpty ?? false);
  }

  DataMap toJson() => {
        'method': method.name,
        if (pickupLocation != null) 'pickupLocation': pickupLocation!.name,
        if (deliveryAddressOption != null)
          'deliveryAddressOption': deliveryAddressOption!.name,
        if (newAddress != null && newAddress!.trim().isNotEmpty)
          'newAddress': newAddress,
        if (newPhone != null && newPhone!.trim().isNotEmpty)
          'newPhone': newPhone,
      };

  static ShipmentSelection? fromJson(DataMap? json) {
    if (json == null) return null;
    final method = _byName(ShipmentMethod.values, json['method'] as String?);
    if (method == null) return null;
    return ShipmentSelection(
      method: method,
      pickupLocation:
          _byName(PickupLocation.values, json['pickupLocation'] as String?),
      deliveryAddressOption: _byName(DeliveryAddressOption.values,
          json['deliveryAddressOption'] as String?),
      newAddress: json['newAddress'] as String?,
      newPhone: json['newPhone'] as String?,
    );
  }

  /// Encodes to the string stored in `cart_items.fulfillment_json`, or null for
  /// a line the rep never gave fulfillment terms for.
  static String? encode(ShipmentSelection? selection) =>
      selection == null ? null : jsonEncode(selection.toJson());

  /// Inverse of [encode]. A malformed blob decodes to null rather than
  /// throwing: a line whose fulfillment terms cannot be read is still a real
  /// order line the rep must be able to see and fix.
  static ShipmentSelection? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? ShipmentSelection.fromJson(decoded)
          : null;
    } on FormatException {
      return null;
    }
  }

  static T? _byName<T extends Enum>(List<T> values, String? name) {
    if (name == null) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  @override
  List<Object?> get props => [
        method,
        pickupLocation,
        deliveryAddressOption,
        newAddress,
        newPhone,
      ];
}
