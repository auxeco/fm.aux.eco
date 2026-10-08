import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/station.dart';
import '../voice/station_search.dart';
import 'local_player.dart';

/// Phone playback through just_audio (ExoPlayer / AVPlayer), exposed to the
/// OS via audio_service: background play, the media notification, lock
/// screen, headset buttons, and the media browser that voice assistants and
/// Android Auto use to list and start stations.
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
    // Advertise the supported actions (play from search, ...) right away so
    // voice assistants can start the app before anything has played.
    _broadcast();
  }

  static final _artwork = Uri.parse('https://fm.aux.eco/favicon.png');

  final _player = AudioPlayer();
  final _playback = StreamController<LocalPlayback>.broadcast();
  final _streamTitle = StreamController<String?>.broadcast();
  Station? _station;
  bool _error = false;

  @override
  MediaSessionDelegate? delegate;

  @override
  Stream<LocalPlayback> get playback => _playback.stream;

  @override
  Stream<String?> get streamTitle => _streamTitle.stream;

  static MediaItem _item(Station s) => MediaItem(
    id: s.id,
    title: s.name,
    album: 'AUX FM',
    displayDescription: s.description,
    artUri: _artwork,
    playable: true,
  );

  /// With a [station]: the app plays it here. Without: play was pressed in
  /// the media session; the controller decides where it plays.
  @override
  Future<void> play([Station? station]) async {
    if (station == null) {
      final d = delegate;
      if (d != null) return d.resumeFromSession();
      station = _station;
    }
    if (station == null) return;
    _station = station;
    _error = false;
    _streamTitle.add(null);
    mediaItem.add(_item(station));
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
  Future<void> skipToNext() async => delegate?.skipToNext();

  @override
  Future<void> skipToPrevious() async => delegate?.skipToPrevious();

  // ---- Media browser: Android Auto, voice assistants ----

  List<Station> get _stations => delegate?.stations ?? const [];

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async => switch (parentMediaId) {
    AudioService.browsableRootId => _stations.map(_item).toList(),
    AudioService.recentRootId => [if (delegate case final d?) _item(d.current)],
    _ => const [],
  };

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    for (final s in _stations) {
      if (s.id == mediaId) return _item(s);
    }
    return null;
  }

  @override
  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async => searchStations(query, _stations).map(_item).toList();

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final d = delegate;
    if (d == null) return;
    for (final s in d.stations) {
      if (s.id == mediaId) return d.playStationFromSession(s);
    }
  }

  @override
  Future<void> playFromSearch(
    String query, [
    Map<String, dynamic>? extras,
  ]) async => delegate?.playFromSearch(query);

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
        systemActions: const {
          MediaAction.stop,
          MediaAction.playFromMediaId,
          MediaAction.playFromSearch,
        },
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
