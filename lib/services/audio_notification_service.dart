import 'package:just_audio/just_audio.dart';
import '../utils/app_logger.dart';

/// Service for playing audio notifications in background
/// Uses just_audio package for reliable background playback
class AudioNotificationService {
  // Singleton instance
  static final AudioNotificationService instance =
      AudioNotificationService._internal();

  factory AudioNotificationService() {
    return instance;
  }

  AudioNotificationService._internal();

  // Audio player instance
  final AudioPlayer _player = AudioPlayer();

  /// Play trip started notification sound
  /// Returns true if successfully started playback
  Future<bool> playTripStarted() async {
    return await _playSound('assets/audio/trip_started.mp3', 'Trip Started');
  }

  /// Play trip finished notification sound
  /// Returns true if successfully started playback
  Future<bool> playTripFinished() async {
    return await _playSound('assets/audio/trip_finished.mp3', 'Trip Finished');
  }

  /// Internal method to play audio file
  Future<bool> _playSound(String assetPath, String eventName) async {
    try {
      logger.debug('[AUDIO] Attempting to play: $assetPath');

      // Stop any currently playing sound
      await _player.stop();

      // Load and play the audio file
      await _player.setAsset(assetPath);
      await _player.setVolume(1.0); // Maximum volume

      // Play the sound (don't await - let it play in background)
      _player.play();

      logger.info('[AUDIO] Playing notification sound for: $eventName');
      return true;
    } catch (e) {
      logger.error('[AUDIO ERROR] Failed to play $eventName sound: $e');
      return false;
    }
  }

  /// Dispose the audio player
  Future<void> dispose() async {
    try {
      await _player.dispose();
      logger.debug('[AUDIO] Audio player disposed');
    } catch (e) {
      logger.error('[AUDIO ERROR] Error disposing audio player: $e');
    }
  }
}
