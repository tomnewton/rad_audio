import 'dart:async';

import 'package:flutter/services.dart';

const String EVENT_TYPE_KEY = "EVENT_TYPE";

class RadAudioArgKeys {
  static const String DURATION = "DURATION"; //will contain an int for number of seconds of audio
  static const String CURRENT_PLAYBACK_POSITION = "CURRENT_PLAYBACK_POSITION";
}

class RadAudioEventTypes {
  static const String PREPARING_TO_PLAY = "PREPARING_TO_PLAY";
  static const String PLAYBACK_STOPPED = "PLAYBACK_STOPPED";
  static const String READY_TO_PLAY = "READY_TO_PLAY";
  static const String PLAYBACK_STARTED = "PLAYBACK_STARTED";
  static const String PROGRESS_EVENT = "PROGRESS";
  static const String PAUSED = "PLAYBACK_PAUSED";
  static const String SEEKING = "SEEKING";
  static const String SEEK_COMPLETE = "SEEK_COMPLETE";
}

class RadAudioErrorTypes {
  static const String FILE_DOESNT_EXIST = "FILE_DOESNT_EXIST";
  static const String PLAYER_BAD_STATE = "PLAYER_BAD_STATE";
  static const String FAILED_LOADING_FILE = "FAILED_LOADING_FILE";
  static const String ASSET_PROPERTY_LOADING_ERROR = "ASSET_PROPERTY_LOADING_ERROR";
}

class RadAudioPrepareToPlayMsg {
  String imageUri;
  String audioUri;
  String titleText;
  String subtitleText;

  RadAudioPrepareToPlayMsg(this.audioUri, this.imageUri, this.titleText, this.subtitleText);

  Map<String, String> toMap() {
    return new Map<String, String>.from({
      "audioUri": this.audioUri,
      "imageUri": this.imageUri,
      "titleText": this.titleText,
      "subtitleText": this.subtitleText,
    });
  }
}

class RadAudio {
  IAudioPlayer player;
  StreamController _sc;

  static const MethodChannel _channel = const MethodChannel('rad_audio');

  static void play() => _channel.invokeMethod("play");

  static void stop() => _channel.invokeMethod("stop");

  static void pause() => _channel.invokeMethod("pause");

  static void seekDelta(int seconds) => _channel.invokeMethod("seekDelta", [seconds]);

  static void seekToTime(int seconds) => _channel.invokeMethod("seekToTime", [seconds]);

  static RadAudio _singleton;

  //Private constructor.
  RadAudio._internal({this.player});

  factory RadAudio({IAudioPlayer player}) {
    if (RadAudio._singleton != null) {
      return _singleton;
    }
    _singleton = new RadAudio._internal(player: player);
    _channel.setMethodCallHandler(_singleton.handler);
    return _singleton;
  }

  Stream<dynamic> prepareToPlay(RadAudioPrepareToPlayMsg msg) {
    _channel.invokeMethod("prepareToPlay", [msg.toMap()]);
    if (_sc != null) {
      _sc.close(); // we were playing something before... close the stream.
    }
    _sc = new StreamController<RadAudioEvent>(
        onListen: onListen, onPause: onPause, onCancel: onCancel, onResume: onResume);
    _sc.add(new RAPreparingToPlayEvent.from(msg));
    return _sc.stream;
  }

  Future<dynamic> handler(MethodCall call) async {
    Map<String, dynamic> args = (call.arguments as Map).cast<String, dynamic>();
    String eventType = args[EVENT_TYPE_KEY];

    switch (eventType) {
      case RadAudioEventTypes.READY_TO_PLAY:
        double duration = args[RadAudioArgKeys.DURATION];
        player?.readyToPlay(duration);
        RAReadyToPlayEvent evt = new RAReadyToPlayEvent.from(args);
        _send(evt);
        break;
      case RadAudioEventTypes.PROGRESS_EVENT:
        double pos = args[RadAudioArgKeys.CURRENT_PLAYBACK_POSITION];
        RAProgressEvent evt = new RAProgressEvent.from(args);
        _send(evt);
        player?.playbackProgress(pos);
        break;
      case RadAudioEventTypes.PLAYBACK_STARTED:
        player?.playbackStarted();
        _send(new RAPlaybackStartedEvent());
        break;
      case RadAudioEventTypes.PLAYBACK_STOPPED:
        player?.playbackStopped();
        _send(new RAPlaybackStoppedEvent());
        break;
      case RadAudioEventTypes.SEEK_COMPLETE:
        int pos = args[RadAudioArgKeys.CURRENT_PLAYBACK_POSITION];
        player?.playbackProgress(pos.toDouble());
        _send(new RAProgressEvent.from(args));
        break;
      case RadAudioEventTypes.SEEKING:
        player?.isSeeking(true);
        _send(new RASeekingEvent());
        break;
      case RadAudioEventTypes.PAUSED:
        player?.playbackPaused();
        _send(new RAPlaybackPausedEvent());
        break;
      default:
        break;
    }
    return null;
  }

  void onListen() {}

  void onCancel() {}

  void onPause() {}

  void onResume() {}

  void onSubscriptionListen(StreamSubscription<dynamic> s) {}

  void onSubscriptionCancel(StreamSubscription<dynamic> s) {}

  void _send(RadAudioEvent event) {
    if (_sc.hasListener) {
      _sc.add(event);
    }
  }
}

abstract class IAudioPlayer {
  void readyToPlay(double duration);
  void playbackProgress(double pos);
  void isSeeking(bool seeking);
  void playbackStarted();
  void playbackStopped();
  void playbackPaused();
}

// The API ( Stream ) now sends RadAudioEvents.
abstract class RadAudioEvent {}
class RAPositionChangedEvent extends RadAudioEvent {
  final double position;
  RAPositionChangedEvent.from(Map<String, dynamic> arguments)
      : this.position = arguments[RadAudioArgKeys.CURRENT_PLAYBACK_POSITION];
}

class RAPlaybackStartedEvent extends RadAudioEvent {}

class RAPlaybackStoppedEvent extends RadAudioEvent {}

class RAReadyToPlayEvent extends RadAudioEvent {
  final double duration;
  RAReadyToPlayEvent.from(Map<String, dynamic> arguments) : this.duration = arguments[RadAudioArgKeys.DURATION];
}

class RAProgressEvent extends RAPositionChangedEvent {
  RAProgressEvent.from(Map<String, dynamic> arguments) : super.from(arguments);
}

class RASeekCompleteEvent extends RAPositionChangedEvent {
  RASeekCompleteEvent.from(Map<String, dynamic> arguments) : super.from(arguments);
}

class RASeekingEvent extends RadAudioEvent {}

class RAPlaybackPausedEvent extends RadAudioEvent {}

class RAPreparingToPlayEvent extends RadAudioEvent {
  final RadAudioPrepareToPlayMsg msg;
  RAPreparingToPlayEvent.from(this.msg);
}
