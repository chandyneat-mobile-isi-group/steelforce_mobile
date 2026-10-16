import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/utils/typedefs.dart';

/// The success envelope every business endpoint wraps its payload in:
///
/// ```json
/// { "success": true, "message": "…", "data": { … },
///   "metadata": { … }, "traceId": "…", "timestamp": "…" }
/// ```
///
/// **The OAuth token endpoints are the exception** — `/auth/login`,
/// `/auth/refresh` and `/auth/token` return the raw RFC 6749 token response
/// with no `data` wrapper. Do not run one deserialiser over both.
///
/// Note that [success] is *not* how failure is detected. Branch on the HTTP
/// status code: an error response is a problem document that has no `success`
/// field at all, so reading it would mean reading a null.
class ApiEnvelope {
  const ApiEnvelope({
    required this.data,
    this.message,
    this.metadata,
    this.traceId,
  });

  /// The payload. Its shape is endpoint-specific — the depot list nests a
  /// `depots` array under here, and the depot detail nests one level
  /// deeper again under `data.depot`.
  final DataMap data;

  /// Server-localised and safe to show.
  final String? message;

  final ApiMetadata? metadata;
  final String? traceId;

  factory ApiEnvelope.fromBody(Object? body) {
    if (body is! Map) {
      throw const ServerException(
          message: 'The server returned an unexpected response.');
    }
    final map = body.cast<String, dynamic>();
    final data = map['data'];
    if (data is! Map) {
      throw const ServerException(
          message: 'The server response was missing its payload.');
    }
    return ApiEnvelope(
      data: data.cast<String, dynamic>(),
      message: map['message'] as String?,
      metadata: ApiMetadata.fromJson(map['metadata']),
      traceId: map['traceId'] as String?,
    );
  }

  /// The list under [key], as raw JSON objects.
  List<DataMap> list(String key) =>
      (data[key] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();

  /// The nested object under [key], for payloads like `data.depot`.
  DataMap? object(String key) => (data[key] as Map?)?.cast<String, dynamic>();
}

/// Paging and sync bookkeeping from the envelope's `metadata` block.
class ApiMetadata {
  const ApiMetadata({
    required this.page,
    required this.pageSize,
    required this.totalRecords,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
    this.syncTimestamp,
    this.isDeltaSync = false,
  });

  final int page;

  /// **Read this rather than assuming you got what you asked for.** The server
  /// clamps `pageSize` to 200 silently instead of rejecting a larger value —
  /// deliberately, so a mistyped page size on a flaky connection degrades
  /// instead of failing.
  final int pageSize;

  final int totalRecords;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPreviousPage;

  /// The server's clock at the moment the query ran, and the **only** valid
  /// source for the next `modifiedSince`.
  ///
  /// Never substitute the device clock here. A phone running ten minutes fast
  /// would ask for changes since the future, receive an empty delta, store
  /// that timestamp, and never sync again — a silent, permanent failure. The
  /// server rejects a `modifiedSince` more than five minutes ahead of its own
  /// time precisely to catch clients that get this wrong.
  final DateTime? syncTimestamp;

  /// True when the response was filtered by `modifiedSince`, which also means
  /// tombstones (`deleted: true`) may be present.
  final bool isDeltaSync;

  static ApiMetadata? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.cast<String, dynamic>();
    return ApiMetadata(
      page: (map['page'] as num?)?.toInt() ?? 1,
      pageSize: (map['pageSize'] as num?)?.toInt() ?? 0,
      totalRecords: (map['totalRecords'] as num?)?.toInt() ?? 0,
      totalPages: (map['totalPages'] as num?)?.toInt() ?? 0,
      hasNextPage: map['hasNextPage'] as bool? ?? false,
      hasPreviousPage: map['hasPreviousPage'] as bool? ?? false,
      syncTimestamp: parseUtc(map['syncTimestamp']),
      isDeltaSync: map['isDeltaSync'] as bool? ?? false,
    );
  }
}

/// Parses an API timestamp as UTC.
///
/// Every timestamp the API returns is UTC ISO-8601. `DateTime.parse` honours a
/// trailing `Z`, but a server that ever drops it would silently produce a
/// local-time `DateTime` that compares wrongly against a watermark — so the
/// result is forced to UTC rather than trusted. Convert for display only.
DateTime? parseUtc(Object? raw) {
  if (raw is DateTime) return raw.toUtc();
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toUtc();
}

/// The inverse of [parseUtc]: an ISO-8601 string that always carries an
/// explicit UTC offset.
///
/// `DateTime.toIso8601String()` alone is not safe to put on the wire. On a
/// **local** `DateTime` — which is what `DateTime.now()` returns, and what
/// every offline visit capture is stamped with — it emits no offset at all
/// (`2026-08-20T09:15:00.000`). A server reading that has to guess a zone, and
/// in Cambodia (UTC+7) guessing UTC moves a morning check-in seven hours into
/// the previous night. That is the same class of bug as the UTC-anchoring one
/// the route fixtures already hit.
///
/// So: UTC instants keep the `Z` designator, and local instants are written
/// with their real offset (`+07:00`). Both are valid ISO-8601 and both name
/// the same instant unambiguously — which is the whole requirement.
///
/// Sub-second precision is dropped deliberately: the API's documented format
/// is second-resolution, and no visit capture is meaningful below it.
String formatIsoOffset(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');

  final date = '${value.year.toString().padLeft(4, '0')}-'
      '${two(value.month)}-${two(value.day)}';
  final time = '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';

  if (value.isUtc) return '${date}T${time}Z';

  final offset = value.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final absolute = offset.abs();
  return '$date'
      'T'
      '$time$sign${two(absolute.inHours)}:'
      '${two(absolute.inMinutes.remainder(60))}';
}

/// The same envelope as [ApiEnvelope], for the endpoints whose `data` is a
/// **JSON array rather than an object**.
///
/// The materials selection surface is the reason this exists: `GET
/// selection/categories`, `GET selection/schema` and `POST selection/facets`
/// all answer `{ "success": …, "data": [ … ] }`. Running [ApiEnvelope.fromBody]
/// over one of those throws "missing its payload", because it insists on a map.
///
/// [key] handles the third shape the same family of endpoints uses — the flat
/// material list nests its rows one level deeper, at `data.materials`. Passing
/// a key makes this tolerant of both, which matters because
/// `POST selection/materials` is documented as returning "the same rows as the
/// catalogue list" and the two are not wrapped identically.
class ApiListEnvelope {
  const ApiListEnvelope({
    required this.items,
    this.message,
    this.metadata,
    this.traceId,
  });

  final List<DataMap> items;
  final String? message;
  final ApiMetadata? metadata;
  final String? traceId;

  factory ApiListEnvelope.fromBody(Object? body, {String? key}) {
    // A bare array. Not the documented envelope, but the integration guide
    // prints several responses this way and a client that dies on it would be
    // brittle for no benefit.
    if (body is List) return ApiListEnvelope(items: _rows(body));

    if (body is! Map) {
      throw const ServerException(
          message: 'The server returned an unexpected response.');
    }
    final map = body.cast<String, dynamic>();
    final data = map['data'];

    final List<DataMap> items;
    if (data is List) {
      items = _rows(data);
    } else if (data is Map && key != null) {
      items = _rows(data[key]);
    } else if (data == null) {
      // An empty result set, not a malformed response.
      items = const [];
    } else {
      throw const ServerException(
          message: 'The server response was missing its payload.');
    }

    return ApiListEnvelope(
      items: items,
      message: map['message'] as String?,
      metadata: ApiMetadata.fromJson(map['metadata']),
      traceId: map['traceId'] as String?,
    );
  }

  static List<DataMap> _rows(Object? raw) =>
      (raw as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
}
