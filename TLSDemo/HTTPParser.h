//
//  HTTPParser.h
//  TLSDemo
//
//  Created by John-Paul Gignac on 2015-05-18.
//  Copyright (c) 2015 Abdullah Bakhach. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TLSWrapper;

@interface HTTPParser : NSObject

/**
 * This method reads an HTTP query or response from the
 * given object.
 *
 * If the end of stream is reached before any data is read,
 * this method returns a dictionary with no entries.  This
 * may not be an error if you're trying to read a follow-up
 * query on a keep-alive connection.  It is always an error
 * if you're trying to read a response.
 *
 * If the data contains a syntax error, or if the end of
 * file is reached before the end, this method returns nil.
 *
 * Otherwise, it returns a dictionary with a key-value pair
 * for each HTTP header (with key names all in lowercase).
 * Additionally, it contains the following special keys:
 *
 *   @"HTTP" - The first line of text as an NSString
 *   @"BODY" - The body data as an NSData object
 *   @"PROTOCOL" - The protocol string, eg, "HTTP/1.1"
 *   @"TYPE" - The query type (eg, @"POST"), or @"RESPONSE" for responses
 *   @"RESPONSE" - The HTTP response code as an NSNumber, or @0 for queries
 *   @"URI" - The requested URI, or @"" for responses
 *
 */
+(NSDictionary*)readWithTLSWrapper:(TLSWrapper*)tls;

@end
