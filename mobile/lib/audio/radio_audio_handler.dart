import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/station.dart';
import 'local_player.dart';

/// Phone playback through just_audio (ExoPlayer / AVPlayer), exposed to the
/// OS via audio_service for background play, the media notification, lock
/// screen and headset buttons.
class RadioAudioHandler extends BaseAudioHandler implements LocalPlayer {
  RadioAudioHandler() {
    _player.playbackEventStream.listen(
      (_) => _broadcast(),
      onError: (Object e, StackTrace st) => _setError(),
    );
    _player.playingStream.listen((_) => _broadcast());
    _player.icyMetadataStream.listen((icy) {
      final title = icy?.info?.title?.trim();
      final value = (title == null || title.isEmpty) ? null : title;
      _streamTitle.add(value);
      final item = mediaItem.value;
      if (item != null) mediaItem.add(item.copyWith(artist: value ?? ''));
    });
  }

  final _player = AudioPlayer();
  final _playback = StreamController<LocalPlayback>.broadcast();
  final _streamTitle = StreamController<String?>.broadcast();
  Station? _station;
  bool _error = false;

  @override
  void Function()? onSkipToNext;
  @override
  void Function()? onSkipToPrevious;

  @override
  Stream<LocalPlayback> get playback => _playback.stream;

  @override
  Stream<String?> get streamTitle => _streamTitle.stream;

  @override
  Future<void> play([Station? station]) async {
    station ??= _station;
    if (station == null) return;
    _station = station;
    _error = false;
    _streamTitle.add(null);
    mediaItem.add(
      MediaItem(id: station.id, title: station.name, album: 'AUX FM'),
    );
    try {
      await _player.setUrl(station.url);
      // play() completes only when playback stops, so don't await it.
      unawaited(_player.play());
    } on Exception {
      _setError();
    }
  }

  /// Live radio: pausing would resume from a stale buffer, so stop instead.
  @override
  Future<void> pause() => stop();

  @override
  Future<void> stop() async {
    await _player.stop();
    _broadcast();
  }

  @override
  Future<void> skipToNext() async => onSkipToNext?.call();

  @override
  Future<void> skipToPrevious() async => onSkipToPrevious?.call();

  void _setError() {
    _error = true;
    _broadcast();
  }

  void _broadcast() {
    final playing = _player.playing;
    final state = _player.processingState;
    final loading =
        state == ProcessingState.loading || state == ProcessingState.buffering;

    _playback.add(switch ((_error, playing, loading)) {
      (true, _, _) => LocalPlayback.error,
      (_, true, true) => LocalPlayback.loading,
      (_, true, false) => LocalPlayback.playing,
      _ => LocalPlayback.idle,
    });

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.stop : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.stop},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _error
            ? AudioProcessingState.error
            : switch (state) {
                ProcessingState.idle => AudioProcessingState.idle,
                ProcessingState.loading => AudioProcessingState.loading,
                ProcessingState.buffering => AudioProcessingState.buffering,
                ProcessingState.ready => AudioProcessingState.ready,
                ProcessingState.completed => AudioProcessingState.completed,
              },
        playing: playing,
      ),
    );
  }
}
