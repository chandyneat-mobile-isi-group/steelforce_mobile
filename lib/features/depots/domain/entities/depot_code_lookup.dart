import 'package:steelforce/features/depots/domain/entities/portal_depot.dart';

/// The outcome of a by-code lookup.
///
/// ## Why this is a sealed type and not a nullable depot
///
/// "Not found" and "could not ask" must never be presented the same way, and a
/// `PortalDepot?` invites exactly that collapse:
///
///  * **404 — the code does not exist.** Safe to offer to register the shop.
///  * **502 — the ERP could not be reached.** The depot may well exist. If
///    the app offers a registration here it creates a **duplicate business
///    partner in SAP**, which is expensive to unpick and invisible until
///    somebody reconciles the ERP.
///
/// Making them separate variants means a caller cannot accidentally treat the
/// second as the first — the switch will not compile until both are handled.
/// See `docs/feature/depot/mobile/mobile.md` §Statuses.
sealed class DepotCodeLookup {
  const DepotCodeLookup();
}

/// Found — either locally or fetched from SAP on the server's side. Whatever
/// came back from SAP is stored server-side, so the next lookup is local.
final class DepotCodeFound extends DepotCodeLookup {
  const DepotCodeFound(this.depot);
  final PortalDepot depot;
}

/// Neither the platform nor SAP has this code (`Depot.NotFoundByCode`).
///
/// **This is the only outcome where offering to register the shop is safe.**
final class DepotCodeAbsent extends DepotCodeLookup {
  const DepotCodeAbsent();
}

/// The ERP could not be reached (502).
///
/// **Never offer to register from here.** Tell the rep it cannot be checked
/// right now and to try again later.
final class DepotCodeUnavailable extends DepotCodeLookup {
  const DepotCodeUnavailable();
}
