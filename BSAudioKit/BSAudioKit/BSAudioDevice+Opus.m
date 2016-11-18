//
//  BSAudioDevice+Opus.m
//  YXY
//
//  Created by Captain Black on 16/8/30.
//  Copyright © 2016年 Captain Black. All rights reserved.
//

#import "BSAudioDevice+Opus.h"
#import <objc/runtime.h>
#import <opus/opus.h>
#import "BSRingBuffer.h"

#define SAMPLE_RATE 16000
#define CHANNEL_COUNT 1

@interface BSAudioDevice (OpusEncode_Private)
@property (nonatomic, strong) BSRingBuffer *circularBuffer;
@property (nonatomic, strong) void (^recordingCompletion)(NSData *encodedAudioData, NSError *error);
@end

@implementation BSAudioDevice (Opus)

static const char circularBufferKey;
- (BSRingBuffer *)circularBuffer {
    BSRingBuffer *_circularBuffer = objc_getAssociatedObject(self, &circularBufferKey);
    if (!_circularBuffer) {
        _circularBuffer = [[BSRingBuffer alloc] init];
        objc_setAssociatedObject(self, &circularBufferKey, _circularBuffer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return _circularBuffer;
}

- (void)setCircularBuffer:(BSRingBuffer *)circularBuffer {
    objc_setAssociatedObject(self, &circularBufferKey, circularBuffer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static const char recordingCompletionKey;
- (void (^)(NSData *, NSError *))recordingCompletion {
    return objc_getAssociatedObject(self, &recordingCompletionKey);
}

- (void)setRecordingCompletion:(void (^)(NSData *, NSError *))recordingCompletion {
    objc_setAssociatedObject(self, &recordingCompletionKey, recordingCompletion, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark -
- (NSData*)encodedDataFromCirculaBuffer {
    int error;
    AudioStreamBasicDescription ASBD = [self currentCaptureASBD];
    OpusEncoder *enc = opus_encoder_create(ASBD.mSampleRate, ASBD.mChannelsPerFrame, OPUS_APPLICATION_VOIP, &error);
    if (error) {
        return nil;
    }
    opus_encoder_ctl(enc, OPUS_SET_BANDWIDTH(OPUS_BANDWIDTH_WIDEBAND));
    opus_encoder_ctl(enc, OPUS_SET_BITRATE(16000));
    opus_encoder_ctl(enc, OPUS_SET_VBR(1));
    opus_encoder_ctl(enc, OPUS_SET_COMPLEXITY(10));
    opus_encoder_ctl(enc, OPUS_SET_INBAND_FEC(0));
    opus_encoder_ctl(enc, OPUS_SET_FORCE_CHANNELS(OPUS_AUTO));
    opus_encoder_ctl(enc, OPUS_SET_DTX(0));
    opus_encoder_ctl(enc, OPUS_SET_PACKET_LOSS_PERC(0));
    //opus_encoder_ctl(enc, OPUS_GET_LOOKAHEAD(&skip));
    opus_encoder_ctl(enc, OPUS_SET_LSB_DEPTH(16));
    
    NSUInteger samplesIn20ms = 20 * ASBD.mSampleRate / 1000;
    NSUInteger size = samplesIn20ms * ASBD.mBytesPerFrame;
    NSUInteger lResult;
    void *tempBuffer = malloc(size);
    void *encBuffer = malloc(size);
    NSMutableData *data = [NSMutableData data];
    opus_int32 len;
    while (self.circularBuffer.available >= size) {
        lResult = [self.circularBuffer getBytes:tempBuffer length:size];
        len = opus_encode(enc, tempBuffer, (opus_int32)samplesIn20ms, encBuffer, (opus_int32)size);
        if (len <= 0) {
            break;
        }
        Byte nb = len;
        [data appendBytes:&nb length:sizeof(nb)];
        [data appendBytes:encBuffer length:len];
    }
    
    free(tempBuffer);
    free(encBuffer);
    opus_encoder_destroy(enc);
    
    return [data copy];
}

- (NSData*)pcmDataFromEncodedData:(NSData*)encData {
    int error;
    AudioStreamBasicDescription ASBD = [self currentCaptureASBD];
    OpusDecoder *dec = opus_decoder_create(ASBD.mSampleRate, ASBD.mChannelsPerFrame, &error);
    if (error) {
        return nil;
    }
    
    NSUInteger samplesIn20ms = 20 * ASBD.mSampleRate / 1000;
    NSUInteger size = samplesIn20ms * ASBD.mBytesPerFrame;
    
    opus_int32 len;
    NSInputStream *inputStream = [NSInputStream inputStreamWithData:encData];
    [inputStream open];
    void *tempBuffer = malloc(size);
    void *encBuffer = malloc(size);
    NSMutableData *data = [NSMutableData data];
    while (inputStream.hasBytesAvailable) {
        Byte nb;
        [inputStream read:(void*)&nb maxLength:sizeof(nb)];
        len = nb;
        if (len > size) {
            break;
        }
        if (len != [inputStream read:encBuffer maxLength:len]) {
            break;
        }
        len = opus_decode(dec, encBuffer, len, tempBuffer, (opus_int32)samplesIn20ms, 0);
        [data appendBytes:tempBuffer length:len * ASBD.mBytesPerFrame];
    }
    
    free(tempBuffer);
    free(encBuffer);
    opus_decoder_destroy(dec);
    [inputStream close];
    
    return [data copy];
}

- (BOOL)opus_captureWithMaxDuration:(NSTimeInterval)duration completion:(void(^)(NSData *encodedAudioData, NSError *error))completion {
    if (completion) {
        self.recordingCompletion = completion;
        self.circularBuffer.capacity = 2/*bitsPerChannel / 8*/ * SAMPLE_RATE * CHANNEL_COUNT * duration;
    }
    return [self opus_startCapture];
}

- (BOOL)opus_startCapture {
    if (self.isRunning) {
        [self stop];
    }
    __weak typeof(self) wself = self;
    [self setCaptureWithSampleRate:SAMPLE_RATE numberOfChannel:CHANNEL_COUNT callback:^(void *pcmData, UInt32 size) {
        __strong typeof(wself) self = wself;
        [self.circularBuffer addBytes:pcmData length:size];
        if (self.recordingCompletion && self.circularBuffer.isFull) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self opus_stopCapture];
            });
        }
    }];
    //去除播放回调
    [self setPlaybackWithSampleRate:SAMPLE_RATE numberOfChannel:CHANNEL_COUNT callback:nil];
    return [self run];
}

- (void)opus_stopCapture {
    if (self.isRunning) {
        [self stop];
    }
    
    if (self.recordingCompletion) {
        NSData *data = [self encodedDataFromCirculaBuffer];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = nil;
            if (!data) {
                error = [NSError errorWithDomain:@"" code:-1 userInfo:nil];
            }
            self.recordingCompletion(data, error);
            self.recordingCompletion = nil;
        });
    }
    self.circularBuffer = nil;
}

- (BOOL)opus_playbackWithPCMStream:(NSInputStream *)pcmAudioStream {
    if (self.isRunning) {
        [self stop];
    }
    [pcmAudioStream open];
    //去除录音回调
    [self setCaptureWithSampleRate:SAMPLE_RATE numberOfChannel:CHANNEL_COUNT callback:nil];
    __weak typeof(self) wself = self;
    [self setPlaybackWithSampleRate:SAMPLE_RATE numberOfChannel:CHANNEL_COUNT callback:^(void *outPCMData, UInt32 *inoutSize) {
        __strong typeof (wself) self = wself;
        if (!pcmAudioStream.hasBytesAvailable) {
            [pcmAudioStream close];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self opus_stopPlayback];
            });
            *inoutSize = 0;
            return ;
        }
        
        UInt32 neededSize = *inoutSize;
        NSUInteger count = [pcmAudioStream read:outPCMData maxLength:neededSize];
        *inoutSize = (UInt32)count;
    }];
    return [self run];
}

- (BOOL)opus_playbackWithEncodedData:(NSData*)data {
    NSData *pcmData = [self pcmDataFromEncodedData:data];
    NSInputStream *pcmStream = [NSInputStream inputStreamWithData:pcmData];
    return [self opus_playbackWithPCMStream:pcmStream];
}

- (void)opus_stopPlayback {
    if (self.isRunning) {
        [self stop];
    }
}

@end
