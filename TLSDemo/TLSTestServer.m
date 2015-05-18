//
//  TLSTestServer.m
//  TLSDemo
//
//  Created by John-Paul Gignac on 2015-05-17.
//  Copyright (c) 2015 Abdullah Bakhach. All rights reserved.
//

#import "TLSTestServer.h"
#import "TLSWrapper.h"
#import "HTTPParser.h"

#include <CoreFoundation/CoreFoundation.h>
#include <sys/socket.h>
#include <netinet/in.h>

@interface TLSTestServer ()
- (void)handleConnectionOnInputStream:(NSInputStream*)_in
                         outputStream:(NSOutputStream*)_out;
@end

void handleConnect(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info)
{
    if( type != kCFSocketAcceptCallBack) return;

    NSLog(@"Server: incoming connection");

    CFSocketNativeHandle fd = *(CFSocketNativeHandle*)data;
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocket ( kCFAllocatorDefault, fd, &readStream, &writeStream);

    NSInputStream* _in = (__bridge_transfer NSInputStream*)readStream;
    NSOutputStream* _out = (__bridge_transfer NSOutputStream*)writeStream;

    if( !_in || !_out) {
        NSLog(@"Server: Connection failed");
        return;
    }

    [_in open];
    [_out open];

    // Spawn our server on another thread
    dispatch_async(dispatch_get_global_queue(0, DISPATCH_QUEUE_PRIORITY_DEFAULT), ^{
        TLSTestServer* server = (__bridge TLSTestServer*)info;

        [server handleConnectionOnInputStream:_in
                                 outputStream:_out];
    });
}

@implementation TLSTestServer {
    CFSocketRef _socket;
    CFRunLoopSourceRef _socketSource;
    CFRunLoopRef _runLoop;
}

- (instancetype)init
{
    assert(NO);
}

- (instancetype)initWithPort:(int)port
{
    if( self = [super init]) {
        CFSocketContext context;
        memset(&context, 0, sizeof(context));
        context.info = (__bridge void*)self;

        _socket = CFSocketCreate(
                                 kCFAllocatorDefault,
                                 PF_INET,
                                 SOCK_STREAM,
                                 IPPROTO_TCP,
                                 kCFSocketAcceptCallBack, handleConnect, &context);
        struct sockaddr_in sin;

        memset(&sin, 0, sizeof(sin));
        sin.sin_len = sizeof(sin);
        sin.sin_family = AF_INET;
        sin.sin_port = htons(port);
        sin.sin_addr.s_addr= INADDR_ANY;

        CFDataRef sincfd = CFDataCreate(
                                        kCFAllocatorDefault,
                                        (UInt8 *)&sin,
                                        sizeof(sin));

        CFSocketSetAddress(_socket, sincfd);
        CFRelease(sincfd);

        _socketSource = CFSocketCreateRunLoopSource(
                                                    kCFAllocatorDefault,
                                                    _socket,
                                                    0);
        _runLoop = CFRunLoopGetCurrent();

        NSLog(@"Server: Launching on port %d", port);

        CFRunLoopAddSource(
                           _runLoop,
                           _socketSource,
                           kCFRunLoopDefaultMode);
    }
    return self;
}

- (void)dealloc
{
    CFRunLoopRemoveSource(_runLoop, _socketSource, kCFRunLoopDefaultMode);
    CFRelease(_socketSource);
    CFRelease(_socket);
}

- (void)handleConnectionOnInputStream:(NSInputStream *)_in
                         outputStream:(NSOutputStream *)_out
{
    // Get our TLS identity
    NSString* path = [[NSBundle mainBundle] pathForResource:@"deviceA" ofType:@"p12"];
    NSData* identity = [NSData dataWithContentsOfFile:path];

    TLSWrapper* tls = [TLSWrapper wrapperWithInputStream:_in
                                            outputStream:_out
                                                identity:identity
                                                isServer:YES];

    for(;;) {
        NSLog(@"Server: Trying to read a request...");

        // Receive a request.
        NSDictionary* request = [HTTPParser readWithTLSWrapper:tls];
        if( request && request.count == 0) {
            NSLog(@"Server: End of session");
            return;
        }

        if( request == nil) {
            NSLog(@"Server: Error receiving request");
            return;
        }

        // Send the response
        static const char* response = "HTTP/1.0 200 OK\r\nContent-Length: 0\r\n\r\n\r\n";
        NSUInteger remaining = strlen(response);
        while( remaining) {
            NSInteger rc = [tls write:(void*)response maxLength:remaining];
            if( rc < 0) {
                NSLog(@"Server: Write error with %d bytes remaining.", (int)remaining);
                return;
            }
            remaining -= rc;
        }
    }
}

@end
