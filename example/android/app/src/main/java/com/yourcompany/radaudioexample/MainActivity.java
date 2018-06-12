package com.yourcompany.radaudioexample;

import android.content.Context;
import android.os.Bundle;
import android.util.Log;

import com.yyztom.radaudio.RadAudioService;

import io.flutter.app.FlutterActivity;
import io.flutter.plugins.GeneratedPluginRegistrant;
import io.flutter.view.FlutterNativeView;

import static android.content.ContentValues.TAG;

public class MainActivity extends FlutterActivity {

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    GeneratedPluginRegistrant.registerWith(this);
  }


}
