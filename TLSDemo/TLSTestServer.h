//
//  TLSTestServer.h
//  TLSDemo
//
//  Created by John-Paul Gignac on 2015-05-17.
//  Copyright (c) 2015 Abdullah Bakhach. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TLSTestServer : NSObject

/**
 * Construct and launch the server.  The server will continue to run
 * until this object is deallocated.
 */
- (instancetype)initWithPort:(int)port;

@end
