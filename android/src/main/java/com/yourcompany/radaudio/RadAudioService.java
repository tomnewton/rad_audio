
package com.yourcompany.radaudio;

import android.app.Activity;
import android.app.Application;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.media.AudioAttributes;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.os.Binder;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;

import android.net.Uri;
import android.support.annotation.Nullable;
import android.support.v4.app.NotificationCompat;
import android.support.v4.media.MediaMetadataCompat;
import android.support.v4.media.app.NotificationCompat.MediaStyle;
import android.support.v4.media.session.MediaControllerCompat;
import android.support.v4.media.session.MediaSessionCompat;
import android.support.v4.media.session.PlaybackStateCompat;
import android.util.Log;


import io.flutter.app.FlutterActivity;
import io.flutter.app.FlutterApplication;



public class RadAudioService extends Service implements
        MediaPlayer.OnPreparedListener,
        MediaPlayer.OnCompletionListener,
        MediaPlayer.OnErrorListener{

    public static final String TAG = "RadAudioService";

    public static final String ACTION_STARTUP = "action_startup";
    public static final String ACTION_PLAY = "action_play";
    public static final String ACTION_PAUSE = "action_pause";
    public static final String ACTION_REWIND = "action_rewind";
    public static final String ACTION_FAST_FORWARD = "action_fast_foward";
    public static final String ACTION_STOP = "action_stop";

    private static final String NOTIFICATION_CHANNEL_ID = "RAD_DEFAULT";

    public static final long SKIP_DELTA = 10000L;

    private final IBinder audioBinder = new RadAudioServiceBinder();
    final Handler mProgressHandler = new Handler();


    MediaSessionCompat mSession;
    MediaPlayer mPlayer;
    int lastPlayerPosition;
    boolean isPaused;
    private RadAudioServiceCallbacks callbacks;
    NotificationChannel mNotificationChannel;

    @Override
    public void onCreate(){
        super.onCreate();
        initPlayer();
        initSession();
        initChannels();
    }


    private void initPlayer(){
        mPlayer = new MediaPlayer();

        if (Build.VERSION.SDK_INT >= 21) {
            mPlayer.setAudioAttributes(new AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .setLegacyStreamType(AudioManager.STREAM_MUSIC)
                    .build());
        } else {
            mPlayer.setAudioStreamType(AudioManager.STREAM_MUSIC);
        }
        mPlayer.setOnPreparedListener(this);
        mPlayer.setOnCompletionListener(this);
        mPlayer.setOnErrorListener(this);
    }

    private void initSession(){
        mSession = new MediaSessionCompat(this.getApplicationContext(), "RadAudioMediaSession");
        mSession.setFlags(MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS| MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS);
        mSession.setCallback(mSessionCallback);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if ( mPlayer == null  ){
            initPlayer();
        }
        if (mSession == null ){
            initSession();
        }

        handleIntent(intent);

        return START_STICKY;
    }

    public void clearNotifications(){

        if (mSession != null && mSession.isActive()){
            return;
        }
        NotificationManager nm = (NotificationManager) getApplicationContext().getSystemService(Context.NOTIFICATION_SERVICE);
        if ( nm != null ) {
            nm.cancelAll();
        }
    }

    private NotificationCompat.Action generateAction(int icon, String title, String intentAction){
        Intent intent = new Intent( getApplicationContext(), RadAudioService.class );
        intent.setAction( intentAction );
        PendingIntent pendingIntent = PendingIntent.getService(getApplicationContext(), 1, intent, 0);
        return new NotificationCompat.Action.Builder( icon, title, pendingIntent ).build();
    }

    private void buildNotification(NotificationCompat.Action action) {
        MediaStyle style = new MediaStyle();
        style.setMediaSession(mSession.getSessionToken());

        Intent intent = new Intent(getApplicationContext(), RadAudioService.class);
        intent.setAction(ACTION_STOP);
        PendingIntent pendingIntent = PendingIntent.getService(getApplicationContext(), 1, intent, 0);

        Intent contentIntent = new Intent(getApplicationContext(), FlutterActivity.class);
        PendingIntent contentPendingIntent = PendingIntent.getActivity(getFlutterActivity(), 1, contentIntent, 0);

        MediaMetadataCompat meta = mSession.getController().getMetadata();

        NotificationCompat.Builder builder = new NotificationCompat.Builder(getApplicationContext(), NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(meta.getString(MediaMetadataCompat.METADATA_KEY_TITLE))
                .setContentText(meta.getString(MediaMetadataCompat.METADATA_KEY_AUTHOR))
                .setLargeIcon(meta.getBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART))
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setColorized(true)
                .setShowWhen(false)
                .setDeleteIntent(pendingIntent)
                .setContentIntent(contentPendingIntent)
                .setDefaults(0)
                .setStyle(style);


        builder.addAction( generateAction( R.drawable.ic_replay_10_black_32dp, "Rewind", ACTION_REWIND ) );
        builder.addAction( action );
        builder.addAction( generateAction( R.drawable.ic_forward_10_black_32dp, "Fast Foward", ACTION_FAST_FORWARD ) );

        startForeground(1, builder.build());
    }


    private void handleIntent(Intent intent){
        if ( intent == null || intent.getAction() == null ){
            return;
        }

        String action = intent.getAction();

        if ( action.equalsIgnoreCase(ACTION_PLAY)){
            mSession.getController().getTransportControls().play();
        } else if (action.equalsIgnoreCase(ACTION_PAUSE)){
            mSession.getController().getTransportControls().pause();
        } else if ( action.equalsIgnoreCase(ACTION_STOP) ){
            mSession.getController().getTransportControls().stop();
        } else if (action.equalsIgnoreCase(ACTION_FAST_FORWARD)){
            mSession.getController().getTransportControls().seekTo(mPlayer.getCurrentPosition()+SKIP_DELTA);
        } else if (action.equalsIgnoreCase((ACTION_REWIND))){
            mSession.getController().getTransportControls().seekTo(mPlayer.getCurrentPosition()-SKIP_DELTA);
        }
    }


    @Override
    public IBinder onBind(Intent intent) {
        return audioBinder;
    }

    @Override
    public boolean onUnbind(Intent intent){
        if ( mPlayer.isPlaying() ) {
            mPlayer.stop();
            mPlayer.reset();
            mSession.setActive(false);
            mSession.release();
        }
        return false;
    }


    public void play(){
        if (mSession.isActive() == false ) {
            mSession.setActive(true);
        }
        NotificationCompat.Action pause = generateAction(R.drawable.ic_pause_black_32dp, "Pause", ACTION_PAUSE);
        buildNotification(pause);

        mPlayer.setOnSeekCompleteListener( new MediaPlayer.OnSeekCompleteListener(){
            public void onSeekComplete(MediaPlayer mp){
                mp.start();
                mProgressHandler.post(sendProgress);
            }
        });

        if ( isPaused ){
            mPlayer.seekTo(lastPlayerPosition);
        } else {
            mPlayer.seekTo(0);
        }
    }

    private final Runnable sendProgress = new Runnable(){
      public void run(){
          if ( mPlayer != null && mPlayer.isPlaying() ){
              callbacks.progress(mPlayer.getCurrentPosition());
              mProgressHandler.postDelayed(this, 500);
          }
      }
    };


    public void prepareToPlay(Uri uri){
        if (mSession == null){
            initSession();
        }
        if (mPlayer == null){
            initPlayer();
        }

        try {

            mPlayer.setOnPreparedListener(this);
            mPlayer.setDataSource(uri.toString());


        } catch(Exception e){
            Log.e("RadMusicService", "Error setting dataSource", e);
        }
        mPlayer.prepareAsync();
    }

    public void seekTo(long pos){
        mPlayer.seekTo((int)pos);
        mPlayer.setOnSeekCompleteListener( new MediaPlayer.OnSeekCompleteListener(){
            public void onSeekComplete(MediaPlayer mp){
                mp.start();
            }
        });
    }

    public void stop(){
        mProgressHandler.removeCallbacks(sendProgress);
        mPlayer.stop();
        isPaused = false;
        lastPlayerPosition = 0;
        mPlayer.reset();
        mPlayer = null;
        mSession.setActive(false);
        mSession.release();
        stopForeground(true);
    }

    public void pause(){
        NotificationCompat.Action play = generateAction(R.drawable.ic_play_arrow_black_32dp, "Play", ACTION_PLAY);
        buildNotification(play);

        mPlayer.pause();
        lastPlayerPosition = mPlayer.getCurrentPosition();
        isPaused = true;
    }

    @Override
    public void onCompletion(MediaPlayer mp) {

        //TODO: when we allow playlists... we'll need to move to the next item in the queue.
        mSession.getController().getTransportControls().stop();
    }

    @Override
    public boolean onError(MediaPlayer mp, int what, int extra) {
        Log.e(TAG, "Error loading mp3.");
        return false;
    }

    @Override
    public void onPrepared(MediaPlayer mp) {
        //mSession.getController().getTransportControls().play();
        callbacks.playbackReady(mp.getDuration());
    }


    class RadAudioServiceBinder extends Binder {
        RadAudioService getService(){
            return RadAudioService.this;
        }
    }

    public MediaSessionCompat.Token getSessionToken(){
       return this.mSession.getSessionToken();
    }

    public void setCallbacks(RadAudioServiceCallbacks callbacks){
        this.callbacks = callbacks;
    }

    public void registerControllerCallback(MediaControllerCompat.Callback callback){
        mSession.getController().registerCallback(callback);
    }

    public interface RadAudioServiceCallbacks {
        void playbackReady(int duration);
        void progress(int currentPosition);
    }


    private
    MediaSessionCompat.Callback mSessionCallback = new MediaSessionCompat.Callback() {

        private PlaybackStateCompat.Builder _builder = new PlaybackStateCompat.Builder();

        @Override
        public boolean onMediaButtonEvent(Intent mediaButtonEvent) {
            return super.onMediaButtonEvent(mediaButtonEvent);
        }

        @Override
        public void onPrepareFromUri(Uri uri, Bundle extras) {
            RadAudioService.this.prepareToPlay(uri);
            mSession.setPlaybackState(
                    _builder
                            .setState(PlaybackStateCompat.STATE_CONNECTING, 0L, 0.0f)
                            .build()
            );
        }

        @Override
        public void onPlay() {
            RadAudioService.this.play();
            mSession.setPlaybackState(
                    _builder
                            .setState(PlaybackStateCompat.STATE_PLAYING, mPlayer.getCurrentPosition(), 1.0f)
                            .build()
            );
        }

        @Override
        public void onPlayFromUri(Uri uri, Bundle extras) {}

        @Override
        public void onPause() {
            RadAudioService.this.pause();
            mSession.setPlaybackState(
                    _builder
                    .setState(PlaybackStateCompat.STATE_PAUSED, mPlayer.getCurrentPosition(), 0.0f)
                    .build()
            );
        }

        @Override
        public void onStop() {
            mSession.setPlaybackState(
                    _builder
                            .setState(PlaybackStateCompat.STATE_STOPPED, mPlayer.getCurrentPosition(), 0.0f)
                            .build()
            );
            RadAudioService.this.stop();
        }

        @Override
        public void onSeekTo(long pos) {
            RadAudioService.this.seekTo(pos);
            mSession.setPlaybackState(
                    _builder
                            .setState(PlaybackStateCompat.STATE_PLAYING, mPlayer.getCurrentPosition(), 0.0f)
                            .build()
            );
        }

    };

    public void initChannels() {
        if (Build.VERSION.SDK_INT < 26) {
            return;
        }
        Context context = this.getApplicationContext();
        NotificationManager notificationManager =
                (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        mNotificationChannel = new NotificationChannel(NOTIFICATION_CHANNEL_ID,
                "RadAudioService",
                NotificationManager.IMPORTANCE_DEFAULT);
        mNotificationChannel.setDescription("RadAudioService channel.");
        mNotificationChannel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
        if( notificationManager != null ) {
            notificationManager.createNotificationChannel(mNotificationChannel);
        }
    }

    @Nullable
    private FlutterActivity getFlutterActivity(){
        Application app = (Application) getApplicationContext();
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

    @Override
    public void onDestroy(){
        mProgressHandler.removeCallbacks(sendProgress);
        if ( mPlayer.isPlaying() ) {
            this.mPlayer.stop();
        }
        this.mPlayer = null;

        if ( mSession.isActive() ) {
            this.mSession.setActive(false);
        }
        this.mSession.release();
        this.mSession = null;

        if (Build.VERSION.SDK_INT >= 26) {
            Context context = this.getApplicationContext();
            NotificationManager notificationManager =
                    (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);

            if (notificationManager != null) {
                notificationManager.deleteNotificationChannel(NOTIFICATION_CHANNEL_ID);
            }
        }
        clearNotifications();
        this.stopForeground(true);
    }
}