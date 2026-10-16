import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openTelegramOrCall(String rawPhoneNumber) async {
  // 1. Format the phone number (remove spaces, hyphens, and leading zeros for E.164 standard)
  // Example format expected: +85512345678
  final String cleanNumber = rawPhoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

  // Telegram deep link URI for phone numbers
  final Uri telegramUri = Uri.parse('tg://resolve?phone=$cleanNumber');

  // Standard Phone Call URI
  final Uri callUri = Uri(scheme: 'tel', path: cleanNumber);

  try {
    // 2. Check if Telegram app is installed and can handle the request
    bool canOpenTelegram = await canLaunchUrl(telegramUri);

    if (canOpenTelegram) {
      // Launch Telegram directly to that phone number's chat
      await launchUrl(
        telegramUri,
        mode: LaunchMode.externalApplication,
      );
    } else {
      // Fallback: Open phone call dialer
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri);
      } else {
        debugPrint('Could not launch phone dialer.');
      }
    }
  } catch (e) {
    if (kDebugMode) debugPrint('Error launching url: $e');
    // Fallback to phone dialer in case of any native errors
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
    }
  }
}
