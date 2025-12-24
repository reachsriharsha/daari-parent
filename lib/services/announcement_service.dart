import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/app_logger.dart';

/// Service for Text-to-Speech announcements
/// Provides audio feedback for trip events
class AnnouncementService {
  static final AnnouncementService _instance = AnnouncementService._internal();
  factory AnnouncementService() => _instance;
  AnnouncementService._internal();

  FlutterTts? _flutterTts;
  bool _isInitialized = false;

  /// Initialize the TTS engine
  /// Called once during app startup
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Only initialize for Android platform
    if (!Platform.isAndroid) {
      logger.info('[TTS] Skipping initialization - not Android platform');
      return;
    }

    try {
      _flutterTts = FlutterTts();

      // Configure TTS settings
      await _flutterTts!.setLanguage("en-US");
      await _flutterTts!.setSpeechRate(0.5); // Normal speed
      await _flutterTts!.setVolume(1.0); // Full volume (respects system)
      await _flutterTts!.setPitch(1.0); // Normal pitch

      // Set completion and error handlers
      _flutterTts!.setCompletionHandler(() {
        logger.debug('[TTS] Announcement completed');
      });

      _flutterTts!.setErrorHandler((message) {
        logger.error('[TTS ERROR] $message');
      });

      _isInitialized = true;
      logger.info('[TTS] AnnouncementService initialized successfully');
    } catch (e) {
      logger.error('[TTS ERROR] Failed to initialize: $e');
      _flutterTts = null;
    }
  }

  /// Announce text using Text-to-Speech
  ///
  /// This is the ONLY public method for TTS functionality.
  /// Fire-and-forget pattern - does not wait for speech completion.
  ///
  /// [text] - The text to be spoken
  ///
  /// Example:
  /// ```dart
  /// await announce("Trip started for Family Group");
  /// ```
  Future<void> announce(String text) async {
    // Guard: Skip if not initialized or not Android
    if (!_isInitialized || _flutterTts == null) {
      logger.warning('[TTS] Cannot announce - service not initialized');
      return;
    }

    // Guard: Skip empty text
    if (text.trim().isEmpty) {
      logger.warning('[TTS] Cannot announce - empty text');
      return;
    }

    try {
      logger.debug('[TTS] Announcing: "$text"');

      // Stop any currently playing announcement
      await _flutterTts!.stop();

      // Speak the text (fire-and-forget)
      await _flutterTts!.speak(text);

      logger.info('[TTS] ✅ Announcement queued: "$text"');
    } catch (e) {
      // Log error but don't throw - TTS failures are non-critical
      logger.error('[TTS ERROR] Failed to announce: $e');
    }
  }

  /// Clean up TTS resources
  /// Called during app shutdown
  Future<void> dispose() async {
    if (_flutterTts != null) {
      await _flutterTts!.stop();
      _isInitialized = false;
      logger.info('[TTS] AnnouncementService disposed');
    }
  }
}

/// Global instance for easy access throughout the app
final announcementService = AnnouncementService();
