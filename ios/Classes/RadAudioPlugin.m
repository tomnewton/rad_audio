#import "RadAudioPlugin.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>


typedef enum {
    kFileDoesntExist,
    kFileLoadingFailed,
    kPlayerBadState,
    kAssetPropertyLoadingError,
} RadAudioErrors;

typedef enum {
    kPlaybackStopped,
    kReadyToPlay,
    kPlaybackStarted,
    kProgressEvent,
    kPaused,
    kSeekComplete,
    kSeeking,
} RadAudioEventType;


typedef enum {
    kCurrentPlaybackPosition,
    kDuration,
} RadAudioArgKey;

@implementation RadAudioPlugin {
    AVAudioSession* session;
    AVPlayer* player;
    FlutterMethodChannel* channel;
    void (^progressBloc)(CMTime t);
    id timeObserver;
    bool isPaused;
    MPNowPlayingInfoCenter *infoCenter;
    
}



-(NSString*)formatRadAudioEventsToString:(RadAudioEventType)event{
    switch(event){
        case kPlaybackStopped:
            return @"PLAYBACK_STOPPED";
        case kReadyToPlay:
            return @"READY_TO_PLAY";
        case kPlaybackStarted:
            return @"PLAYBACK_STARTED";
        case kProgressEvent:
            return @"PROGRESS";
        case kPaused:
            return @"PLAYBACK_PAUSED";
        case kSeeking:
            return @"SEEKING";
        case kSeekComplete:
            return @"SEEK_COMPLETE";
        default:
            [NSException raise:NSGenericException format:@"Unknown event type"];
    }
}

-(NSString*)FormatRadAudioErrorsToString:(RadAudioErrors)error {
    switch(error){
        case kFileDoesntExist:
            return @"FILE_DOESNT_EXIST";
        case kPlayerBadState:
            return @"PLAYER_BAD_STATE";
        case kFileLoadingFailed:
            return @"FAILED_LOADING_FILE";
        case kAssetPropertyLoadingError:
            return @"ASSET_PROPERTY_LOADING_ERROR";
        default:
            [NSException raise: NSGenericException format:@"Unexpected Error type"];
    }
}

-(NSString*)FormatRadAudioArgKeyToString:(RadAudioArgKey)key{
    switch(key){
        case kCurrentPlaybackPosition:
            return @"CURRENT_PLAYBACK_POSITION";
        case kDuration:
            return @"DURATION";
        default:
            [NSException raise: NSGenericException format:@"Unexpected Arg key"];
    }
}


+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"rad_audio"
                                     binaryMessenger:[registrar messenger]];
    RadAudioPlugin* instance = [[RadAudioPlugin alloc] initWithChannel:channel];
    [registrar addMethodCallDelegate:instance channel:channel];
    
    [registrar addApplicationDelegate:instance];
}

-(void)applicationWillResignActive:(UIApplication *)application{
    if (player == nil){
        NSLog(@"iOS [session setActive:false]");
        NSError* error;
        [session setActive:false error:&error];
    }
}

-(id)initWithChannel:(FlutterMethodChannel*)chan{
    if ( self = [super init] )
    {
        channel = chan;
        infoCenter = [MPNowPlayingInfoCenter defaultCenter];
        
        __weak RadAudioPlugin *weakSelf = self;
        progressBloc = ^(CMTime t){
            [weakSelf updatePlaybackPosition:t];
        };
        
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleInterruption:) name:AVAudioSessionInterruptionNotification object:session];
    }
    return self;
}

-(void)setupAudioSession{
    if ( session == nil ){
        session = [AVAudioSession sharedInstance];
        
        NSError* error;
        [session setCategory:AVAudioSessionCategoryPlayback error:&error];
        
        if (error != nil){
            @throw [NSException
                    exceptionWithName:NSGenericException
                    reason:@"Couldnt start audio session"
                    userInfo:nil];
        }
      
        
        [session setActive:YES error:&error];
        if (error != nil){
            @throw [NSException
                    exceptionWithName:NSGenericException
                    reason:@"Couldnt start audio session"
                    userInfo:nil];
        }
    }
}

-(void)setupCommandCenter{
    MPRemoteCommandCenter* cc = [MPRemoteCommandCenter sharedCommandCenter];
    cc.pauseCommand.enabled = true;
    [cc.pauseCommand addTarget:self action:@selector(pause)];
    cc.playCommand.enabled = true;
    [cc.playCommand addTarget:self action:@selector(play)];
    
    cc.skipForwardCommand.enabled = true;
    [cc.skipForwardCommand addTarget:self action:@selector(seekForwardFromRemote)];
    
    cc.skipBackwardCommand.enabled = true;
    cc.skipBackwardCommand.preferredIntervals = [NSArray arrayWithObject:[NSNumber numberWithInt:15]];
    [cc.skipBackwardCommand addTarget:self action:@selector(seekBackwardFromRemote)];
    
    cc.nextTrackCommand.enabled = NO;
    cc.previousTrackCommand.enabled = NO;
 
}

-(void)seekForwardFromRemote{
    [self seekDelta:[NSNumber numberWithInt:15]];
}

-(void)seekBackwardFromRemote{
    [self seekDelta:[NSNumber numberWithInt:-15]];
}


-(void)setupNotifications{
    NSNotificationCenter* nCenter = [NSNotificationCenter defaultCenter];
    [nCenter addObserver:self selector:@selector(handleInterruption:) name:AVAudioSessionInterruptionNotification object:nil];
    [nCenter addObserver:self selector:@selector(handleTimeJumped:) name:AVPlayerItemTimeJumpedNotification object:nil];
    [nCenter addObserver:self selector:@selector(handleDidFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [nCenter addObserver:self selector:@selector(handlePlaybackStalled:) name:AVPlayerItemPlaybackStalledNotification object:nil];
}

-(void)handleInterruption:(NSNotification*)note{
    NSLog(@"Audio interrputed");
    NSDictionary *info = note.userInfo;
    
    AVAudioSessionInterruptionType type = [info[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    
    if ( type == AVAudioSessionInterruptionTypeBegan ){
        //assuming audio will stop playing automagically... soo....
        [self sendEventToFlutter:kPaused];
    } else {
        // handle AVAudioSessionInterruptionTypeEnded
        [self sendEventToFlutter:kPlaybackStarted];
    }
}

-(void)handleDidPlayToEnd:(NSNotification*)note{
    [self stop];
}

-(void)handleTimeJumped:(NSNotification* )note{
    NSLog(@"TimeDidJump");
}

-(void)handleDidFinishPlaying:(NSNotification*)note{
    NSLog(@"DidFinishPlaying");
}

-(void)handlePlaybackStalled:(NSNotification*)note{
    NSLog(@"Playback stalled...");
}


- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ( [@"prepareToPlay" isEqualToString:call.method]){
        [self handlePrepareToPlayWithFlutterCall:call];
    } else if ([@"play" isEqualToString:call.method]){
        [self play];
    } else if ([@"stop" isEqualToString:call.method]){
        [self stop];
    } else if ([@"pause" isEqualToString:call.method]){
        [self pause];
    } else if ([@"seekDelta" isEqualToString:call.method]){
        [self seekDelta:call.arguments[0]];
    } else if ([@"seekToTime" isEqualToString:call.method]){
        [self seekToTime:call.arguments[0]];
    }
    else {
        result(FlutterMethodNotImplemented);
    }
}

-(void)seekToTime:(NSNumber*)timeInSeconds {
    __weak RadAudioPlugin *weakSelf = self;
    CMTime t = CMTimeMakeWithSeconds([timeInSeconds floatValue], [player currentTime].timescale);
    [player seekToTime:t completionHandler:^(BOOL finished){
        if (finished) {
            //[weakSelf updateControllerElapsedTime:YES];
            
            [weakSelf sendEventToFlutter:kSeekComplete
                           withArguments:[NSDictionary dictionaryWithObjectsAndKeys:timeInSeconds, [self FormatRadAudioArgKeyToString:kCurrentPlaybackPosition], nil]];
        } else {
            [weakSelf sendEventToFlutter:kSeeking];
        }
    }];
}

-(void)updateControllerElapsedTime:(BOOL)isPlaying{
    NSMutableDictionary *nfo = [NSMutableDictionary dictionaryWithDictionary:[[MPNowPlayingInfoCenter defaultCenter] nowPlayingInfo]];
    
    NSLog(@"Update wtih new time: %f s", CMTimeGetSeconds([player currentTime]));
    [nfo setObject:[NSNumber numberWithDouble:CMTimeGetSeconds([player currentTime])] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
  
    if(isPlaying){
        [nfo setObject:[NSNumber numberWithInt:1] forKey:MPNowPlayingInfoPropertyPlaybackRate];
    } else {
        [nfo setObject:[NSNumber numberWithInt:0] forKey:MPNowPlayingInfoPropertyPlaybackRate];
    }
    
    [infoCenter setNowPlayingInfo:nfo];
}

-(void)seekDelta:(NSNumber*)delta {
    Float64 now = CMTimeGetSeconds([player currentTime]);
    Float64 then = now + [delta floatValue];
    
    CMTime newTime = CMTimeMakeWithSeconds(then, [player currentTime].timescale);
    
    __weak RadAudioPlugin *weakSelf = self;
    
    if ( CMTimeGetSeconds(newTime) <= 1 ){
        newTime = kCMTimeZero;
    }
    
    [player seekToTime:newTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished){
        if ( finished ){
                [weakSelf updateControllerElapsedTime:YES];
                [weakSelf sendEventToFlutter:kSeekComplete
                               withArguments:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:newTime.value/newTime.timescale], [self FormatRadAudioArgKeyToString:kCurrentPlaybackPosition], nil]];
            
        } else {
            // tell flutter still seeking...
            [weakSelf sendEventToFlutter:kSeeking];
        }
    }];
}

-(void)play{
    if ( session == nil ){
        [self setupAudioSession];
        [self setupCommandCenter];
    }
    
    [self updateControllerElapsedTime:YES];
    
    if(@available(iOS 11, *)){
        [infoCenter setPlaybackState:MPNowPlayingPlaybackStatePlaying];
    }
    
    if ( isPaused ){
        [player setRate:1.0f];
        isPaused = false;
        [self sendEventToFlutter:kPlaybackStarted];
        return;
    }
    
    [player play];
    
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    
    CMTime interval = CMTimeMakeWithSeconds(0.5, NSEC_PER_SEC);
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    
    [self sendEventToFlutter:kPlaybackStarted withArguments:nil];
    
    if ( timeObserver == nil ){
        timeObserver = [player addPeriodicTimeObserverForInterval:interval queue:mainQueue usingBlock:progressBloc];
    }
}




-(void)stop{
    if ( player.error == false ){
        [player pause];
        if ( timeObserver != nil ){
            [player removeTimeObserver:timeObserver];
            timeObserver = nil;
        }
        player = nil;
        [self sendEventToFlutter:kPlaybackStopped];
        
        if(@available(iOS 11, *)){
            [infoCenter setPlaybackState:MPNowPlayingPlaybackStateStopped];
        }
        
        [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
        
        return;
    }
    
    //Send an error.
    [self sendErrorMessageToFlutter:@"Couldn't stop the player. Either not playing or player.error was true." andCode:kPlayerBadState];
}

-(void)pause {
    if (player.rate > 0 && player.error == false){
        [player pause];
        isPaused = true;
       
        [self updateControllerElapsedTime:NO];
        if(@available(iOS 11, *)){
            [infoCenter setPlaybackState:MPNowPlayingPlaybackStatePaused];
        }
        
        [self sendEventToFlutter:kPaused withArguments:nil];
        
    } else {
        [self sendErrorMessageToFlutter:@"Pause when nothing is playing" andCode:kPlayerBadState];
    }
}

-(void)handlePrepareToPlayWithFlutterCall:(FlutterMethodCall*)call {
    if (player.rate > 0){
        [self stop];
    }
    
    NSDictionary* args = call.arguments[0];
    
    AVAsset* asset;
    
    NSString* audioUri = [args objectForKey:@"audioUri"];
    if ( [audioUri hasPrefix:@"http"] ){
        asset = [AVAsset assetWithURL:[NSURL URLWithString:audioUri]];
    } else {
        asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:audioUri]];
    }
    
    NSArray<NSString*>* assetKeys =
        [NSArray arrayWithObjects:@"duration", @"playable", @"providesPreciseDurationAndTiming", nil];
    
    AVPlayerItem* item = [AVPlayerItem playerItemWithAsset:asset automaticallyLoadedAssetKeys:assetKeys];
    
    player = [AVPlayer playerWithPlayerItem:item];
    if(@available(iOS 10.0, *)){
        [player setAutomaticallyWaitsToMinimizeStalling:false];
    }
    
    //listen for when the playback has ended for the current item.
     [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:player.currentItem];
    
    MPMediaItemArtwork *artwork;
    
    if ( [args objectForKey:@"imageUri"] != nil && ![@"" isEqualToString:[args objectForKey:@"imageUri"]]){
        UIImage* img = [UIImage imageWithContentsOfFile:[args objectForKey:@"imageUri"]];
        artwork = [[MPMediaItemArtwork alloc] initWithImage:img];
    }
    __weak RadAudioPlugin *weakSelf = self;
    
    [asset loadValuesAsynchronouslyForKeys:assetKeys completionHandler:^(void){
        NSError* error;
        
        bool isPlayable = false;
        float duration = -1;
        
        bool readPropertyPreciseTiming;
        bool providesPreciseTiming;
        
        AVKeyValueStatus status = [asset statusOfValueForKey:@"playable" error:&error];
        switch (status) {
            case AVKeyValueStatusLoaded:
                NSLog(@" %s", [asset isPlayable] ? "isPlayable: true" : "isPlayable: false");
                if ( [asset isPlayable] == YES ){
                    isPlayable = true;
                }
                break;
            case AVKeyValueStatusFailed:
                [weakSelf sendErrorMessageToFlutter:@"isPlayableFailed" andCode:kAssetPropertyLoadingError];
                break;
            case AVKeyValueStatusLoading:
                NSLog(@"AVKeyValueStatusLoading");
                break;
            case AVKeyValueStatusCancelled:
                NSLog(@"AVKeyValueStatusCancelled");
                break;
            default:
                break;
        }
        
        status = [asset statusOfValueForKey:@"providesPreciseDurationAndTiming" error:&error];
        switch (status) {
            case AVKeyValueStatusLoaded:
                NSLog(@" %s", [asset providesPreciseDurationAndTiming] ? "preciseTiming?: true" : "preciseTiming?: false");
                readPropertyPreciseTiming = true;
                providesPreciseTiming = asset.providesPreciseDurationAndTiming;
                break;
            case AVKeyValueStatusFailed:
                NSLog(@"providesPreciseDurationAndTiming: AVKeyValueStatusFailed");
                [weakSelf sendErrorMessageToFlutter:@"providesPreciseDurationAndTiming Failed." andCode:kAssetPropertyLoadingError];
                break;
            case AVKeyValueStatusLoading:
                NSLog(@"providesPreciseDurationAndTiming AVKeyValueStatusLoading");
            case AVKeyValueStatusCancelled:
                NSLog(@"providesPreciseDurationAndTiming: AVKeyValueStatusCancelled.");
                break;
            default:
                break;
        }
        
        status = [asset statusOfValueForKey:@"duration" error:&error];
        switch (status) {
            case AVKeyValueStatusLoaded:
                duration = CMTimeGetSeconds([asset duration]);
               NSLog(@"%.2f", duration);
                break;
            case AVKeyValueStatusFailed:
                NSLog(@"Error: %@ %@", error, [error userInfo]);
                NSLog(@"duration: failed");
                break;
            case AVKeyValueStatusLoading:
                NSLog(@"duration: AVKeyValueStatusLoading");
            case AVKeyValueStatusCancelled:
                NSLog(@"duration: AVKeyValueStatusCancelled.");
                break;
            default:
                break;
        }
        
        if ( isPlayable ){
            
            [infoCenter setNowPlayingInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [args objectForKey:@"titleText"], MPMediaItemPropertyTitle,
                                           [args objectForKey:@"subtitleText"], MPMediaItemPropertyArtist,
                                           [NSNumber numberWithFloat:duration], MPMediaItemPropertyPlaybackDuration,
                                           artwork, MPMediaItemPropertyArtwork, nil]];
            
            [weakSelf sendEventToFlutter:kReadyToPlay
                           withArguments:[NSDictionary dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithFloat:duration], [self FormatRadAudioArgKeyToString:kDuration], nil]];
        }
        
    }];
}


-(void)sendErrorMessageToFlutter:(NSString *)errorMessage andCode:(RadAudioErrors)code {
    [FlutterError
     errorWithCode: [self FormatRadAudioErrorsToString:code]
     message:errorMessage
     details:nil];
}

-(void)sendEventToFlutter:(RadAudioEventType)eventType{
    [self sendEventToFlutter:eventType withArguments:nil];
}

-(void)sendEventToFlutter:(RadAudioEventType)eventType withArguments:(nullable NSDictionary*)args {
    NSMutableDictionary *toFlutter = [NSMutableDictionary dictionaryWithDictionary:
   @{
     @"EVENT_TYPE": [self formatRadAudioEventsToString:eventType],
     }];
    [toFlutter addEntriesFromDictionary:args];
    
    [channel invokeMethod:@"event" arguments:toFlutter result:nil];
}

-(void)handleGetPlatformVersionWithResult:(FlutterResult)result {
    result([@"Toms Plugin...iOS" stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
}

-(void)updatePlaybackPosition:(CMTime)time{
    Float64 seconds = CMTimeGetSeconds(time);  //=seconds.
    [self sendEventToFlutter:kProgressEvent withArguments:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:seconds], [self FormatRadAudioArgKeyToString:kCurrentPlaybackPosition], nil]];
}

@end
