//
//  BSAudioDevice+Opus.h
//  YXY
//
//  Created by Captain Black on 16/8/30.
//  Copyright © 2016年 Captain Black. All rights reserved.
//

#import "BSAudioDevice.h"

@interface BSAudioDevice (Opus)
/**
 *  采集音频数据并使用opus编码。duration秒之后或者-opus_stopCature被调用立即回调completion。编码参数为sampeRate=16000, channel=1
 *
 *  @param duration   采集最大持续时间
 *  @param completion 采集结束回调
 *
 *  @return 采集是否成功开始
 */
- (BOOL)opus_captureWithMaxDuration:(NSTimeInterval)duration completion:(void(^)(NSData *encodedAudioData, NSError *error))completion;
- (void)opus_stopCapture;
/**
 *  播放PCM音频数据流
 *
 *  @param pcmAudioStream PCM数据流
 *
 *  @return 播放是否成功开始
 */
- (BOOL)opus_playbackWithPCMStream:(NSInputStream*)pcmAudioStream;
/**
 *  播放opus编码过的数据
 *
 *  @param data opus编码过的数据。编码参数为sampleRate=16000, channel=1
 *
 *  @return 播放是否成功开始
 */
- (BOOL)opus_playbackWithEncodedData:(NSData*)data;
- (void)opus_stopPlayback;
@end
