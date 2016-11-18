//
//  BSAudioDevice.h
//  YXY
//
//  Created by Captain Black on 16/8/26.
//  Copyright © 2016年 Captain Black. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface BSAudioDevice : NSObject
@property (nonatomic, readonly) BOOL isRunning;

/**
 *  设置录音回调。在isRunning = YES 状态下不要调用，会引起问题
 *
 *  @param sampleRate 录音采用
 *  @param number     声道数量
 *  @param callback   回调。传nil即取消录音
 *
 *  @return 是否成功
 */
- (BOOL)setCaptureWithSampleRate:(Float64)sampleRate numberOfChannel:(UInt32)number callback:(void(^)(void *pcmData, UInt32 size))callback;

/**
 *  设置播放回调。在isRunning = YES 状态下不要调用，会引起问题
 *
 *  @param sampleRate 播放采样率
 *  @param number     声道数量
 *  @param callback   回调。传nil即取消播放
 *
 *  @return 是否成功
 */
- (BOOL)setPlaybackWithSampleRate:(Float64)sampleRate numberOfChannel:(UInt32)number callback:(void(^)(void *outPCMData, UInt32 *inoutSize))callback;

- (BOOL)run;

- (void)stop;

- (AudioStreamBasicDescription)currentCaptureASBD;
- (AudioStreamBasicDescription)currentPlaybacASBD;

@end
