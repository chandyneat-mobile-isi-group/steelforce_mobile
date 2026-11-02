import 'package:steelforce/features/notification/domain/entities/notification_message.dart';

/// Keys in [NotificationMessage.data] for what `GET /me/notifications` sends
/// beside the English text.
///
/// The link keys match the push `data` block (`targetType`, `targetId`), so a
/// row stored from a push and one stored from the inbox read the same.
abstract final class NotificationDataKeys {
  static const String titleKm = 'title_km';
  static const String bodyKm = 'body_km';
  static const String targetType = 'targetType';
  static const String targetId = 'targetId';
}

/// The title and body in the app's language.
///
/// The API sends both English and Khmer, with Khmer set to the English text
/// when none was written. [NotificationMessage.title] holds the English; the
/// Khmer rides in [NotificationMessage.data]. A row from a push carries only
/// the text the OS showed, so it falls back to [NotificationMessage.title].
extension NotificationMessageText on NotificationMessage {
  String titleIn(String languageCode) =>
      _pick(languageCode, title, data[NotificationDataKeys.titleKm]);

  String bodyIn(String languageCode) =>
      _pick(languageCode, body, data[NotificationDataKeys.bodyKm]);

  static String _pick(String languageCode, String english, String? khmer) =>
      languageCode == 'km' && khmer != null && khmer.isNotEmpty
          ? khmer
          : english;
}
