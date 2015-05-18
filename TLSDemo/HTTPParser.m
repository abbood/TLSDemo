//
//  HTTPParser.m
//  TLSDemo
//
//  Created by John-Paul Gignac on 2015-05-18.
//  Copyright (c) 2015 Abdullah Bakhach. All rights reserved.
//

#import "HTTPParser.h"

#include <sys/socket.h>

@implementation HTTPParser

+(NSDictionary*)readWithTLSWrapper:(TLSWrapper *)tls
{
    return [HTTPParser readWithSomething:tls];
}

+(NSDictionary*)readWithSomething:(id)i
{
    NSMutableDictionary* dict = [HTTPParser readHeaders:i];
    assert(dict != nil);
    if( [dict isKindOfClass:[NSString class]]) {
        NSLog(@"HTTPParser Error reading headers: %@", dict);
        return nil;
    }

    if( dict.count == 0) {
        NSLog(@"HTTPParser Empty message");
        // We return an empty dictionary to indicate that there was no input.
        return dict;
    }

    NSData* body = [HTTPParser readBody:i headers:dict];
    assert(body != nil);
    if( [body isKindOfClass:[NSString class]]) {
        NSLog(@"HTTPParser Error reading HTTP body: %@", body);

        // We don't return an error here because HTTP clients don't
        // always include the HTTP body in their queries.  We should
        // allow the query to proceed if possible.
        body = [NSData new];
    }

    dict[@"BODY"] = body;

    // Parse the first line
    NSString* firstLine = dict[@"HTTP"];
    NSArray* tokens = [firstLine componentsSeparatedByString:@" "];
    if( [tokens[0] length] >= 4 && [[tokens[0] substringToIndex:4] isEqual:@"HTTP"]) {
        dict[@"PROTOCOL"] = tokens[0];
        dict[@"TYPE"] = @"RESPONSE";
        dict[@"RESPONSE"] = [NSNumber numberWithInt:(tokens.count > 1 ? [tokens[1] intValue] : 0)];
        dict[@"URI"] = @"";
    } else {
        dict[@"PROTOCOL"] = (tokens.count > 2 ? tokens[2] : @"HTTP/1.0");
        dict[@"TYPE"] = tokens[0];
        dict[@"RESPONSE"] = @0;
        dict[@"URI"] = (tokens.count > 1 ? tokens[1] : @"");
    }

    return dict;
}

+(NSMutableDictionary*)readHeaders:(id)i
{
    NSMutableDictionary* headers = [NSMutableDictionary new];

    char c;
    NSMutableString* buffer = [NSMutableString new];
    NSString* headerName = @"HTTP";

    for(;;) {
        // Read the value
        [buffer setString:@""];
        for(;;) {
            NSInteger rc = [i read:(void*)&c maxLength:1];
            if( rc < 0) return (id)@"Stream error 1";
            if( rc == 0) {
                if( buffer.length == 0 && headers.count == 0) return headers;
                return (id)@"Premature EOF";
            }
            if( c == '\r') continue;
            if( c == '\n') break;
            [buffer appendFormat:@"%c", c];
        }

        headers[headerName] = [buffer stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        // Read the header name
        [buffer setString:@""];
        for(;;) {
            NSInteger rc = [i read:(void*)&c maxLength:1];
            if( rc < 0) return (id)@"Stream error 2";
            if( rc == 0) return (id)@"Premature EOF";
            if( c == '\r') continue;
            if( c == '\n') {
                if( [buffer length] == 0) return headers;

                // Header name isn't followed by a colon character
                return (id)@"Expected ':' in HTTP header";
            }
            if( c == ':') break;
            [buffer appendFormat:@"%c", c];
        }

        headerName = [buffer lowercaseString];
    }

    return headers;
}

+(NSData*)readBody:(id)i
           headers:(NSDictionary*)headers
{
    NSString* lenStr = headers[@"content-length"];
    if( lenStr == nil) return (id)@"No Content-Length header found";

    int contentLength = [lenStr intValue];
    NSMutableData* buffer = [NSMutableData dataWithLength:contentLength];
    NSUInteger received = 0;

    while( received < contentLength) {
        NSInteger rc = [i read:(unsigned char*)[buffer mutableBytes] + received
               maxLength:contentLength-received];
        if( rc < 0) return (id)@"HTTPParser Error reading HTTP response";
        if( rc == 0) return (id)@"HTTPParser Unexpected EOF in HTTP response data";
        received += rc;
    }

    char crlf[2];
    if( [i read:(void*)&crlf[0] maxLength:1] != 1 ||
       [i read:(void*)&crlf[1] maxLength:1] != 1 ||
       crlf[0] != '\r' || crlf[1] != '\n') {
        return (id)@"HTTPParser Problem reading terminating CRLF";
    }

    return buffer;
}

@end
