package com.yourcompany.radaudio;

import android.app.Activity;
import android.app.Application;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.IBinder;
import android.os.RemoteException;
import android.support.v4.media.MediaMetadataCompat;
import android.support.v4.media.session.MediaControllerCompat;
import android.support.v4.media.session.PlaybackStateCompat;
import android.util.Log;

import java.util.ArrayList;
import java.util.HashMap;

import io.flutter.app.FlutterActivity;
import io.flutter.app.FlutterApplication;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * RadAudioPlugin
 */
public class RadAudioPlugin implements MethodCallHandler, RadAudioService.RadAudioServiceCallbacks {
  private static final String TAG = "RadAudioPlugin";

  /**
   * Plugin registration.
   */
  public static void registerWith(Registrar registrar) {
    MethodChannel chan = new MethodChannel(registrar.messenger(), "rad_audio");
    RadAudioPlugin instance = new RadAudioPlugin(registrar, chan);
    chan.setMethodCallHandler(instance);
  }

  private MethodChannel mChannel;
  private RadAudioService mService;
  private Registrar mRegistrar;

  private MediaControllerCompat mController;

  private RadAudioPlugin( Registrar registrar, MethodChannel chan){
    this.mRegistrar = registrar;
    this.mChannel = chan;
    startAudioService(Uri.EMPTY);
  }

  private ServiceConnection audioServiceConnection = new ServiceConnection(){

    @Override
    public void onServiceConnected(ComponentName name, IBinder service) {
      RadAudioService.RadAudioServiceBinder binder = (RadAudioService.RadAudioServiceBinder)service;
      //get service
      mService = binder.getService();
      mService.setCallbacks(RadAudioPlugin.this);
      mService.registerControllerCallback(RadAudioPlugin.this.mControllerCallback);

      try {
        mController = new MediaControllerCompat(RadAudioPlugin.this.getFlutterActivity(), RadAudioPlugin.this.mService.getSessionToken());
      } catch(RemoteException e){
        Log.e(TAG, e.getMessage());
      }
   }

    @Override
    public void onServiceDisconnected(ComponentName name) {
      mController.unregisterCallback(mControllerCallback);
      mController = null;
    }
  };

  private void startAudioService(Uri uri){
    Intent intent = new Intent(RadAudioService.ACTION_STARTUP, uri, getActiveContext(), RadAudioService.class);
    getActiveContext().bindService(intent, audioServiceConnection, Context.BIND_AUTO_CREATE);
  }

  @Override
  public void onMethodCall(MethodCall call, Result result) {
    if (call.method.equalsIgnoreCase("prepareToPlay")) {
      Log.d("plugin", "prepareToPlay");

      @SuppressWarnings("unchecked")
      HashMap<String, String> msg = ((ArrayList<HashMap<String, String>>)call.arguments).get(0);

      Uri uri = Uri.parse(msg.get("audioUri"));
      Uri imageUri = Uri.parse(msg.get("imageUri"));

      Bitmap bmp = BitmapFactory.decodeFile(imageUri.toString());

      if (mService.mSession.isActive() ){
        if ( mService.mPlayer.isPlaying() ) {
          mController.getTransportControls().stop();
        }
        mService.mSession.setActive(false);
      }

      mService.mSession.setMetadata(new MediaMetadataCompat.Builder()
              .putString(MediaMetadataCompat.METADATA_KEY_ALBUM_ART_URI, imageUri.toString())
              .putString(MediaMetadataCompat.METADATA_KEY_TITLE, msg.get("titleText"))
              .putString(MediaMetadataCompat.METADATA_KEY_AUTHOR, msg.get("subtitleText"))
              .putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, bmp)
              .build());


      mController.getTransportControls().prepareFromUri(uri, null);

      result.success(true);
      return;
    }

    if (call.method.equalsIgnoreCase("play")){
      mController.getTransportControls().play();
      result.success(true);
      return;
    }

    if (call.method.equalsIgnoreCase("stop")){
      mController.getTransportControls().stop();
      result.success(true);
      return;
    }
    if (call.method.equalsIgnoreCase("pause")){
      mController.getTransportControls().pause();
      result.success(true);
      return;
    }
    if (call.method.equalsIgnoreCase("seekToTime")){
      long t = ((Integer)((ArrayList)call.arguments).get(0)).longValue();

      mController.getTransportControls().seekTo(t);
      result.success(true);
      return;
    }

    if ( call.method.equalsIgnoreCase("seekDelta")){
      long delta = ((Integer)((ArrayList)call.arguments).get(0)).longValue()*1000;
      long t = mService.mPlayer.getCurrentPosition() + delta;
      mController.getTransportControls().seekTo(t);
      return;
    }

    result.notImplemented();
  }

  public void playbackReady(int duration){
    HashMap<String, Object> args = new HashMap<>();
    args.put("EVENT_TYPE", "READY_TO_PLAY");
    args.put("DURATION", (double)duration );

    mChannel.invokeMethod("event", args);
  }

  public void progress(int position){
    HashMap<String, Object> args = new HashMap<>();
    args.put("EVENT_TYPE", "PROGRESS");
    args.put("CURRENT_PLAYBACK_POSITION", (double)position);

    mChannel.invokeMethod("event", args);
  }



  private Context getActiveContext(){
    return (mRegistrar.activity() != null) ? mRegistrar.activity() : mRegistrar.context();
  }

  private FlutterActivity getFlutterActivity(){
    Application app = (Application) mRegistrar.activeContext().getApplicationContext();
    if(!(app instanceof FlutterApplication)){
      Log.i(TAG, "app was not FlutterApplication.");
      return null;
    }
    FlutterApplication flutterApp = (FlutterApplication) app;
    Activity activity = flutterApp.getCurrentActivity();
    if(activity == null){
      Log.i(TAG, "viewFromAppContext is null?");
      return null;
    }
    if(!(activity instanceof FlutterActivity)){
      Log.i(TAG, "activity is not Flutter Activity...");
      return null;
    }
    return (FlutterActivity)activity;
  }

  private MediaControllerCompat.Callback mControllerCallback = new MediaControllerCompat.Callback() {
    @Override
    public void onPlaybackStateChanged(PlaybackStateCompat state) {
      Log.d(TAG, "playbackStateChanged");
      if ( state.getState() == PlaybackStateCompat.STATE_CONNECTING){
        Log.d(TAG, "Media loading...");
      }
      else if (state.getState() == PlaybackStateCompat.STATE_PLAYING){
        Log.d(TAG, "Media is playing.");
        HashMap<String, Object> args = new HashMap<>();
        args.put("EVENT_TYPE", "PLAYBACK_STARTED");

        mChannel.invokeMethod("event", args);

      }
      else if ( state.getState() == PlaybackStateCompat.STATE_STOPPED){
        Log.d(TAG, "Media is stopped");
        HashMap<String, Object> args = new HashMap<>();
        args.put("EVENT_TYPE", "PLAYBACK_STOPPED");

        mChannel.invokeMethod("event", args);
      }
      else if ( state.getState() == PlaybackStateCompat.STATE_PAUSED){
        Log.d(TAG, "Media paused.");
        HashMap<String, Object> args = new HashMap<>();
        args.put("EVENT_TYPE", "PLAYBACK_PAUSED");

        mChannel.invokeMethod("event", args);
      }
    }
  };
}
