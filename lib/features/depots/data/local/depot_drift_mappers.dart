import 'package:steelforce/core/utils/enum_parse.dart';
import 'package:drift/drift.dart' show Value;
import 'package:steelforce/core/database/drift/app_database.dart' as db;
import 'package:steelforce/core/database/drift/daos/depot_dao.dart';
import 'package:steelforce/features/depots/data/models/depot_activity_model.dart';
import 'package:steelforce/features/depots/data/models/depot_contact_model.dart';
import 'package:steelforce/features/depots/data/models/depot_model.dart';
import 'package:steelforce/features/depots/data/models/depot_note_model.dart';
import 'package:steelforce/features/depots/domain/entities/depot_activity_type.dart';
import 'package:steelforce/features/depots/domain/entities/depot_filter.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';

/// Bidirectional mapping between the encrypted Drift rows/companions and the
/// depot feature's models. Isolated here so the data source stays thin and
/// the `productsPurchased` list⇄`'|'`-joined-text convention lives in one place.
///
/// The Drift generated types are prefixed `db.` to avoid colliding with the
/// domain entities the models extend.

const _kProductsSeparator = '|';

extension DepotRowMapper on db.Depot {
  DepotModel toModel({List<DepotContactModel> contacts = const []}) {
    return DepotModel(
      id: id,
      sapDepotId: sapDepotId,
      depotCode: depotCode,
      shopName: shopName,
      ownerName: ownerName,
      phone: phone,
      email: email,
      whatsapp: whatsapp,
      address: address,
      province: province,
      district: district,
      territory: territory,
      latitude: latitude,
      longitude: longitude,
      creditLimit: creditLimit,
      status: DepotStatus.values
          .byNameOr(status, DepotStatus.draft, context: 'depots.status'),
      assignedRepId: assignedRepId,
      assignedRepName: assignedRepName,
      updatedAt: updatedAt,
      originLeadId: originLeadId,
      productsPurchased: productsPurchased
          .split(_kProductsSeparator)
          .where((e) => e.isNotEmpty)
          .toList(),
      contacts: contacts,
      lastOrderDate: lastOrderDate,
      lastVisitDate: lastVisitDate,
      lifetimeValue: lifetimeValue,
      openOpportunityCount: openOpportunityCount,
      salesOrg: salesOrg,
      division: division,
      distributionChannel: distributionChannel,
      depotGroup: depotGroup,
      priceGroup: priceGroup,
      enName: enName,
      khName: khName,
      taxNumber: taxNumber,
      creditBalance: creditBalance,
      currency: currency,
      totalOrders: totalOrders,
      createdAt: createdAt,
      deleted: deleted,
    );
  }
}

extension DepotModelMapper on DepotModel {
  db.DepotsCompanion toCompanion() {
    return db.DepotsCompanion.insert(
      id: id,
      sapDepotId: Value(sapDepotId),
      depotCode: depotCode,
      shopName: shopName,
      ownerName: ownerName,
      phone: phone,
      email: Value(email),
      whatsapp: Value(whatsapp),
      address: address,
      province: province,
      district: district,
      territory: territory,
      latitude: latitude,
      longitude: longitude,
      creditLimit: creditLimit,
      status: status.name,
      assignedRepId: assignedRepId,
      assignedRepName: assignedRepName,
      updatedAt: updatedAt,
      originLeadId: Value(originLeadId),
      productsPurchased: Value(productsPurchased.join(_kProductsSeparator)),
      lastOrderDate: Value(lastOrderDate),
      lastVisitDate: Value(lastVisitDate),
      lifetimeValue: Value(lifetimeValue),
      openOpportunityCount: Value(openOpportunityCount),
      salesOrg: Value(salesOrg),
      division: Value(division),
      distributionChannel: Value(distributionChannel),
      depotGroup: Value(depotGroup),
      priceGroup: Value(priceGroup),
      enName: Value(enName),
      khName: Value(khName),
      taxNumber: Value(taxNumber),
      creditBalance: Value(creditBalance),
      currency: Value(currency),
      totalOrders: Value(totalOrders),
      createdAt: Value(createdAt),
      deleted: Value(deleted),
    );
  }

  DepotWithContacts toRecord() {
    final contactCompanions = contacts
        .map((c) => db.DepotContactsCompanion.insert(
              id: c.id,
              depotId: id,
              name: c.name,
              role: c.role,
              phone: c.phone,
              email: Value(c.email),
            ))
        .toList();
    return DepotWithContacts(toCompanion(), contactCompanions);
  }
}

extension DepotContactRowMapper on db.DepotContact {
  DepotContactModel toModel() => DepotContactModel(
        id: id,
        name: name,
        role: role,
        phone: phone,
        email: email,
      );
}

extension DepotNoteRowMapper on db.DepotNote {
  DepotNoteModel toModel() => DepotNoteModel(
        id: id,
        depotId: depotId,
        body: body,
        createdAt: createdAt,
        synced: synced,
      );
}

extension DepotNoteModelMapper on DepotNoteModel {
  db.DepotNotesCompanion toCompanion() => db.DepotNotesCompanion.insert(
        id: id,
        depotId: depotId,
        body: body,
        createdAt: createdAt,
        synced: Value(synced),
      );
}

extension DepotActivityRowMapper on db.DepotActivity {
  DepotActivityModel toModel() => DepotActivityModel(
        id: id,
        depotId: depotId,
        type: DepotActivityType.fromValue(type),
        summary: summary,
        createdAt: createdAt,
        synced: synced,
      );
}

extension DepotActivityModelMapper on DepotActivityModel {
  db.DepotActivitiesCompanion toCompanion() =>
      db.DepotActivitiesCompanion.insert(
        id: id,
        depotId: depotId,
        type: type.value,
        summary: summary,
        createdAt: createdAt,
        synced: Value(synced),
      );
}

/// Maps the feature's sort enum onto the DAO's decoupled equivalent.
extension DepotSortMapper on DepotSortBy {
  DepotBrowseSort toBrowseSort() => switch (this) {
        DepotSortBy.recentOrder => DepotBrowseSort.recentOrder,
        DepotSortBy.nameAsc => DepotBrowseSort.nameAsc,
        DepotSortBy.nearest => DepotBrowseSort.nearest,
        DepotSortBy.valueDesc => DepotBrowseSort.valueDesc,
      };
}
