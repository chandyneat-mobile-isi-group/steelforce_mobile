import 'package:equatable/equatable.dart';
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/core/utils/money.dart';

/// The outlet profile a visit's stop screen shows, fetched on demand.
///
/// ## Not to be confused with `DepotStopInfo`
///
/// `my_visits`' [DepotStopInfo] is what the **route sync** puts on every stop:
/// a name, a pin and a geofence radius — enough to render a stop card. This is
/// what `GET /mobile/depots/{id}/stop-information` returns when a rep actually
/// opens one, and the two have **different contracts for the same-looking
/// fields**:
///
/// | | route sync | this |
/// |---|---|---|
/// | absent Khmer name | `''` | `null` |
/// | absent contact | `''` | `null` |
///
/// The backend notice is explicit that they must not share a parser. Treating
/// `''` and `null` as the same thing is what turns "nobody was recorded" into
/// a blank line the rep reads as a rendering bug.
class DepotStopInformation extends Equatable {
  const DepotStopInformation({
    required this.outlet,
    required this.credit,
  });

  final DepotOutletProfile outlet;
  final DepotCreditProfile credit;

  @override
  List<Object?> get props => [outlet, credit];
}

/// Who the outlet is. `data.customer` on the wire — SAP's word, kept
/// deliberately (see ADR-0007); the route is the business word.
class DepotOutletProfile extends Equatable {
  const DepotOutletProfile({
    required this.id,
    required this.code,
    required this.name,
    required this.phone,
    required this.address,
    required this.outletType,
    this.nameKh,
    this.contact,
    this.telegram,
  });

  final String id;

  /// The SAP outlet number. A locally registered outlet carries a `BP-…`
  /// placeholder until SAP names it, so this is never empty but is not always
  /// a SAP number.
  final String code;

  final String name;

  /// Null when SAP holds no Khmer name — **not** `''`. See the class doc.
  final String? nameKh;

  /// Null when nobody was recorded against the outlet.
  ///
  /// Callers must render "not recorded" rather than a placeholder name: a rep
  /// who reads an invented contact and asks for that person at the counter is
  /// worse off than one shown nothing.
  final String? contact;

  final String phone;
  final String address;

  /// **Stored without a leading `@`.** Use [telegramHandle] to display it.
  final String? telegram;

  /// `Retailer` · `Wholesaler` · `Distributor` · `KeyAccount`.
  ///
  /// Deliberately **not** derived from the route sync's `territoryType`, which
  /// collapses `Distributor` and `Wholesaler` both onto `industrial` — the
  /// original value cannot be recovered from it.
  final String outletType;

  /// Both languages, for rendering. Mirrors `DepotStopInfo.displayName`, but
  /// tolerates the null Khmer name this contract uses.
  LocalizedText get displayName => LocalizedText(en: name, km: nameKh ?? '');

  /// The handle as a person writes it. Null stays null — an `@` on its own is
  /// not a Telegram account.
  String? get telegramHandle {
    final raw = telegram?.trim();
    if (raw == null || raw.isEmpty) return null;
    // Tolerates a server that ever starts sending the prefix, rather than
    // rendering `@@outlet`.
    return raw.startsWith('@') ? raw : '@$raw';
  }

  @override
  List<Object?> get props =>
      [id, code, name, nameKh, contact, phone, address, telegram, outletType];
}

/// The outlet's credit position, as SAP holds it.
class DepotCreditProfile extends Equatable {
  const DepotCreditProfile({
    required this.creditLimit,
    required this.creditBalance,
    required this.availableCredit,
    required this.currency,
    this.creditLimitDate,
    this.paymentTermCode,
    this.paymentTermLabel,
    this.paymentTermDays,
  });

  /// **Zero is a real answer** — it means cash-only trade, not "unknown".
  /// Never re-default it to a placeholder.
  final Money creditLimit;

  final Money creditBalance;

  /// Limit − balance, **computed server-side**.
  ///
  /// Not recomputed here on purpose: a client that does its own subtraction can
  /// disagree with the server about an outlet's headroom, and the rep is the
  /// one standing in front of the owner when it does.
  final Money availableCredit;

  final String currency;

  /// When **SAP** last set the limit — read it as the age of the figure, not
  /// as an event in the app.
  final DateTime? creditLimitDate;

  /// SAP's payment term key, e.g. `T030`.
  final String? paymentTermCode;

  /// The catalogue's label for [paymentTermCode].
  ///
  /// Null means the catalogue has no entry — the server will not echo the code
  /// back as a label, so null genuinely means unresolved. Use
  /// [paymentTermDisplay], which falls back to the code.
  final String? paymentTermLabel;

  /// SAP's net days. Distinct from the platform's own `creditTermDays`.
  final int? paymentTermDays;

  /// What to show for the payment term: the label, else the raw code, else
  /// nothing.
  String? get paymentTermDisplay {
    final label = paymentTermLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    final code = paymentTermCode?.trim();
    return (code != null && code.isNotEmpty) ? code : null;
  }

  @override
  List<Object?> get props => [
        creditLimit,
        creditBalance,
        availableCredit,
        currency,
        creditLimitDate,
        paymentTermCode,
        paymentTermLabel,
        paymentTermDays,
      ];
}
