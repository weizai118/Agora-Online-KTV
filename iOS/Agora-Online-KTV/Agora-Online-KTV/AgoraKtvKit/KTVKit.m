//
//  KTVKit.m
//  Agora-Online-KTV
//
//  Created by zhanxiaochao on 2018/9/20.
//  Copyright © 2018年 Agora. All rights reserved.
//

#import "KTVKit.h"
#import <IJKMediaFramework/IJKMediaFramework.h>
#import "AgoraAudioFrame.h"

@interface KTVKit()
{
    UIView *_containerView;
    BOOL isChangeAudio;
    AgoraRtcEngineKit *_rtcEngine;
    BOOL isLoadSuccess;
}
@property(nonatomic, strong) id<IJKMediaPlayback> player;

@end
@implementation KTVKit
+ (instancetype)shareInstance{
    
    static dispatch_once_t once;
    static KTVKit *sharedInstance;
    dispatch_once(&once, ^{
        if (sharedInstance == NULL) {
            
            sharedInstance = [[self alloc] init];
        }
    });
    return sharedInstance;
    
}
-(void)createKTVKit:(NSString *)videoPath withView:(UIView *)view rtcEngine:(nonnull AgoraRtcEngineKit *)rtcEngine withsampleRate:(int)sampleRate
{
    _rtcEngine = rtcEngine;
    [[AgoraAudioFrame shareInstance] registerEngineKit:_rtcEngine];
    
    [_rtcEngine setParameters:@"{\"che.video.keep_prerotation\":false}"];
    [_rtcEngine setParameters:@"{\"che.video.local.camera_index\":1025}"];
    
    //初始化之后加入频道之前开启耳返
    [_rtcEngine enableInEarMonitoring:true];
    
    [_rtcEngine setRecordingAudioFrameParametersWithSampleRate:sampleRate channel:2 mode:AgoraAudioRawFrameOperationModeReadWrite samplesPerCall:sampleRate * 0.01 * 2];
    [_rtcEngine setPlaybackAudioFrameParametersWithSampleRate:sampleRate channel:2 mode:AgoraAudioRawFrameOperationModeReadWrite samplesPerCall:sampleRate * 0.01 * 2];
    //开启说话人检测功能
    [_rtcEngine enableAudioVolumeIndication:200 smooth:3];
    //加入房间
    [_rtcEngine setExternalVideoSource:true useTexture:false pushMode:true];
    [_rtcEngine setVideoResolution:CGSizeMake(640, 360) andFrameRate:15 bitrate:620];
    [_rtcEngine setParameters:@"{\"che.audio.use.remoteio\":true}"];
    [_rtcEngine setParameters:@"{\"che.audio.keep.audiosession\":true}"];
    [_rtcEngine setLocalVoiceReverbOfType:AgoraAudioReverbDryLevel withValue:0];
    
    [_rtcEngine setLocalVoiceReverbOfType:AgoraAudioReverbWetLevel withValue:4];
    
    [_rtcEngine setLocalVoiceReverbOfType:AgoraAudioReverbRoomSize withValue:60];
    
    [_rtcEngine setLocalVoiceReverbOfType:AgoraAudioReverbWetDelay withValue:18];
    
    [_rtcEngine setLocalVoiceReverbOfType:AgoraAudioReverbStrength withValue:80];
    [AgoraAudioFrame shareInstance].sampleRate = sampleRate;
    [self registerNotifications];
    [self initIjkPlayer:videoPath view:view];
}
//切歌
-(void)switchMV:(NSString *)videoPath{
    
    [self initIjkPlayer:videoPath view:_containerView];
}
//获取视频时长
-(double)getDuation{
    return self.player.duration;
}
//获取当前的视频位置
-(float)getCurrentPosition{
    return self.player.currentPlaybackTime/self.player.duration;
}
//原唱伴奏切换
-(void)switchAudioTrack:(BOOL)isSwitch{
    [self.player changeAudioStream:isSwitch];
}
//调整伴奏音量
-(void)adjustVoiceVolume:(double )volume{
    [AgoraAudioFrame shareInstance].voiceNum = volume;
}
//调整背景音量
-(void)adjustAccompanyVolume:(double)volume{
    
    [AgoraAudioFrame shareInstance].songNum = volume;

}
//视频的播放/暂停
-(void)play{
    [self.player play];
}
-(void)pause{
    [self.player pause];
}
//引擎重启
-(void)resume{
    if (self.player) {
        [self.player pause];
        [self.player stop];
        [self.player shutdown];
        [self.player.view removeFromSuperview];
        self.player = NULL;
    }
}
//初始化ijk
-(void)initIjkPlayer:(NSString *)url view:(UIView *)view{
    _containerView = view;
    isLoadSuccess = false;
    if (self.player) {
        [self.player pause];
        //注意一下切歌的逻辑  切歌时先暂停 执行一个过场动画3~5s  再切歌 这样最好
        [self.player stop];
        [self.player shutdown];
        [[AgoraAudioFrame shareInstance] destroyAudioBuf];
        [self.player.view removeFromSuperview];
        self.player = NULL;
        
    }
    
    //设置伴奏音量默认大小
    [AgoraAudioFrame shareInstance].songNum = 0.5;
    //设置人声音量默认大小
    [AgoraAudioFrame shareInstance].voiceNum = 0.5;

    IJKFFOptions *options = [IJKFFOptions optionsByDefault];
    //开启硬件解码器
    [options setOptionIntValue:1 forKey:@"videotoolbox" ofCategory:kIJKFFOptionCategoryPlayer];
    [options setPlayerOptionIntValue:10 forKey:@"min-frames"];
    //获取视频的地址
    //    self.player = [[IJKFFMoviePlayerController alloc] initWithContentURL:[NSURL URLWithString:@"http://compress.mv.letusmix.com/914184d11605138c7de8c28f2905c63a.mp4"] withOptions:options];
    self.player = [[IJKFFMoviePlayerController alloc] initWithContentURL:[NSURL URLWithString:url] withOptions:options];
    self.player.view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.player.view.frame = view.bounds;
    self.player.scalingMode = IJKMPMovieScalingModeFill;
    self.player.shouldAutoplay = false;
    view.autoresizesSubviews = YES;
    [view addSubview:self.player.view];
    [self.player prepareToPlay];
}
-(void)registerRTCEngine:(AgoraRtcEngineKit *)rtcEngine{
    _rtcEngine = rtcEngine;
}
-(void)registerNotifications{
    //注册引擎回调
    [[AgoraAudioFrame shareInstance] registerEngineKit:_rtcEngine];
    //注册音频回调通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ijk_Audio_CallBack:) name:@"ijk_Audio_CallBack" object:nil];
    //注册视频回调通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ijk_video_CallBack:) name:@"ijk_video_CallBack" object:nil];
    //注册音频回调通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(PlaybackDidFinish:) name:IJKMPMoviePlayerPlaybackDidFinishNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadMVSuccess) name:IJKMPMediaPlaybackIsPreparedToPlayDidChangeNotification object:nil];
    
}
-(void)ijk_video_CallBack:(NSNotification *)notification{
    
    CVPixelBufferRef buffer = (__bridge CVPixelBufferRef)(notification.object);
    AgoraVideoFrame *videoFrame = [[AgoraVideoFrame alloc] init];
    videoFrame.format = 12;
    videoFrame.time = CMTimeMake(CACurrentMediaTime()*1000, 1000);
    videoFrame.textureBuf = buffer;
    [_rtcEngine pushExternalVideoFrame:videoFrame];
    
}
//得到音频数据的处理
-(void)ijk_Audio_CallBack:(NSNotification *)notification
{
    NSData *data = notification.object;
    char * p = (char *)[data bytes];
    if (isLoadSuccess) {
        [[AgoraAudioFrame shareInstance] pushAudioSource:p byteLength:data.length];
    }
}
//播放完成回调
-(void)PlaybackDidFinish:(NSNotification *)not{
    NSLog(@"%@",not.userInfo);
    if (self.delegate && [self.delegate respondsToSelector:@selector(loadMVSuccess)]) {
        [self.delegate ktvStatusCallBack:KTVStatusTypeCompleted];
    }
    
}
-(void)removeNotifications{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"ijk_Audio_CallBack" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"ijk_video_CallBack" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:IJKMPMoviePlayerPlaybackDidFinishNotification object:nil];
}
-(void)destroyKTVKit
{
    [self resume];
    [self removeNotifications];
}
-(void)loadMVSuccess{
    isLoadSuccess = true;
    if (self.delegate && [self.delegate respondsToSelector:@selector(ktvStatusCallBack:)]) {
        [self.delegate ktvStatusCallBack:KTVStatusTypePrepared];
    }
}

@end