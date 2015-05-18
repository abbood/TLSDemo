//
//  TLSWrapper.h
//  TLSDemo
//
//  Created by John-Paul Gignac on 2015-05-17.
//  Copyright (c) 2015 Abdullah Bakhach. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TLSWrapper : NSObject

+ (instancetype)wrapperWithFileDescriptor:(int)fd
                                 identity:(NSData*)identity
                                 isServer:(BOOL)isServer;

+ (instancetype)wrapperWithInputStream:(NSInputStream*)i
                          outputStream:(NSOutputStream*)o
                              identity:(NSData*)identity
                              isServer:(BOOL)isServer;

- (NSInteger)read:(uint8_t *)buffer
        maxLength:(NSUInteger)len;

- (NSInteger)write:(const uint8_t *)buffer
         maxLength:(NSUInteger)len;

- (NSInteger)write:(const uint8_t *)data
            length:(NSInteger)length;

- (BOOL)writeString:(NSString*)string;

@end
