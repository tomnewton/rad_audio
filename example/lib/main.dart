import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:rad_audio/rad_audio.dart';
import 'package:rad_audio/RadSlider.dart';

void main() => runApp(new MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> implements IAudioPlayer{
  RadAudio audio;
  bool isPlaying = false;
  double sliderValue = 0.0;
  double duration = 0.0;

  String pathToArtwork = "";

  @override
  initState() {
    super.initState();
    audio = new RadAudio(player: this);
  }

  Future<File> _getFile(String name) async {
    String dir = (await getApplicationDocumentsDirectory()).path;
    File file = new File('$dir/$name');
    return file;
  }

  void play(){
    if ( this.isPlaying == true ){
      RadAudio.play();
      return;
    }
    /*Map<String, String> args = new Map<String, String>.from(
        {
          "imageUri": pathToArtwork,
          "audioUri": "https://traffic.megaphone.fm/GLT7778633911.mp3", //"https://traffic.megaphone.fm/GLT3809370877.mp3"
          "titleText": "Crimetown",
          "subtitleText": "Courtney"
        });*/

    RadAudioPrepareToPlayMsg msg = new RadAudioPrepareToPlayMsg(
        "https://traffic.megaphone.fm/GLT7778633911.mp3",
        pathToArtwork, "Crimetown", "Courtney");
    audio.prepareToPlay(msg);
    //RadAudio.prepareToPlay(msg);
  }

  void fetchDebugAlbumArt(){
    String artwork = "https://upload.wikimedia.org/wikipedia/en/8/82/Crimetown_logo.png";
    _getFile('heavyweight.png').then((File f){
      new HttpClient().getUrl(Uri.parse(artwork))
          .then((HttpClientRequest request) => request.close())
          .then((HttpClientResponse response) {
             response.pipe(f.openWrite());
             print("artwork available ${f.path}");
             pathToArtwork = f.path;
          }
        );
    });
  }

  void readyToPlay(double duration){
    setState((){
      this.duration = duration;
    });
    RadAudio.play();
    isPlaying = true;
  }

  void playbackProgress(double pos) {
    print(pos);
    setState((){
      pos = 300.0*(pos/this.duration);
      this.sliderValue = pos;
    });
  }

  void playbackStarted(){
    this.isPlaying = true;
  }

  void playbackStopped(){
    this.isPlaying = false;
    setState((){
      this.sliderValue = 0.0;
    });
  }

  void isSeeking(bool seeking){
    //TODO: implement seeking...
  }

  void dragStopped(double position){
    if ( this.duration != 0.0 ){

      RadAudio.seekToTime(((position/300.0)*duration).round());
    }
  }

  @override
  Widget build(BuildContext context) => new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
          title: new Text('Plugin example app'),
        ),
        body: new Center(
          child: new Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              new Row(
                children: <Widget>[new MaterialButton(onPressed: ()=>this.fetchDebugAlbumArt(), child: new Text("DL"), color: Colors.orange)],
              ),
              new Container(height: 200.0),
              new Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  new MaterialButton(child: new Text("Play"), color: Colors.green, onPressed: (){this.play();}),
                  new MaterialButton(child: new Text("Stop"), color: Colors.red, onPressed: (){RadAudio.stop();}),
                  new MaterialButton(child: new Text("Pause"), color: Colors.yellow, onPressed: (){RadAudio.pause();})
                ],
              ),
              new Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  new MaterialButton(child: new Text("+10s"), color: Colors.blue, onPressed: (){RadAudio.seekDelta(10);}),
                  new MaterialButton(child: new Text("-10s"), color: Colors.blue, onPressed: (){RadAudio.seekDelta(-10);})
                ],
              ),
              new Container(
                height: 50.0,
              ),
              new RadSlider(300.0, 7.0, callback: this.dragStopped, currentPosition: this.sliderValue, backgroundColor: Colors.green),
            ],
          )
        ),
      ),
    );

}
