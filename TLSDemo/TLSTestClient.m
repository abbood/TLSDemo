//
//  TLSTestClient.m
//  TLSDemo
//
//  Created by John-Paul Gignac on 2015-05-17.
//  Copyright (c) 2015 Abdullah Bakhach. All rights reserved.
//

#import "TLSTestClient.h"
#import "TLSWrapper.h"
#import "HTTPParser.h"

@implementation TLSTestClient

+ (void)runTestWithHost:(NSString*)host
                   port:(int)port
{
    for( int i=0; i < 10; ++i) {
        dispatch_async(dispatch_get_global_queue(0, DISPATCH_QUEUE_PRIORITY_DEFAULT), ^{
            for( int j=0; j < 20; ++j) {
                [TLSTestClient testSessionWithHost:host
                                              port:port
                                       numRequests:1 + (random() % 20)];
            }
        });
    }
}

+ (void)testSessionWithHost:(NSString*)host
                       port:(int)port
                numRequests:(int)numRequests
{
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost( kCFAllocatorDefault, (__bridge CFStringRef)host, port,
                                       &readStream, &writeStream );
    NSInputStream* _in = (__bridge_transfer NSInputStream*)readStream;
    NSOutputStream* _out = (__bridge_transfer NSOutputStream*)writeStream;
    [_in open];
    [_out open];

    NSString* path = [[NSBundle mainBundle] pathForResource:@"deviceB" ofType:@"p12"];
    NSData* identity = [NSData dataWithContentsOfFile:path];

    TLSWrapper* tls = [TLSWrapper wrapperWithInputStream:_in
                                            outputStream:_out
                                                identity:identity
                                                isServer:NO];

    for( int n=0; n < numRequests; ++n) {
        NSLog(@"Client: Sending request %d", n);

        // Make an HTTP request
        BOOL rc = [tls writeString:@"GET / HTTP/1.0\r\nContent-Length: 0\r\n\r\n\r\n"];
        if( !rc) {
            NSLog(@"Client: Write error. Terminating session.");
            return;
        }

        // Read the response.
        NSDictionary* response = [HTTPParser readWithTLSWrapper:tls];

        if( response && response.count == 0) {
            NSLog(@"Client: The server hung up on us! Terminating session.");
            return;
        }

        if( response == nil) {
            NSLog(@"Client: Bad response. Terminating session.");
            return;
        }
    }

    NSLog(@"Client: Session complete");
}

@end
