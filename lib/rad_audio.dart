import 'dart:async';

import 'package:flutter/services.dart';

const String EVENT_TYPE_KEY = "EVENT_TYPE";

class RadAudioArgKeys {
  static const String DURATION = "DURATION"; //will contain an int for number of seconds of audio
  static const String CURRENT_PLAYBACK_POSITION = "CURRENT_PLAYBACK_POSITION";
}

class RadAudioEventTypes {
  static const String PLAYBACK_STOPPED = "PLAYBACK_STOPPED";
  static const String READY_TO_PLAY = "READY_TO_PLAY";
  static const String PLAYBACK_STARTED = "PLAYBACK_STARTED";
  static const String PROGRESS_EVENT = "PROGRESS";
  static const String PAUSED = "PAUSED";
  static const String SEEKING = "SEEKING";
  static const String SEEK_COMPLETE = "SEEK_COMPLETE";
}

class RadAudioErrorTypes {
  static const String FILE_DOESNT_EXIST = "FILE_DOESNT_EXIST";
  static const String PLAYER_BAD_STATE = "PLAYER_BAD_STATE";
  static const String FAILED_LOADING_FILE = "FAILED_LOADING_FILE";
  static const String ASSET_PROPERTY_LOADING_ERROR = "ASSET_PROPERTY_LOADING_ERROR";
}

class RadAudio {
  final IAudioPlayer player;


  static const MethodChannel _channel =
  const MethodChannel('rad_audio');

  /*static Future<String> get platformVersion =>
      _channel.invokeMethod('getPlatformVersion');*/

  static void prepareToPlay(Map<String, String> args) =>
      _channel.invokeMethod("prepareToPlay", [args]);

  static void play() =>
      _channel.invokeMethod("play");

  static void stop() =>
      _channel.invokeMethod("stop");

  static void pause() =>
      _channel.invokeMethod("pause");

  static void seekDelta(int seconds) =>
      _channel.invokeMethod("seekDelta", [seconds]);

  static void seekToTime(int seconds) =>
      _channel.invokeMethod("seekToTime", [seconds]);

  RadAudio(this.player){
    _channel.setMethodCallHandler(this.handler);
  }

  Future<dynamic> handler(MethodCall call) async {
    //print("Heard a call!");
    switch (call.method){
      case "event":
        print(call.method);

        Map<String, dynamic> args = call.arguments;
        String eventType = args[EVENT_TYPE_KEY];

        if ( eventType == RadAudioEventTypes.READY_TO_PLAY ){
          //print("Heard Event: Ready To Play!");
          //contains the duration
          double duration = args[RadAudioArgKeys.DURATION];
          player.readyToPlay(duration);
        } else if ( eventType == RadAudioEventTypes.PROGRESS_EVENT ){
          //print("Progress @ ${call.arguments[1]} seconds");
          double pos = args[RadAudioArgKeys.CURRENT_PLAYBACK_POSITION];
          player.playbackProgress(pos);
        } else if ( eventType == RadAudioEventTypes.PLAYBACK_STARTED ){
          player.playbackStarted();
        } else if ( eventType == RadAudioEventTypes.PLAYBACK_STOPPED ){
          player.playbackStopped();
        } else if ( eventType == RadAudioEventTypes.SEEK_COMPLETE){
          double pos = args[RadAudioArgKeys.CURRENT_PLAYBACK_POSITION];
          player.playbackProgress(pos);
        } else if ( eventType == RadAudioEventTypes.SEEKING){
          player.isSeeking(true);
        } else if ( eventType == RadAudioEventTypes.SEEK_COMPLETE){
          player.isSeeking(false);
        }
        break;
      default:
        break;
    }
    return new Future(()=>true);
  }
}


abstract class IAudioPlayer {
  void readyToPlay(double duration);
  void playbackProgress(double pos);
  void isSeeking(bool seeking);
  void playbackStarted();
  void playbackStopped();
}