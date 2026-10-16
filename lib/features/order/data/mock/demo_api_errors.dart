import 'package:steelforce/core/network/api/api_error.dart';

/// The problem documents the demo backend answers with.
///
/// TODO(release-gate): demo-only, selected only when `DataSourceMode.useMocks`.
///
/// Built as the same [ApiException] a real problem document maps to — stable
/// `errorCode` plus HTTP status — so the repositories' and the sync gateway's
/// real error branches run (`404` → gone, `409 PriceChanged` → rep review,
/// `422` → business refusal), not demo imitations of them. `detail` is
/// developer English, never shown to the rep: the UI localizes from the code.
abstract final class DemoApiErrors {
  static ApiException of(int status, String code, [String? detail]) =>
      ApiException(ApiError(code: code, statusCode: status, detail: detail));

  static ApiException quotationNotFound() =>
      of(404, 'Quotation.NotFound', 'No such quotation or depot.');

  static ApiException lineNotFound() =>
      of(404, 'Quotation.LineNotFound', 'No such line on this document.');

  static ApiException notEditable(String status) => of(409,
      'Quotation.NotEditable', 'The document is $status and not editable.');

  static ApiException invalidTransition(String status) =>
      of(409, 'Quotation.InvalidTransition', 'Not a legal move from $status.');

  static ApiException materialNotFound() =>
      of(404, 'Material.NotFound', 'No such material.');
}
