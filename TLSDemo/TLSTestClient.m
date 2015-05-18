//
//  TLSTestClient.m
//  TLSDemo
//
//  Created by John-Paul Gignac on 2015-05-17.
//  Copyright (c) 2015 Abdullah Bakhach. All rights reserved.
//

#import "TLSTestClient.h"
#import "TLSWrapper.h"

@implementation TLSTestClient

+ (void)runTestWithHost:(NSString*)host
                   port:(int)port
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

    for( int n=0; n < 10; ++n) {
        NSLog(@"Client: Sending request %d", n);

        // Make an HTTP request
        static const char* request = "GET / HTTP/1.0\r\nContent-Length: 0\r\n\r\n\r\n";
        NSUInteger remaining = strlen(request);
        while( remaining) {
            NSInteger rc = [tls write:(void*)request maxLength:remaining];
            if( rc < 0) {
                NSLog(@"Client: Write error with %d bytes remaining. Terminating session.", (int)remaining);
                return;
            }
            remaining -= rc;
        }

        // Read the response.  We assume a zero content-length
        int newlines = 0;
        while(newlines < 3) {
            char c;
            NSInteger rc = [tls read:(void*)&c maxLength:1];
            if( rc != 1) {
                NSLog(@"Client: Error receiving response. Terminating session.");
                return;
            }
            if( c == '\n') newlines++;
            else if( c != '\r') newlines = 0;
        }
    }

    NSLog(@"Client: Session complete");
}

@end
