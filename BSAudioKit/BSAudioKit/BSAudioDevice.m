//
//  BSAudioDevice.m
//  YXY
//
//  Created by Captain Black on 16/8/26.
//  Copyright © 2016年 Captain Black. All rights reserved.
//

#import "BSAudioDevice.h"
#import <AVFoundation/AVFoundation.h>

#define BITS_PER_CHANNEL 16
#define FRAMES_PER_PACKET 1

typedef NS_ENUM(NSInteger, YXYOption) {
    YXYOptionCaptureStreamBasicDescription,
    YXYOptionPlaybackStreamBasicDescription,
    YXYOptionSetSpeekerRoute
};

@interface BSAudioDevice () {
    @package
    void (^_inputCallbackBlock)(void *inPCMData, UInt32 inSize);
    void (^_outputCallbackBlock)(void *outPCMData, UInt32 *inoutSize);
}
@property (nonatomic, readwrite) AudioUnit audioUnit;
@property (nonatomic, readwrite) BOOL isRunning;
@end

OSStatus inputCallback(	void *							inRefCon,
                       AudioUnitRenderActionFlags *	ioActionFlags,
                       const AudioTimeStamp *			inTimeStamp,
                       UInt32							inBusNumber,
                       UInt32							inNumberFrames,
                       AudioBufferList * __nullable	ioData) {
    NSLog(@"input");
    BSAudioDevice *device = (__bridge BSAudioDevice*)inRefCon;
    
    OSStatus status;
    AudioStreamBasicDescription asbd;
    UInt32 size = sizeof(AudioStreamBasicDescription);
    status = AudioUnitGetProperty(device.audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output, inBusNumber, &asbd,
                                  &size);
    if (status != noErr) {
        return status;
    }
    
    AudioBufferList bl;
    ioData = &bl;
    ioData->mNumberBuffers = 1;
    ioData->mBuffers[0].mDataByteSize = asbd.mBytesPerFrame * inNumberFrames;
    ioData->mBuffers[0].mNumberChannels = asbd.mChannelsPerFrame;
    ioData->mBuffers[0].mData = NULL;
    
    status = AudioUnitRender(device.audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData);
    if (status != noErr) {
        return status;
    }
    
    if (device->_inputCallbackBlock) {
        device->_inputCallbackBlock(ioData->mBuffers[0].mData, ioData->mBuffers[0].mDataByteSize);
    }
    
    return noErr;
}

OSStatus outputCallback(	void *							inRefCon,
                       AudioUnitRenderActionFlags *	ioActionFlags,
                       const AudioTimeStamp *			inTimeStamp,
                       UInt32							inBusNumber,
                       UInt32							inNumberFrames,
                       AudioBufferList * __nullable	ioData) {
    NSLog(@"output");
    BSAudioDevice *device = (__bridge BSAudioDevice*)inRefCon;
    
    UInt32 size = 0;
    if (device->_outputCallbackBlock) {
        size = ioData->mBuffers[0].mDataByteSize;
        device->_outputCallbackBlock(ioData->mBuffers[0].mData,
                                     &size);
    }
    memset(ioData->mBuffers[0].mData + size, 0, ioData->mBuffers[0].mDataByteSize - size);
    
    return noErr;
}

@implementation BSAudioDevice
@synthesize audioUnit = _audioUnit;

/*
#pragma mark - singleton
static BSAudioDevice *g_sharedInstance = nil;
+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    id obj = nil;
    if (!g_sharedInstance) {
        obj = [super allocWithZone:zone];
    } else {
        NSString *reason = [NSString stringWithFormat:@"%@ is singleton class! Please use +sharedInstance to get the singleton instance.", NSStringFromClass(self)];
        [[NSException exceptionWithName:@"singletonError" reason:reason userInfo:nil] raise];
    }
    return obj;
}

+ (instancetype)sharedInstance {
    if (!g_sharedInstance) {
        g_sharedInstance = [[self alloc] init];
    }
    return g_sharedInstance;
}
*/

- (void)dealloc {
    AudioComponentInstanceDispose(_audioUnit);
}

- (AudioUnit)audioUnit {
    if (!_audioUnit) {
        _audioUnit = [self createAudioUnitInstance];
    }
    return _audioUnit;
}

- (void)setAudioUnit:(AudioUnit)audioUnit {
    if (_audioUnit == audioUnit) {
        return;
    }
    AudioComponentInstanceDispose(_audioUnit);
    _audioUnit = audioUnit;
}

- (AudioUnit)createAudioUnitInstance {
    OSStatus status;
    
    AudioUnit unit;
    AudioComponentDescription audioComponentDesc;
    AudioComponent audioComp;
    
    audioComponentDesc.componentType = kAudioUnitType_Output;
    audioComponentDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioComponentDesc.componentFlags = 0;
    audioComponentDesc.componentFlagsMask = 0;
#if TARGET_IPHONE_SIMULATOR
    audioComponentDesc.componentSubType = kAudioUnitSubType_RemoteIO;
#elif TARGET_OS_IPHONE
    audioComponentDesc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
#endif
    audioComp = AudioComponentFindNext(NULL, &audioComponentDesc);
    if (audioComp == NULL) {
        return nil;
    }
    status = AudioComponentInstanceNew(audioComp, &unit);
    if (status != noErr) {
        return nil;
    }
    
    return unit;
}

- (AudioStreamBasicDescription)asbdWithSampleRate:(Float64)sampleRate numberOfChannel:(UInt32)number {
    AudioStreamBasicDescription asbd;
    asbd.mBitsPerChannel =      BITS_PER_CHANNEL;
    asbd.mChannelsPerFrame =    number;
    asbd.mBytesPerFrame =       asbd.mBitsPerChannel / 8 * asbd.mChannelsPerFrame;
    asbd.mSampleRate =          sampleRate;
    asbd.mFramesPerPacket =     FRAMES_PER_PACKET;
    asbd.mBytesPerPacket =      asbd.mBytesPerFrame * asbd.mFramesPerPacket;
    asbd.mFormatID =            kAudioFormatLinearPCM;
    asbd.mFormatFlags =         kLinearPCMFormatFlagIsSignedInteger |
                                kLinearPCMFormatFlagIsPacked;
    return asbd;
}

- (BOOL)setCaptureWithSampleRate:(Float64)sampleRate numberOfChannel:(UInt32)number callback:(void(^)(void *inPCMData, UInt32 inSize))callback {
    OSStatus status;
    
    //设置录音回调
    AURenderCallbackStruct cbStruct = {0};
    if (callback != NULL) {
        cbStruct.inputProc = inputCallback;
        cbStruct.inputProcRefCon = (__bridge void *)(self);
    }
    
    status = AudioUnitSetProperty(self.audioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &cbStruct, sizeof(cbStruct));
    if (status != noErr) {
        return NO;
    }
    _inputCallbackBlock = callback;
    
    UInt32 enable = YES;
    //输入连接到bus 1
    status = AudioUnitSetProperty(self.audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enable, sizeof(enable));
    if (status != noErr) {
        return NO;
    }
    
    UInt32 size;
    AudioStreamBasicDescription asbd = [self asbdWithSampleRate:sampleRate numberOfChannel:number];
    size = sizeof(AudioStreamBasicDescription);
    status = AudioUnitSetProperty(self.audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output, 1, &asbd, size);
    if (status != noErr) {
        return NO;
    }

    return YES;
}

- (BOOL)setPlaybackWithSampleRate:(Float64)sampleRate numberOfChannel:(UInt32)number callback:(void(^)(void *outPCMData, UInt32 *inoutSize))callback {
    OSStatus status;
    
    //设置播放回调
    AURenderCallbackStruct cbStruct = {0};
    if (callback != NULL) {
        cbStruct.inputProc = outputCallback;
        cbStruct.inputProcRefCon = (__bridge void *)(self);
    }
    
    status = AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, 0, &cbStruct, sizeof(cbStruct));
    if (status != noErr) {
        return NO;
    }
    _outputCallbackBlock = callback;
    
    UInt32 enable = YES;
    //输出连接到bus 0
    status = AudioUnitSetProperty(self.audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &enable, sizeof(enable));
    if (status != noErr) {
        return NO;
    }
    
    UInt32 size;
    AudioStreamBasicDescription asbd = [self asbdWithSampleRate:sampleRate numberOfChannel:number];
    size = sizeof(AudioStreamBasicDescription);
    status = AudioUnitSetProperty(self.audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input, 0, &asbd, size);
    if (status != noErr) {
        return NO;
    }
    
    return YES;
}

- (BOOL)run {
    //audio unit
    OSStatus status;
    status = AudioUnitInitialize(self.audioUnit);
    if (status != noErr) {
        return NO;
    }
    status = AudioOutputUnitStart(self.audioUnit);
    if (status != noErr) {
        return NO;
    }
    self.isRunning = YES;
    return YES;
}

- (void)stop {
    OSStatus status;
    status = AudioUnitUninitialize(self.audioUnit);
    if (status != noErr) {
        return;
    }
    status = AudioOutputUnitStop(self.audioUnit);
    if (status != noErr) {
        return;
    }
    self.isRunning = NO;
}

- (AudioStreamBasicDescription)currentCaptureASBD {
    AudioStreamBasicDescription ASBD = {0};
    UInt32 size = sizeof(ASBD);
    AudioUnitGetProperty(self.audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &ASBD, &size);
    return ASBD;
}

- (AudioStreamBasicDescription)currentPlaybacASBD {
    AudioStreamBasicDescription ASBD = {0};
    UInt32 size = sizeof(ASBD);
    AudioUnitGetProperty(self.audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &ASBD, &size);
    return ASBD;
}

@end
