//
//  BSRingBuffer.m
//  YXYAudioKit
//
//  Created by Captain Black on 16/8/15.
//  Copyright © 2016年 Captain Black. All rights reserved.
//

#import "BSRingBuffer.h"

@interface BSRingBuffer ()
{
    char *_buffer;
    NSInteger _readingPos;
    NSInteger _writtingPos;
    dispatch_semaphore_t _sem;
}
@end

@implementation BSRingBuffer

- (void)dealloc {
    free(_buffer);
}
- (instancetype)init {
    return [self initWithCapacity:0];
}
- (instancetype)initWithCapacity:(NSUInteger)capacity {
    if (self = [super init]) {
        _sem = dispatch_semaphore_create(1);
        self.capacity = capacity;
    }
    return self;
}

- (void)setCapacity:(NSUInteger)capacity {
    dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);
    if (_capacity != capacity) {
        _capacity = capacity;
        if (_buffer) {
            free(_buffer);
        }
        _buffer = malloc(_capacity);
    }
    _readingPos = _writtingPos = 0;
    dispatch_semaphore_signal(_sem);
}

- (BOOL)isEmpty {
    return (_readingPos == _writtingPos);
}

- (BOOL)isFull {
    return !(_capacity - _writtingPos + _readingPos);
}

- (NSUInteger)available {
    return (_writtingPos - _readingPos);
}

- (NSUInteger)freeSpace {
    return (_capacity - _writtingPos + _readingPos);
}

- (NSUInteger)addBytes:(void*)bytes length:(NSUInteger)length {
    dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);
    
    length = MIN(length, _capacity - _writtingPos + _readingPos);
    if (length == 0) {
        dispatch_semaphore_signal(_sem);
        return length;
    }
   
    NSUInteger writingLen = MIN(length, _capacity - (_writtingPos % (_capacity - 1)));
    memcpy(_buffer + (_writtingPos % (_capacity - 1)), bytes, writingLen);
    memcpy(_buffer, bytes + writingLen, length - writingLen);
    
    _writtingPos += length;
    
    dispatch_semaphore_signal(_sem);
    
    return length;
}

- (NSUInteger)getBytes:(void*)buffer length:(NSUInteger)length {
    dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);
    
    length = MIN(length, _writtingPos - _readingPos);
    if (length == 0) {
        dispatch_semaphore_signal(_sem);
        return length;
    }
    
    NSUInteger readingLen = MIN(length, _capacity - (_readingPos % (_capacity - 1)));
    memcpy(buffer, _buffer + (_readingPos % (_capacity - 1)), readingLen);
    memcpy(buffer + readingLen, _buffer, length - readingLen);
    
    _readingPos += length;
    
    dispatch_semaphore_signal(_sem);
    
    return length;
}

@end