import 'package:flutter/material.dart';
import 'package:steelforce/features/order/domain/services/voice_search_service.dart';
import 'package:steelforce/features/order/presentation/screens/catalog/voice_search_screen.dart';
import 'package:steelforce/routes/app_routes.dart';

/// Real `speech_to_text`-backed implementation. Pushes the listening UI via the
/// app's global [navigatorKey] — the same trick [MobileBarcodeScannerService]
/// uses — so [VoiceSearchService] itself stays free of any `BuildContext`.
class SpeechVoiceSearchService implements VoiceSearchService {
  const SpeechVoiceSearchService();

  @override
  Future<String?> listen() async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return null;
    return navigator.push<String>(
      MaterialPageRoute(
          fullscreenDialog: true, builder: (_) => const VoiceSearchScreen()),
    );
  }
}
