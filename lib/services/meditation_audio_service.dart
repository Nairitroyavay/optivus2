// lib/services/meditation_audio_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:optivus2/models/meditation_track_model.dart';
import 'package:optivus2/config/meditation_library.dart';

class MeditationAudioService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  // ── Track Listing ──

  /// Returns the static list of tracks from the library.
  List<MeditationTrack> getTracks() {
    return MeditationLibrary.tracks.where((t) => t.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Alias for backward compatibility if needed, or simple getter.
  Stream<List<MeditationTrack>> watchTracks() {
    return Stream.value(getTracks());
  }

  // ── Playback ──

  Future<void> setTrack(MeditationTrack track) async {
    try {
      // Load from assets
      await _player.setAudioSource(AudioSource.uri(Uri.parse('asset:///${track.assetPath}')));
      await _player.setLoopMode(LoopMode.all);
    } catch (e) {
      debugPrint('Error setting track: $e');
      rethrow;
    }
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  
  Stream<bool> get playingStream => _player.playingStream;
  bool get isPlaying => _player.playing;

  // ── Download Management (No-ops/Removed) ──
  // These are kept as empty stubs or removed depending on call sites.
  // I will remove them to keep it clean, and update call sites.

  void dispose() {
    _player.dispose();
  }
}
