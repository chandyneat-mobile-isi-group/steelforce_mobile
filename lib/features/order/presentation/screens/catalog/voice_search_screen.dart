import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Pushed by [SpeechVoiceSearchService]. Listens on-device via `speech_to_text`
/// and pops with the recognized query string, or `null` if the user cancels,
/// says nothing, or the device has no speech recognition available.
class VoiceSearchScreen extends StatefulWidget {
  const VoiceSearchScreen({super.key});

  @override
  State<VoiceSearchScreen> createState() => _VoiceSearchScreenState();
}

class _VoiceSearchScreenState extends State<VoiceSearchScreen> {
  final SpeechToText _speech = SpeechToText();

  String _words = '';
  bool _listening = false;
  bool _finished = false; // guards against popping twice
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final available = await _speech.initialize(
        onStatus: _onStatus,
        onError: (e) => _onError(e.errorMsg),
      );
      if (!mounted) return;
      if (!available) {
        setState(() => _error = 'orders.voice.unavailable'.tr);
        return;
      }
      await _startListening();
    } catch (_) {
      if (mounted) setState(() => _error = 'orders.voice.start_failed'.tr);
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _words = '';
      _error = null;
      _listening = true;
    });
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _words = result.recognizedWords);
        if (result.finalResult) _accept();
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  void _onStatus(String status) {
    if (!mounted) return;
    final stopped = status == 'done' || status == 'notListening';
    if (stopped) {
      if (_words.trim().isNotEmpty) {
        _accept();
      } else {
        setState(() => _listening = false);
      }
    }
  }

  void _onError(String message) {
    if (!mounted || _finished) return;
    setState(() {
      _listening = false;
      _error = message.contains('no match') || message.contains('timeout')
          ? 'orders.voice.no_match_heard'.tr
          : 'orders.voice.error'.tr;
    });
  }

  void _accept() {
    if (_finished) return;
    _finished = true;
    final query = _words.trim();
    _speech.stop();
    if (mounted) Navigator.of(context).pop(query.isEmpty ? null : query);
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text('orders.voice.title'.tr,
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(17),
                fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(context.rr(24)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Text(
                _listening
                    ? 'orders.voice.listening'.tr
                    : (_error ?? 'orders.voice.tap_to_start'.tr),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: colors.textSecondary, fontSize: context.rsp(14)),
              ),
              SizedBox(height: context.rh(28)),
              GestureDetector(
                onTap: _listening ? _accept : _startListening,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _listening ? primaryColor : colors.surfaceSoft,
                    border: Border.all(color: primaryColor, width: 3),
                    boxShadow: _listening
                        ? [
                            BoxShadow(
                                color: primaryColor.withValues(alpha: 0.4),
                                blurRadius: 28,
                                spreadRadius: 6)
                          ]
                        : null,
                  ),
                  child: Icon(
                    _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: _listening ? Colors.white : primaryColor,
                    size: context.rr(46),
                  ),
                ),
              ),
              SizedBox(height: context.rh(28)),
              Text(
                _words.isEmpty ? 'orders.voice.example'.tr : _words,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _words.isEmpty
                      ? colors.textSecondary
                      : colors.textPrimary,
                  fontSize: _words.isEmpty ? 13 : 18,
                  fontWeight:
                      _words.isEmpty ? FontWeight.w400 : FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_words.trim().isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _accept,
                    icon: const Icon(Icons.search_rounded),
                    label: Text('common.search_button'.tr),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
