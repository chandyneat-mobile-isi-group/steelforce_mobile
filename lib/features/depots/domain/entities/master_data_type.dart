/// The nine SAP Depot Helper master-data lists.
///
/// These are the exact endpoints defined in `SapAPI_Technical_Document_v1_BP.docx`
/// §4.1. Note there is **no `division` member**: the document defines nine Helper
/// endpoints and Division is not one of them — it exists only as a query filter on
/// `Depot/GetDetail` / `Depot/GetPaging`. See ADR-009, finding 3.
///
/// Listing all nine here (rather than only the ones the filter currently uses)
/// is deliberate: depot create/update needs the same lists, and the cache
/// layer is generic over this enum.
enum MasterDataType {
  salesOrg(action: 'GetSalesOrg', cacheKey: 'sales_org'),
  distributionChannel(action: 'GetDisChannel', cacheKey: 'dis_channel'),
  salesOffice(action: 'GetSalesOffice', cacheKey: 'sales_office'),
  salesGroup(action: 'GetSalesGroup', cacheKey: 'sales_group'),
  depotGroup(action: 'GetCustGroup', cacheKey: 'cust_group'),
  salesEmployee(action: 'GetSalesEmployee', cacheKey: 'sales_employee'),
  paymentTerm(action: 'GetPaymentTerm', cacheKey: 'payment_term'),
  shippingCondition(action: 'GetShipping', cacheKey: 'shipping'),
  priceGroup(action: 'GetPriceGroup', cacheKey: 'price_group');

  const MasterDataType({required this.action, required this.cacheKey});

  /// The `{Action}` segment of `GET /api/CustHelper/{Action}/{conId}`.
  final String action;

  /// Stable suffix for the Hive cache key. Kept separate from [action] so
  /// renaming an endpoint cannot silently orphan cached data.
  final String cacheKey;
}
