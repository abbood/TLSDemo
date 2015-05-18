//
//  TLSTestClient.h
//  TLSDemo
//
//  Created by John-Paul Gignac on 2015-05-17.
//  Copyright (c) 2015 Abdullah Bakhach. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TLSTestClient : NSObject

/**
 * Run a series of tests against the given host and port.
 * Do not call this method on the main thread.
 */
+ (void)runTestWithHost:(NSString*)host
                   port:(int)port;

@end
