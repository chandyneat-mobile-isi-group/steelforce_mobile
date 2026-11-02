import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:steelforce/core/network/api/api_defaults.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/notification/data/models/inbox_item_mapper.dart';
import 'package:steelforce/features/notification/data/models/notification_api_mapper.dart';
import 'package:steelforce/features/notification/data/remote/notification_remote_data_source.dart';
import 'package:steelforce/features/notification/domain/entities/notification_counts.dart';
import 'package:steelforce/features/notification/domain/entities/notification_preferences.dart';
import 'package:steelforce/features/notification/domain/entities/push_registration.dart';

/// The real notification API: the inbox at `/me/notifications` (backend
/// `InboxEndpoints`) and the device registry at `/me/devices`.
///
/// Every success is `{ "success": true, "data": { … } }` — [ApiEnvelope].
/// Mark-read answers `204 No Content` and is not parsed: a reader run over an
/// empty body is how a successful call starts reporting failure. Errors are
/// `{ "success": false, "error": { "code", "message" } }`, which
/// [ApiError.fromDio] reads, so callers branch on codes such as
/// `NOTIFICATION_NOT_FOUND` and `NOTIFICATION_CURSOR_INVALID`.
class ApiNotificationRemoteDataSource implements NotificationRemoteDataSource {
  const ApiNotificationRemoteDataSource(this._client);

  final Dio _client;

  @override
  Future<NotificationPage> fetchPage({
    String? cursor,
    int limit = ApiDefaults.notificationPageSize,
    bool unreadOnly = false,
  }) async {
    try {
      final response = await _client.get<DataMap>(
        ApiEndpoints.notificationsEndpoint,
        queryParameters: {
          if (cursor != null) 'cursor': cursor,
          'limit': limit,
          if (unreadOnly) 'unreadOnly': true,
        },
      );
      final page = ApiEnvelope.fromBody(response.data).data;
      return NotificationPage(
        // A row with no id is skipped rather than failing the page: one
        // malformed record must not cost the rep the rest.
        items: InboxItemMapper.itemsFromJson(page['items']),
        nextCursor: page['nextCursor'] as String?,
      );
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<NotificationCounts> fetchCounts() async {
    try {
      final response =
          await _client.get<DataMap>(ApiEndpoints.notificationCountsEndpoint);
      return InboxItemMapper.countsFromJson(
          ApiEnvelope.fromBody(response.data).data);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<void> markRead(String id) async {
    try {
      await _client.post<void>(ApiEndpoints.notificationReadEndpoint(id));
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<int> markAllRead({String? categoryCode}) async {
    try {
      final response =
          await _client.post<DataMap>(ApiEndpoints.notificationReadAllEndpoint);
      final data = ApiEnvelope.fromBody(response.data).data;
      return (data['marked'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<void> recordAction(
    String id, {
    String? actionId,
    DateTime? occurredAt,
  }) async {
    try {
      await _client.post<void>(
        ApiEndpoints.notificationActionEndpoint(id),
        data: <String, Object?>{
          // Omitted when the rep acted inside the record rather than from a
          // notification button — §8.3 allows exactly that, and sending an id
          // the notification does not offer answers
          // `400 Notification.ActionNotOffered`.
          if (actionId != null) 'actionId': actionId,
          if (occurredAt != null)
            // An explicit offset, never a bare local timestamp: the offline
            // queue stamps these with `DateTime.now()`, and in Cambodia (UTC+7)
            // a server guessing UTC moves a morning acknowledgement seven hours
            // into the previous night.
            'occurredAt': formatIsoOffset(occurredAt),
        },
      );
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<void> dismiss(String id) async {
    try {
      await _client.delete<void>(ApiEndpoints.notificationDismissEndpoint(id));
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<void> invokeAction({
    required String endpoint,
    required String method,
  }) async {
    try {
      await _client.request<void>(
        endpoint,
        options: Options(method: method.toUpperCase()),
      );
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<PushRegistrationResult> registerDevice(
      PushRegistration registration) async {
    final body = NotificationApiMapper.registrationToJson(registration);
    final path = ApiEndpoints.deviceRegisterEndpoint(registration.deviceId);

    try {
      if (kDebugMode) {
        debugPrint('=========== PUT device registration ===========');
        debugPrint('path: $path');
        debugPrint('platform: ${body['platform']}');
        debugPrint('pushToken: [REDACTED]');
        debugPrint('locale: ${body['locale']}');
        debugPrint('appVersion: ${body['appVersion']}');
      }

      Response<Object?> response;
      try {
        response = await _client.put<Object?>(path, data: body);
      } on DioException catch (error) {
        if (error.response?.statusCode != 409) rethrow;
        if (kDebugMode) {
          debugPrint('device registration: retrying once after 409');
        }
        response = await _client.put<Object?>(path, data: body);
      }
      // The registration contract only guarantees successful status, and may
      // return 204. Parse an optional representation when supplied.
      try {
        final envelope = ApiEnvelope.fromBody(response.data);
        final result = NotificationApiMapper.registrationFromJson({
          ...envelope.data,
          'pushPermissionGranted': envelope.data['pushPermissionGranted'] ??
              registration.pushPermissionGranted,
        });
        if (kDebugMode) {
          debugPrint('============== result ==============');
          debugPrint('status: ${response.statusCode}');
          debugPrint('success: true');
        }
        return result;
      } on Object {
        if (kDebugMode) {
          debugPrint('============== result ==============');
          debugPrint('status: ${response.statusCode}');
          debugPrint('success: true');
        }
        return PushRegistrationResult(
          id: registration.deviceId,
          deviceId: registration.deviceId,
          isActive: true,
          pushPermissionGranted: registration.pushPermissionGranted,
        );
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('============== result ==============');
        debugPrint('status: ${e.response?.statusCode ?? 'no response'}');
        debugPrint('success: false');
      }
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<void> deregisterDevice(String deviceId) async {
    final path = ApiEndpoints.deviceEndpoint(deviceId);
    try {
      final response = await _client.delete<void>(path);
      _dump('DEVICE DEREGISTER',
          method: 'DELETE', path: path, status: response.statusCode);
    } on DioException catch (e) {
      _dump('DEVICE DEREGISTER — FAILED',
          method: 'DELETE',
          path: path,
          status: e.response?.statusCode,
          response: e.response?.data);
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<NotificationPreferences> fetchPreferences() async {
    try {
      final response = await _client
          .get<DataMap>(ApiEndpoints.notificationPreferencesEndpoint);
      final envelope = ApiEnvelope.fromBody(response.data);
      return NotificationApiMapper.preferencesFromJson(envelope.data);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  /// Prints one device-registry round trip to the console.
  ///
  /// TODO(release-gate): debug-only. This must not ship enabled.
  ///
  /// ## Why this is fenced rather than logged
  ///
  /// The request body carries the **FCM registration token** — a credential
  /// that addresses pushes to one specific handset — which
  /// `docs/skills/security.md` §10 keeps out of logs. So it cannot go through
  /// [AppLogger]: `LogRedactor` would replace `pushToken`, `deviceId` and
  /// `deviceName` with `***REDACTED***`, which is correct for every other
  /// caller and would leave this dump showing nothing worth seeing.
  ///
  /// `kDebugMode` is a compile-time constant, so the whole body is
  /// **tree-shaken out of a release build** rather than skipped at runtime.
  /// That is what makes a deliberate §10 exception acceptable: there is no
  /// build in which it can leak.
  ///
  /// The structured, release-safe view of the same call is
  /// `push.permission` + `push.registered` in `PushDeviceRepositoryImpl` —
  /// status, flags and counts, never the token.
  void _dump(
    String label, {
    required String method,
    required String path,
    Object? request,
    int? status,
    Object? response,
  }) {
    if (!kDebugMode) return;

    const encoder = JsonEncoder.withIndent('  ');
    void write(String line) => debugPrint('│ $line');
    void writeJson(Object? value) {
      try {
        // Line by line: `debugPrint` throttles and Android's logcat drops very
        // long single lines, so a one-string dump arrives truncated exactly
        // when it is most needed.
        for (final line in encoder.convert(value).split('\n')) {
          write(line);
        }
      } catch (_) {
        write('(unencodable) $value');
      }
    }

    debugPrint('┌── $label ${'─' * (46 - label.length).clamp(0, 46)}');
    write('$method $path');
    if (request != null) {
      write('── request ──');
      writeJson(request);
    }
    write('── response ${status ?? '(no status)'} ──');
    if (response != null) {
      writeJson(response);
    } else {
      write('(no body)');
    }
    debugPrint('└${'─' * 64}');
  }

  @override
  Future<NotificationPreferences> savePreferences(
      NotificationPreferences preferences) async {
    try {
      final response = await _client.put<DataMap>(
        ApiEndpoints.notificationPreferencesEndpoint,
        data: NotificationApiMapper.preferencesToJson(preferences),
      );
      // The PUT echoes the saved document. Falling back to what was sent — for
      // a 204, or a body the reader rejects — is right: the server accepted it,
      // so throwing here would tell the rep their saved settings failed to save.
      try {
        final envelope = ApiEnvelope.fromBody(response.data);
        return NotificationApiMapper.preferencesFromJson(envelope.data);
      } on Object {
        return preferences;
      }
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }
}
