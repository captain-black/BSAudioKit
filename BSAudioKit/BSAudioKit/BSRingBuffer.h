//
//  BSRingBuffer.h
//  YXYAudioKit
//
//  Created by Captain Black on 16/8/15.
//  Copyright © 2016年 Captain Black. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BSRingBuffer : NSObject

@property (nonatomic, readwrite) NSUInteger capacity;//设置将会新建缓冲区，会丢失所有数据
@property (nonatomic, readonly, getter=isEmpty) BOOL empty;
@property (nonatomic, readonly, getter=isFull) BOOL full;
@property (nonatomic, readonly) NSUInteger available;
@property (nonatomic, readonly) NSUInteger freeSpace;

- (instancetype)initWithCapacity:(NSUInteger)capacity;
- (NSUInteger)addBytes:(void*)bytes length:(NSUInteger)length;
- (NSUInteger)getBytes:(void*)buffer length:(NSUInteger)length;
@end
