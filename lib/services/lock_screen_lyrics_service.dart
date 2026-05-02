import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'lyrics_manager.dart';

/// Service for managing synchronized lyrics on the lock screen
/// Handles iOS Live Activities and Android Media Notification updates
class LockScreenLyricsService {
  static const _platform = MethodChannel('com.devid.musly/lyrics');
  static const _eventChannel = EventChannel('com.devid.musly/lyrics_updates');

  LyricsManager? _currentLyrics;
  StreamSubscription<Duration>? _positionSubscription;
  String? _lastSentLine;
  Timer? _updateTimer;

  // Throttling configuration
  static const _updateInterval = Duration(milliseconds: 500);

  /// Whether Live Activities/iOS lock screen lyrics are supported
  bool get supportsLiveActivities => !kIsWeb && Platform.isIOS;

  /// Whether Android media notification lyrics are supported  
  bool get supportsAndroidNotification => !kIsWeb && Platform.isAndroid;

  /// Initialize the service
  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('[Lyrics] Web platform - lyrics disabled');
      return;
    }

    debugPrint('[Lyrics] Initializing lock screen lyrics service...');
    debugPrint('[Lyrics] Platform: ${Platform.operatingSystem}');
    debugPrint('[Lyrics] Live Activities supported: $supportsLiveActivities');
    debugPrint('[Lyrics] Android notification supported: $supportsAndroidNotification');

    _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        debugPrint('[Lyrics] Native event: $event');
      },
      onError: (dynamic error) {
        debugPrint('[Lyrics] Native error: $error');
      },
    );

    // Initialize native side
    try {
      final result = await _platform.invokeMethod('initialize');
      debugPrint('[Lyrics] Native init result: $result');
    } catch (e) {
      debugPrint('[Lyrics] Failed to initialize native lyrics: $e');
    }
  }

  /// Load lyrics for the current song
  Future<void> loadLyrics(String? lrcContent) async {
    if (lrcContent == null || lrcContent.isEmpty) {
      _currentLyrics = null;
      await _clearLyrics();
      return;
    }

    _currentLyrics = LyricsManager.parse(lrcContent);
    _lastSentLine = null;

    // Notify native side that lyrics are available
    if (_currentLyrics!.hasLyrics) {
      try {
        await _platform.invokeMethod('lyricsAvailable', {
          'hasLyrics': true,
          'lineCount': _currentLyrics!.lineCount,
        });
      } catch (e) {
        debugPrint('Failed to notify lyrics available: $e');
      }
    }
  }

  /// Clear current lyrics
  Future<void> _clearLyrics() async {
    _currentLyrics = null;
    _lastSentLine = null;
    _updateTimer?.cancel();
    _updateTimer = null;

    try {
      await _platform.invokeMethod('clearLyrics');
    } catch (e) {
      debugPrint('Failed to clear lyrics: $e');
    }
  }

  /// Start synchronizing lyrics to position updates
  /// Call this when a song starts playing
  void startSync(Stream<Duration> positionStream) {
    debugPrint('[Lyrics] Starting lyrics sync...');
    _positionSubscription?.cancel();
    _updateTimer?.cancel();

    if (_currentLyrics == null || !_currentLyrics!.hasLyrics) {
      debugPrint('[Lyrics] No lyrics to sync');
      return;
    }
    
    debugPrint('[Lyrics] Lyrics loaded: ${_currentLyrics!.lineCount} lines');

    // Use a timer-based approach for more control over update frequency
    DateTime? lastUpdate;
    String? lastLine;

    _positionSubscription = positionStream.listen(
      (position) {
        final now = DateTime.now();
        
        // Throttle updates
        if (lastUpdate != null && 
            now.difference(lastUpdate!) < _updateInterval) {
          return;
        }

        final currentLine = _currentLyrics!.getCurrentLine(position);
        
        // Only send if line changed
        if (currentLine != lastLine && currentLine != null) {
          lastUpdate = now;
          lastLine = currentLine;
          debugPrint('[Lyrics] Line changed: "$currentLine"');
          _updateLockScreenLyrics(currentLine);
        }
      },
      onError: (error) {
        debugPrint('Position stream error in lyrics sync: $error');
      },
    );
  }

  /// Stop synchronization
  void stopSync() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// Update the lock screen with current lyrics
  Future<void> _updateLockScreenLyrics(String line) async {
    if (line == _lastSentLine) return;
    _lastSentLine = line;

    debugPrint('[Lyrics] Sending to native: "$line"');
    try {
      final result = await _platform.invokeMethod('updateLyrics', {
        'currentLine': line,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('[Lyrics] Native update result: $result');
    } catch (e) {
      debugPrint('[Lyrics] Failed to update lock screen lyrics: $e');
    }
  }

  /// Update song info for Live Activity (iOS)
  Future<void> updateSongInfo({
    required String title,
    required String artist,
    String? artworkUrl,
  }) async {
    if (kIsWeb) return;
    
    debugPrint('[Lyrics] Updating song info: $title - $artist');
    try {
      await _platform.invokeMethod('updateSongInfo', {
        'title': title,
        'artist': artist,
        'artworkUrl': artworkUrl,
      });
    } catch (e) {
      debugPrint('[Lyrics] Failed to update song info: $e');
    }
  }

  /// Update lyrics for Android media notification
  /// This should be called from your audio handler when updating media item
  Future<String?> getNotificationSubtitle(Duration position) async {
    if (_currentLyrics == null || !_currentLyrics!.hasLyrics) {
      return null;
    }

    return _currentLyrics!.getCurrentLine(position);
  }

  /// Get current lyrics line for display
  String? getCurrentLine(Duration position) {
    return _currentLyrics?.getCurrentLine(position);
  }

  /// Get lyrics context (previous, current, next) for rich UI display
  LyricsContext? getLyricsContext(Duration position) {
    return _currentLyrics?.getContext(position);
  }

  /// Public stream for in-app UI display
  /// More frequent updates than lock screen (100ms vs 500ms)
  Stream<String?> getLyricsStream(Stream<Duration> positionStream) {
    if (_currentLyrics == null || !_currentLyrics!.hasLyrics) {
      return const Stream.empty();
    }
    
    return positionStream
      .asyncMap((position) async => _currentLyrics!.getCurrentLine(position))
      .distinct();
  }

  /// Dispose the service
  void dispose() {
    stopSync();
    _clearLyrics();
  }
}
