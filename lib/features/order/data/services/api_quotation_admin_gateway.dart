import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/order/data/remote/quotation_remote_data_source.dart';
import 'package:steelforce/features/order/domain/entities/admin_submit_result.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/product_material_number.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/domain/entities/quotation_review.dart';
import 'package:steelforce/features/order/domain/services/quotation_admin_gateway.dart';

/// Error codes the device raises itself, before or instead of a backend call.
/// Same `Area.Reason` shape as the contract's codes so the UI localizes both
/// from one table.
abstract final class QuotationSyncErrorCodes {
  /// A lead-only quotation: the backend opens a document against a depot, and
  /// a lead is not one until it is converted.
  static const depotRequired = 'Quotation.DepotRequired';

  /// A line whose product carries no SAP material number.
  static const materialMissing = 'Quotation.MaterialMissing';

  /// A customized (made-to-order) line. The quotation contract has no field
  /// for measurements, drawings or appearance, so sending it as a plain
  /// material would silently drop what the depot actually asked for.
  static const customizationUnsupported = 'Quotation.CustomizationUnsupported';

  /// The backend document has left the rep's hands without being submitted
  /// from here — rejected or cancelled in the portal.
  static const closed = 'Quotation.Closed';
}

/// [QuotationAdminGateway] over the mobile quotations API
/// (`docs/feature/quotation-orders/api/mobile.md`).
///
/// ## The push, step by step
///
/// 1. **Find or open the document.** Reuse the linked backend id; otherwise
///    `POST /` and hand the new id to `onRemoteCreated` before anything else,
///    so an interrupted push resumes on the same document.
/// 2. **Reconcile lines** by material number — add, change quantity, remove —
///    so a retry after a half-finished push converges instead of duplicating
///    (`422 DuplicateLine`).
/// 3. **Reconcile manual discounts**, sending the complete set only when it
///    differs (the contract replaces the whole set on every `PUT`).
/// 4. **Submit.** `409 PriceChanged` is *not* auto-accepted: the contract
///    requires the rep to see the new prices first, so it comes back as
///    [AdminNeedsReview] and the rep resolves it on the document screen.
///
/// Every write is intent only — materials, quantities, percentages. Prices and
/// totals come from the backend (contract rule 2).
class ApiQuotationAdminGateway implements QuotationAdminGateway {
  const ApiQuotationAdminGateway(this._remote);

  final QuotationRemoteDataSource _remote;

  /// The list endpoint clamps `pageSize` to 100. Five pages is far beyond one
  /// rep's documents in review; the cap only stops a runaway loop.
  static const _pageSize = 100;
  static const _maxPages = 5;
  static const _discountTolerance = 0.0001;

  @override
  Future<AdminSubmitResult> submit(
    Quotation quotation, {
    required String? remoteId,
    required Future<void> Function(String remoteId) onRemoteCreated,
  }) async {
    final wanted = _wantedLines(quotation.lines);
    if (wanted case _LocalRefusal(:final code)) {
      return AdminRejected(errorCode: code, message: code, remoteId: remoteId);
    }
    final lines = (wanted as _WantedLines).byMaterial;

    String? id = remoteId;
    try {
      var doc = id == null ? null : await _fetchOrNull(id);
      if (doc == null) {
        final depotId = quotation.depotId;
        if (depotId == null || depotId.isEmpty) {
          return const AdminRejected(
            errorCode: QuotationSyncErrorCodes.depotRequired,
            message: 'A lead quotation needs a depot before review.',
          );
        }
        // The local id rides along as `clientId`: a create whose answer was
        // lost returns the same quotation on retry, and a visit check-out
        // that named this quotation links to it.
        doc = await _remote.createQuotation(
            depotId: depotId, clientId: quotation.id);
        id = doc.id;
        await onRemoteCreated(id);
      }

      if (!QuotationRemoteStatus.isEditable(doc.status)) {
        // Already past the rep: a previous attempt submitted it and its
        // response was lost, or the rep submitted it online. Either way the
        // work is done — report where it stands rather than fail.
        if (QuotationRemoteStatus.waiting.contains(doc.status)) {
          return AdminSubmitted(
            remoteId: doc.id,
            number: doc.number,
            remoteStatus: doc.status,
          );
        }
        return AdminRejected(
          errorCode: QuotationSyncErrorCodes.closed,
          message: 'Backend document is ${doc.status}.',
          remoteId: doc.id,
        );
      }

      doc = await _reconcileLines(doc, lines);
      doc = await _reconcileDiscounts(doc, lines);
      final submitted = await _remote.submit(doc.id);
      return AdminSubmitted(
        remoteId: submitted.id,
        number: submitted.number,
        remoteStatus: submitted.status,
      );
    } on ApiException catch (e) {
      return _classify(e, remoteId: id);
    } catch (e) {
      // A parse failure or similar: nothing the rep can fix, so retry under
      // backoff. The type only — the message may echo payload data.
      return AdminTransportFailure(message: e.runtimeType.toString());
    }
  }

  @override
  Future<List<QuotationReview>> fetchReviews(List<String> remoteIds) async {
    if (remoteIds.isEmpty) return const [];

    // One list call answers every document still in review. Only the ones that
    // have left review — returned, rejected, gone — cost a detail call, which
    // is also the only way to read `decisionReason`.
    final waiting = <String, QuotationSummary>{};
    for (var page = 1; page <= _maxPages; page++) {
      final result = await _remote.fetchQuotations(
        status: 'Waiting',
        page: page,
        pageSize: _pageSize,
      );
      for (final row in result.quotations) {
        waiting[row.id] = row;
      }
      if (!(result.metadata?.hasNextPage ?? false)) break;
    }

    final reviews = <QuotationReview>[];
    for (final id in remoteIds) {
      final row = waiting[id];
      if (row != null) {
        reviews.add(QuotationReview(
          remoteId: id,
          status: row.status,
          number: row.number,
        ));
        continue;
      }
      final doc = await _fetchOrNull(id);
      reviews.add(doc == null
          ? QuotationReview(remoteId: id, status: null)
          : QuotationReview(
              remoteId: id,
              status: doc.status,
              number: doc.number,
              decisionReason: doc.decisionReason,
            ));
    }
    return reviews;
  }

  @override
  Future<List<QuotationSummary>> fetchEditableDrafts() async {
    final result = await _remote.fetchQuotations(
      status: 'Drafts',
      page: 1,
      pageSize: 50,
    );
    return result.quotations;
  }

  // ── Steps ──────────────────────────────────────────────────────────────

  /// `null` for a document the backend no longer has (or no longer shows this
  /// rep — the contract answers both with `404`).
  Future<QuotationDetail?> _fetchOrNull(String id) async {
    try {
      return await _remote.fetchQuotationById(id);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<QuotationDetail> _reconcileLines(
    QuotationDetail doc,
    Map<String, _Line> wanted,
  ) async {
    var current = doc;
    final onServer = {for (final l in doc.lines) l.materialNumber: l};

    for (final line in doc.lines) {
      if (!wanted.containsKey(line.materialNumber)) {
        current = await _remote.deleteLine(doc.id, line.id);
      }
    }
    for (final entry in wanted.entries) {
      final existing = onServer[entry.key];
      if (existing == null) {
        current = await _remote.addLine(
          doc.id,
          materialNumber: entry.key,
          quantity: entry.value.quantity,
          unit: entry.value.unit,
        );
      } else if (existing.quantity != entry.value.quantity) {
        current = await _remote.updateLine(
          doc.id,
          existing.id,
          quantity: entry.value.quantity,
        );
      }
    }
    return current;
  }

  Future<QuotationDetail> _reconcileDiscounts(
    QuotationDetail doc,
    Map<String, _Line> wanted,
  ) async {
    final intents = <QuotationDiscountIntent>[];
    var differs = false;
    for (final line in doc.lines) {
      final want = wanted[line.materialNumber]?.discountPercent ?? 0;
      final have = line.discounts
          .where((d) => d.kind == QuotationDiscountKind.manual && d.editable)
          .fold<double>(0, (sum, d) => sum + d.percent);
      if ((want - have).abs() > _discountTolerance) differs = true;
      if (want > 0) {
        intents.add(QuotationDiscountIntent(lineId: line.id, percent: want));
      }
    }
    if (!differs) return doc;
    return _remote.setDiscounts(doc.id, lines: intents);
  }

  // ── Mapping ────────────────────────────────────────────────────────────

  /// The lines to send, keyed by material number. The cart can hold the same
  /// material twice (two separately-added rows); the backend refuses a
  /// duplicate line, so they are merged — quantities summed, the first row's
  /// unit and discount kept.
  static _Wanted _wantedLines(List<CartItem> items) {
    final byMaterial = <String, _Line>{};
    for (final item in items) {
      if (item.isCustomized) {
        return const _LocalRefusal(
            QuotationSyncErrorCodes.customizationUnsupported);
      }
      final material = item.product.materialNumber;
      if (material.isEmpty) {
        return const _LocalRefusal(QuotationSyncErrorCodes.materialMissing);
      }
      final prior = byMaterial[material];
      byMaterial[material] = prior == null
          ? _Line(item.quantity, item.unit, item.discountPercent)
          : _Line(prior.quantity + item.quantity, prior.unit,
              prior.discountPercent);
    }
    if (byMaterial.isEmpty) return const _LocalRefusal('Quotation.NoLines');
    return _WantedLines(byMaterial);
  }

  static AdminSubmitResult _classify(ApiException e, {String? remoteId}) {
    final code = e.code;
    final status = e.statusCode;
    final message = e.error.detail ?? e.error.message ?? code;

    final transport = code == ApiErrorCodes.network ||
        status == null ||
        status == 401 ||
        status == 408 ||
        status == 429 ||
        status >= 500;
    if (transport) {
      return AdminTransportFailure(message: message, errorCode: code);
    }
    if (code == 'Quotation.PriceChanged' && remoteId != null) {
      return AdminNeedsReview(
          errorCode: code, message: message, remoteId: remoteId);
    }
    return AdminRejected(errorCode: code, message: message, remoteId: remoteId);
  }
}

class _Line {
  const _Line(this.quantity, this.unit, this.discountPercent);
  final double quantity;
  final String unit;
  final double discountPercent;
}

sealed class _Wanted {
  const _Wanted();
}

final class _WantedLines extends _Wanted {
  const _WantedLines(this.byMaterial);
  final Map<String, _Line> byMaterial;
}

final class _LocalRefusal extends _Wanted {
  const _LocalRefusal(this.code);
  final String code;
}
