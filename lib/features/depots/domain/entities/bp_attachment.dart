import 'package:steelforce/features/depots/domain/entities/depot_document.dart';

/// One captured document / photo, held on the device until the depot exists.
///
/// Evidence cannot be uploaded during the wizard: the documents endpoint is
/// addressed by depot id, and the depot is not created until submit. So
/// the rep photographs the shop while standing in it, and the files go up once
/// the registration has returned an id
/// (`docs/feature/depot/mobile/depot-documents.md` §Flow).
class BpAttachment {
  final String
      kind; // outlet_front | outlet_inside | id_card | patent_tax | vat_cert
  final String localPath;
  final String? remoteUrl;
  final bool isUploaded;
  final bool isUploading;
  final String? uploadError;

  /// When the photograph was taken.
  ///
  /// Stamped here rather than at upload because the upload happens after
  /// submit and may be minutes or hours later; dating the evidence to when the
  /// connection came back would misrepresent the visit.
  final DateTime capturedAt;

  BpAttachment({
    required this.kind,
    required this.localPath,
    this.remoteUrl,
    this.isUploaded = false,
    this.isUploading = false,
    this.uploadError,
    DateTime? capturedAt,
  }) : capturedAt = capturedAt ?? DateTime.now().toUtc();

  BpAttachment copyWith({
    String? kind,
    String? localPath,
    String? remoteUrl,
    bool? isUploaded,
    bool? isUploading,
    String? uploadError,
    DateTime? capturedAt,
  }) =>
      BpAttachment(
        kind: kind ?? this.kind,
        localPath: localPath ?? this.localPath,
        remoteUrl: remoteUrl ?? this.remoteUrl,
        isUploaded: isUploaded ?? this.isUploaded,
        isUploading: isUploading ?? this.isUploading,
        uploadError: uploadError,
        capturedAt: capturedAt ?? this.capturedAt,
      );

  /// The form's local slot names, paired with the API's codes.
  ///
  /// The two vocabularies are kept apart on purpose: the tile keys are UI
  /// identifiers with their own history (`outlet_front`), and the codes are the
  /// wire contract. Renaming either without the other would silently drop a
  /// photograph, so the pairing lives in exactly one place.
  static const Map<String, DepotDocumentType> kindToDocumentType = {
    'outlet_front': DepotDocumentType.storefront,
    'outlet_inside': DepotDocumentType.insideStore,
    'id_card': DepotDocumentType.idCard,
    'patent_tax': DepotDocumentType.patentTax,
    'vat_cert': DepotDocumentType.vatCertificate,
  };

  /// The API slot this attachment belongs in, or null for an unrecognised kind.
  DepotDocumentType? get documentType => kindToDocumentType[kind];

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'local_path': localPath,
        if (remoteUrl != null) 'url': remoteUrl,
        'is_uploaded': isUploaded,
      };
}
