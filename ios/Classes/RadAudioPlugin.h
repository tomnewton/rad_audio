#import <Flutter/Flutter.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

@interface RadAudioPlugin : NSObject<FlutterPlugin>

@property(nonatomic, copy, nullable) void(^progressBloc)(CMTime t);
@property(nonatomic, retain, nonnull) AVAudioSession* session;
@property(nonatomic, retain) AVPlayer* player;
@property(nonatomic, retain) FlutterMethodChannel* channel;
@property(nonatomic, retain) MPNowPlayingInfoCenter* infoCenter;
@property(nonatomic, retain) id timeObserver;
@property(nonatomic, assign) BOOL isPaused;

@end
