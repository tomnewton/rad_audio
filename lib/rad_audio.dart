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

class RadAudioPrepareToPlayMsg{
  String imageUri;
  String audioUri;
  String titleText;
  String subtitleText;

  RadAudioPrepareToPlayMsg(this.audioUri, this.imageUri, this.titleText, this.subtitleText);

  Map<String, String> toMap(){
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

  static const MethodChannel _channel =
  const MethodChannel('rad_audio');

  /*static Future<String> get platformVersion =>
      _channel.invokeMethod('getPlatformVersion');*/

 /* static void prepareToPlay(RadAudioPrepareToPlayMsg msg) {
    _channel.invokeMethod("prepareToPlay", [msg.toMap()]);
  }*/


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

  static RadAudio _singleton;

  //Private constructor.
  RadAudio._internal({this.player});


  factory RadAudio({IAudioPlayer player}){
    if (RadAudio._singleton != null){
      return _singleton;
    }
    _singleton = new RadAudio._internal(player: player);
    _channel.setMethodCallHandler(_singleton.handler);
    return _singleton;
  }

  Stream<dynamic> prepareToPlay(RadAudioPrepareToPlayMsg msg){
    _channel.invokeMethod("prepareToPlay", [msg.toMap()]);
    if ( _sc != null ){
      //_sc.add({"eventType": RadAudioEventTypes.PLAYBACK_STOPPED});
      _sc.close(); // we were playing something before... close the stream.
    }
    _sc = new StreamController(onListen: onListen, onPause: onPause, onCancel: onCancel, onResume: onResume);
    _sc.add({
      "eventType": RadAudioEventTypes.PREPARING_TO_PLAY,
      "message" : msg
    });
    return _sc.stream;
  }

  Future<dynamic> handler(MethodCall call) async {
    //print("Heard a call!");
    switch (call.method){
      case "event":
        //print(call.method);

        Map<String, dynamic> args = call.arguments;
        String eventType = args[EVENT_TYPE_KEY];

        if ( eventType == RadAudioEventTypes.READY_TO_PLAY ){
          double duration = args[RadAudioArgKeys.DURATION];
          player?.readyToPlay(duration);
          _send({"eventType": eventType, RadAudioArgKeys.DURATION: duration});
        } else if ( eventType == RadAudioEventTypes.PROGRESS_EVENT ){
          double pos = args[RadAudioArgKeys.CURRENT_PLAYBACK_POSITION];
          _send({"eventType": eventType, RadAudioArgKeys.CURRENT_PLAYBACK_POSITION: pos.toDouble()});
          player?.playbackProgress(pos.toDouble());
        } else if ( eventType == RadAudioEventTypes.PLAYBACK_STARTED ){
          player?.playbackStarted();
          _send({"eventType": eventType});
        } else if ( eventType == RadAudioEventTypes.PLAYBACK_STOPPED ){
          player?.playbackStopped();
          _send({"eventType": eventType});
        } else if ( eventType == RadAudioEventTypes.SEEK_COMPLETE){
          double pos = args[RadAudioArgKeys.CURRENT_PLAYBACK_POSITION];
          player?.playbackProgress(pos);
          _send({"eventType": eventType, "position": pos});
        } else if ( eventType == RadAudioEventTypes.SEEKING){
          player?.isSeeking(true);
          _send({"eventType": eventType});
        } else if ( eventType == RadAudioEventTypes.SEEK_COMPLETE){
          player?.isSeeking(false);
          _send({"eventType": eventType});
        } else if ( eventType == RadAudioEventTypes.PAUSED ){
          player?.playbackPaused();
          _send({"eventType": eventType});
        }
        break;
      default:
        break;
    }
    return new Future(()=>true);
  }

  void onListen(){

  }

  void onCancel(){

  }

  void onPause(){

  }

  void onResume(){

  }

  void onSubscriptionListen(StreamSubscription<dynamic> s){

  }

  void onSubscriptionCancel(StreamSubscription<dynamic> s){

  }

  void _send(dynamic event){
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