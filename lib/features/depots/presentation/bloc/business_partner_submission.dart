// =============================================================================
// business_partner_submission.dart
//
// The submit step of the Add Depot wizard, in one place.
//
// `AddDepotBloc` delegates here rather than mapping the draft itself. The
// mapping has real decisions in it — which sales area wins, what happens when
// the gazetteer has no name for a district, how a SAP return row becomes a
// per-field error — and those are worth testing without building a bloc.
//
// It also gives the two callers one behaviour. The wizard's last step and the
// offline queue both submit the same draft, and when the mapping lived in the
// bloc the queue replayed it with slightly different defaults.
// =============================================================================

import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/features/depots/data/mappers/bp_draft_to_business_partner.dart';
import 'package:steelforce/features/depots/domain/entities/bp_depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/bp_form_step.dart';
import 'package:steelforce/features/depots/domain/entities/rep_sales_context.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_request.dart';
import 'package:steelforce/features/depots/domain/entities/business_partner_result.dart';
import 'package:steelforce/features/depots/domain/entities/pending_depot_registration.dart';
import 'package:steelforce/features/depots/domain/usecases/create_business_partner.dart';

/// What came of a submit. Sealed so the bloc's handler cannot forget a case.
sealed class BpSubmissionOutcome {
  const BpSubmissionOutcome();
}

/// The server took the registration.
///
/// Named "created" for the caller's purposes, but it covers both outcomes the
/// endpoint reports as success: a partner SAP has numbered, and a record stored
/// and awaiting HQ approval. Read [isPendingApproval] to tell them apart —
/// [depotNumber] is empty in the pending case and that is not an error.
class BpSubmissionCreated extends BpSubmissionOutcome {
  const BpSubmissionCreated(this.result);
  final BusinessPartnerResult result;

  /// The SAP number, or empty while approval is pending.
  String get depotNumber => result.depotNumber;

  /// The id evidence is filed against. Prefers the platform's `depotId`,
  /// which exists even before SAP assigns a number.
  String get documentId => result.documentId;

  bool get isPendingApproval => result.isPendingApproval;
}

/// The call reached SAP and SAP said no, or the app refused to send.
///
/// [fieldErrors] maps SAP field names to messages when SAP named a field, and
/// [step] is the wizard step that owns the first of them — so the rep is
/// returned to the screen with the problem rather than shown a banner on the
/// review step.
class BpSubmissionRejected extends BpSubmissionOutcome {
  const BpSubmissionRejected({
    required this.message,
    this.fieldErrors = const {},
    this.step,
  });

  final String message;
  final Map<String, String> fieldErrors;
  final BpFormStep? step;
}

/// The network was the problem, so nothing is known about SAP's state.
///
/// Kept apart from [BpSubmissionRejected] because the two need opposite
/// advice: a rejection means change something and resend, a transport failure
/// means the record should be queued and the rep must not resend by hand.
class BpSubmissionUnreachable extends BpSubmissionOutcome {
  const BpSubmissionUnreachable({
    required this.message,
    required this.request,
    required this.mayHaveLanded,
  });

  final String message;

  /// The exact payload, for the offline queue to store and replay.
  final BusinessPartnerRequest request;

  /// True when the request was sent but the answer never arrived — the write
  /// may have succeeded. The queue must not blind-retry these; they need a
  /// duplicate check first.
  final bool mayHaveLanded;
}

class BusinessPartnerSubmission {
  const BusinessPartnerSubmission({
    required CreateBusinessPartner createBusinessPartner,
    required ValidateBusinessPartner validateBusinessPartner,
  })  : _create = createBusinessPartner,
        _validate = validateBusinessPartner;

  final CreateBusinessPartner _create;
  final ValidateBusinessPartner _validate;

  /// Builds the payload without sending it. Exposed so the review step can
  /// show the rep exactly what will go to SAP, and so tests can assert on the
  /// mapping alone.
  BusinessPartnerRequest buildRequest(
    BpDepotDraft draft, {
    required RepSalesContext rep,
    String? Function(String?)? priceGroupResolver,
    String? depotNumber,
  }) =>
      draft.toBusinessPartnerRequest(
        rep: rep,
        priceGroupResolver: priceGroupResolver,
        depotNumber: depotNumber,
      );

  /// Asks SAP whether the form would be accepted, creating nothing.
  ///
  /// A [BpSubmissionCreated] here means "would be accepted" and carries no
  /// depot number — `Commit: false` rolls the unit of work back, so there
  /// is nothing to number. Callers must not treat it as a registration.
  Future<BpSubmissionOutcome> validate(
    BpDepotDraft draft, {
    required RepSalesContext rep,
    String? Function(String?)? priceGroupResolver,
    String? depotNumber,
  }) async {
    final request = buildRequest(
      draft,
      rep: rep,
      priceGroupResolver: priceGroupResolver,
      depotNumber: depotNumber,
    );
    final response = await _validate(request);
    return response.when(
      success: _created,
      failure: (f) => _classify(f, request),
    );
  }

  /// Submits.
  ///
  /// When [dryRunFirst] is set, the payload is sent once with `Commit: false`
  /// and only committed if SAP accepts it. That costs a round trip and buys
  /// the difference between a rep who fixes a payment term while still in the
  /// shop and one who learns about it from HQ the next day. Off by default so
  /// the caller decides whether the connection can afford it.
  Future<BpSubmissionOutcome> submit(
    BpDepotDraft draft, {
    required RepSalesContext rep,
    String? Function(String?)? priceGroupResolver,
    String? depotNumber,
    bool dryRunFirst = false,
  }) async {
    final request = buildRequest(
      draft,
      rep: rep,
      priceGroupResolver: priceGroupResolver,
      depotNumber: depotNumber,
    );

    if (dryRunFirst) {
      final dryRun = await _validate(request);
      final blocked = dryRun.when(
        success: _passedDryRun,
        failure: (f) => _classify(f, request),
      );
      if (blocked != null) return blocked;
    }

    final response = await _create(request);
    return response.when(
      success: _created,
      failure: (f) => _classify(f, request),
    );
  }

  /// Both branches of `when` must agree on a static type, and a tear-off of
  /// `BpSubmissionCreated.new` infers as the subclass — which makes the
  /// success branch and the failure branch disagree. Declaring the return
  /// type here fixes the inference without an explicit type argument or a
  /// cast.
  BpSubmissionOutcome _created(BusinessPartnerResult result) =>
      BpSubmissionCreated(result);

  /// A clean dry run means "carry on", not an outcome to report.
  BpSubmissionOutcome? _passedDryRun(BusinessPartnerResult _) => null;

  /// Splits a failure into "SAP said no" and "we never heard back".
  ///
  /// Switches on the sealed [Failure] type rather than on message text. The
  /// distinction decides whether a retry is safe, and a retry decision made by
  /// substring-matching an error string is one copy edit away from turning one
  /// shop into two partners.
  BpSubmissionOutcome _classify(
    Failure failure,
    BusinessPartnerRequest request,
  ) {
    switch (failure) {
      // Never left the handset. Safe to hold and resend unchanged.
      case NetworkFailure():
      case ServerUnreachableFailure():
        return BpSubmissionUnreachable(
          message: failure.message,
          request: request,
          mayHaveLanded: false,
        );

      case ServerFailure(:final statusCode):
        // The gateway refused it before SAP (502/503): nothing was committed,
        // so the offline queue may resend it automatically.
        if (isSafeToResendServerError(statusCode)) {
          return BpSubmissionUnreachable(
            message: failure.message,
            request: request,
            mayHaveLanded: false,
          );
        }
        // Any other 5xx may have landed: 504 is set by the data source for an
        // answer that never came (receive timeout, connection dropped after
        // sending), and a 500 can be raised after SAP wrote the partner. Queued
        // for the rep to check, never resent blind.
        if (statusCode != null && statusCode >= 500) {
          return BpSubmissionUnreachable(
            message: failure.message,
            request: request,
            mayHaveLanded: true,
          );
        }
        return BpSubmissionRejected(
          message: failure.message,
          step: _stepForMessage(failure.message.toLowerCase()),
        );

      // Cache and auth failures are not something the rep can fix on this
      // form. Surfaced as a rejection so the message is at least shown,
      // rather than silently queued as if the shop had been registered.
      //
      // `DepotStopInformationUnavailableFailure` and
      // `AdHocVisitRefusedFailure` cannot reach this path — one belongs to the
      // stop screen's read and the other to adding a visit, neither to a
      // submission — but this switch is deliberately exhaustive so that a new
      // failure type forces a decision rather than falling through a wildcard.
      // Handled with the others for that reason, not because they are expected.
      case CacheFailure():
      case AuthenticationFailure():
      case DepotStopInformationUnavailableFailure():
      case AdHocVisitRefusedFailure():
        return BpSubmissionRejected(message: failure.message);
    }
  }

  /// Best-effort routing of a SAP complaint back to the step that owns it.
  ///
  /// Keyword matching, which is crude, but the alternative is leaving the rep
  /// on the review step with a message about a field four screens back. When
  /// nothing matches, the step stays null and the bloc shows the banner.
  BpFormStep? _stepForMessage(String lower) {
    if (lower.contains('name') || lower.contains('search term')) {
      return BpFormStep.identity;
    }
    if (lower.contains('address') ||
        lower.contains('postal') ||
        lower.contains('city') ||
        lower.contains('district') ||
        lower.contains('region')) {
      return BpFormStep.address;
    }
    if (lower.contains('phone') || lower.contains('telephone')) {
      return BpFormStep.contact;
    }
    if (lower.contains('sales') ||
        lower.contains('division') ||
        lower.contains('distribution') ||
        lower.contains('payment term') ||
        lower.contains('price group') ||
        lower.contains('currency') ||
        lower.contains('tax') ||
        lower.contains('credit')) {
      return BpFormStep.salesTerms;
    }
    return null;
  }
}

/// Maps SAP field names to wizard steps, for [BusinessPartnerResult.fieldErrors].
///
/// Separate from the keyword matcher above because when SAP does name a field
/// the answer is exact, and guessing from prose is only the fallback.
BpFormStep? bpStepForSapField(String sapField) =>
    switch (sapField.trim().toUpperCase()) {
      'NAME1' ||
      'NAME2' ||
      'NAME3' ||
      'SORT1' ||
      'SORT2' ||
      'KTOKD' =>
        BpFormStep.identity,
      'STREET' ||
      'HOUSE_NUM1' ||
      'CITY1' ||
      'CITY2' ||
      'POST_CODE1' ||
      'COUNTRY' ||
      'REGION' =>
        BpFormStep.address,
      'TEL_NUMBER' || 'MOB_NUMBER' || 'LANGU' => BpFormStep.contact,
      'VKORG' ||
      'VTWEG' ||
      'SPART' ||
      'KDGRP' ||
      'VKBUR' ||
      'VKGRP' ||
      'KONDA' ||
      'ZTERM' ||
      'WAERS' ||
      'LPRIO' ||
      'VSBED' ||
      'TAXKD' ||
      'KKBER' =>
        BpFormStep.salesTerms,
      _ => null,
    };
