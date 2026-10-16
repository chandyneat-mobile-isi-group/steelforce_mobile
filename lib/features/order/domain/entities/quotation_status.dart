/// `draft` is transient (mid-edit, cart not yet saved) and never persisted;
/// `saved` is a persisted, editable quotation; `converted` means a
/// [SalesOrder] has been created from it.
enum QuotationStatus { draft, saved, converted }
