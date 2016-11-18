//
//  ViewController.m
//  BSAudioKit
//
//  Created by Captain Black on 2016/11/18.
//  Copyright © 2016年 Captain Black. All rights reserved.
//

#import "ViewController.h"
#import "BSAudioDevice+Opus.h"

@interface ViewController ()
@property (nonatomic, strong) BSAudioDevice *audioDev;
@property (nonatomic, strong) NSData *encodedAudioRecord;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
}

- (IBAction)actionForCapture:(UIButton *)sender forEvent:(UIEvent *)event {
    if (!sender.selected) {
        NSError *error = nil;
        //声音会话相关选项设置
        [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:0.01 error:&error];//io缓存区的时间精度, 在可用范围内，越小延时越低
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];//声音会话采用录播模式
        [[AVAudioSession sharedInstance] setMode:AVAudioSessionModeVoiceChat error:&error];//降噪访回声
        [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];//扬声器播放
        [[AVAudioSession sharedInstance] setActive:YES error:&error];
        
        sender.selected = [self.audioDev opus_captureWithMaxDuration:30 completion:^(NSData *encodedAudioData, NSError *error) {
            if (error) {
                self.encodedAudioRecord = nil;
                return;
            }
            self.encodedAudioRecord = encodedAudioData;
        }];
    } else {
        [self.audioDev opus_stopCapture];
        sender.selected = NO;
    }
}

- (IBAction)actionForPlayback:(UIButton *)sender forEvent:(UIEvent *)event {
    if (!sender.selected) {
        sender.selected = [self.audioDev opus_playbackWithEncodedData:self.encodedAudioRecord];
    } else {
        [self.audioDev opus_stopPlayback];
        sender.selected = NO;
    }
    
}

#pragma mark - getter & setter
- (BSAudioDevice *)audioDev {
    if (!_audioDev) {
        _audioDev = [[BSAudioDevice alloc] init];
    }
    return _audioDev;
}

@end
