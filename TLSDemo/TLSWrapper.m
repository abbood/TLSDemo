//
//  TLSWrapper.m
//  TLSDemo
//
//  Created by John-Paul Gignac on 2015-05-17.
//  Copyright (c) 2015 Abdullah Bakhach. All rights reserved.
//

#import "TLSWrapper.h"
#include <CommonCrypto/CommonDigest.h>
#include <sys/socket.h>

/**
 * Set this to YES to disable TLS
 */
static const BOOL dummyTLS = NO;

@interface TLSWrapper ()
- (OSStatus)internalRead:(void*)data length:(size_t*)dataLength;
- (OSStatus)internalWrite:(const void*)data length:(size_t*)dataLength;
@end

OSStatus TLSWrapperRead( SSLConnectionRef connection, void *data, size_t *dataLength)
{
    return [(__bridge TLSWrapper*)connection internalRead:data length:dataLength];
}

OSStatus TLSWrapperWrite( SSLConnectionRef connection, const void *data, size_t *dataLength)
{
    return [(__bridge TLSWrapper*)connection internalWrite:data length:dataLength];
}

@implementation TLSWrapper {
    int _fd;
    NSInputStream* _in;
    NSOutputStream* _out;
    SSLContextRef _context;
}

+ (instancetype)wrapperWithFileDescriptor:(int)fd
                                 identity:(NSData*)identity
                                 isServer:(BOOL)isServer
{
    return [[TLSWrapper alloc] initWithFileDescriptor:fd
                                            inputStream:nil
                                           outputStream:nil
                                               identity:identity
                                               isServer:isServer];
}

+ (instancetype)wrapperWithInputStream:(NSInputStream*)i
                          outputStream:(NSOutputStream*)o
                              identity:(NSData*)identity
                              isServer:(BOOL)isServer
{
    return [[TLSWrapper alloc] initWithFileDescriptor:-1
                                            inputStream:i
                                           outputStream:o
                                               identity:identity
                                               isServer:isServer];
}

- (instancetype)init
{
    assert(NO);
}

- (instancetype)initWithFileDescriptor:(int)fd
                           inputStream:(NSInputStream*)i
                          outputStream:(NSOutputStream*)o
                              identity:(NSData*)identity
                              isServer:(BOOL)isServer
{
    if( self = [super init]) {
        _fd = fd;
        _in = i;
        _out = o;

        if( dummyTLS) {
            NSLog(@"Using dummy TLS wrapper on %@",
                  isServer ? @"server" : @"client");
            return self;
        }

        _context = SSLCreateContext(NULL, isServer ? kSSLServerSide : kSSLClientSide, kSSLStreamType);
        if(_context == NULL) {
            NSLog(@"Wrapper: Can't create SSL context");
            return nil;
        }

        OSStatus rc = SSLSetIOFuncs(_context, TLSWrapperRead, TLSWrapperWrite);
        if(rc) {
            NSLog(@"Wrapper: Can't set IO funcs: %d",(int)rc);
            return nil;
        }

        rc = SSLSetConnection(_context, (__bridge void*)self);
        if(rc) {
            NSLog(@"Wrapper Can't set SSL connection: %d", (int)rc);
            return nil;
        }

        if( isServer) {
            rc = SSLSetClientSideAuthenticate(_context, kAlwaysAuthenticate);
            if(rc) {
                NSLog(@"Wrapper: Can't force client to authenticate: %d", (int)rc);
                return nil;
            }
        }

        // Load the identity from the p12 data
        SecIdentityRef secID = [TLSWrapper secIDforIdentity:identity];
        if( secID == NULL) {
            NSLog(@"Wrapper: Invalid p12 file");
            return nil;
        }

        // Inform the SSL session of our identity
        rc = SSLSetCertificate(_context, (__bridge CFArrayRef)@[(__bridge id)secID]);
        CFRelease(secID);
        if(rc) {
            NSLog(@"Wrapper: Can't set SSL certificate: %d", (int)rc);
            return nil;
        }

        rc = SSLSetSessionOption(_context, isServer ? kSSLSessionOptionBreakOnClientAuth :
                                 kSSLSessionOptionBreakOnServerAuth, true);
        if(rc) {
            NSLog(@"Wrapper: Can't set SSL session options: %d", (int)rc);
            return nil;
        }

        rc = SSLHandshake(_context);
        if(rc != errSSLServerAuthCompleted &&
           rc != errSSLClientAuthCompleted) {
            // The handshake was supposed to pause to let us verify the certificate.
            NSLog(@"Wrapper: SSL Handshake not proceeding as expected: %d", (int)rc);
            return nil;
        }

        SecTrustRef trust;
        rc = SSLCopyPeerTrust(_context, &trust);
        if(rc) {
            NSLog(@"Wrapper: Can't copy peer trust: %d",(int)rc);
            return nil;
        }

        // Load the root certificate
        NSString* resourcePath = [[NSBundle mainBundle] pathForResource:@"root.cert" ofType:@"der"];
        NSData* certData = [NSData dataWithContentsOfFile:resourcePath];
        SecCertificateRef rootCert = SecCertificateCreateWithData(NULL,(__bridge CFDataRef)certData);
        if( rootCert == NULL) {
            NSLog(@"Wrapper: Can't load root certificate");
            CFRelease(trust);
            return nil;
        }

        // Override the trust certificates
        rc = SecTrustSetAnchorCertificates(trust, (__bridge CFArrayRef)@[(__bridge id)rootCert]);
        CFRelease(rootCert);
        if(rc) {
            NSLog(@"Wrapper: Can't set anchor certificates: %d", (int)rc);
            CFRelease(trust);
            return nil;
        }

        // Evaluate the trust object
        SecTrustResultType trustResult;
        rc = SecTrustEvaluate(trust, &trustResult);
        CFRelease(trust);
        if(rc) {
            NSLog(@"Wrapper: Can't evaluate SSL trust: %d", (int)rc);
            return nil;
        }
        if( trustResult != kSecTrustResultUnspecified) {
            // We expected kSecTrustResultUnspecified -- in the established context, this result
            // code indicates that the certificate is signed by our root certificate.
            // Any other result code indicates that something has gone wrong.
            NSLog(@"Wrapper: Unexpected trust evaluation result code: %d", (int)trustResult);
            return nil;
        }

        // We can complete the handshake now
        rc = SSLHandshake(_context);
        if(rc) {
            NSLog(@"Wrapper: The handshake continuation failed: %d", (int)rc);
            return nil;
        }

        NSLog(@"Wrapper: TLS Handshake successful!");
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"Wrapper: Deallocating TLS; _fd=%d", _fd);
    if(_context) {
        SSLSessionState state;
        OSStatus rc = SSLGetSessionState(_context, &state);
        if(rc == 0 && state == kSSLConnected) SSLClose(_context);
        CFRelease(_context);
    }
    if(_fd >= 0) close(_fd);
    else {
        [_in close];
        [_out close];
    }
}

- (OSStatus)internalWrite:(const void*)data
                   length:(size_t*)dataLength
{
    NSInteger rc;
    if( _fd >= 0) {
        rc = (NSInteger)send(_fd, data, *dataLength, 0);
        if( rc < 0)
            NSLog(@"Wrapper: Write error: %s", strerror(errno));
        if( rc == 0)
            NSLog(@"Wrapper: Wrote 0 bytes: %s", strerror(errno));
    } else {
        rc = [_out write:data maxLength:*dataLength];
        if( rc < 0)
            NSLog(@"Wrapper: Write error: status=%d; error=%d",
                  (int)_out.streamStatus, (int)_out.streamError);
        if( rc == 0)
            NSLog(@"Wrapper: Wrote 0 bytes: status=%d; error=%d",
                  (int)_out.streamStatus, (int)_out.streamError);
    }

    if(rc < 0) {
        *dataLength = 0;
        return errSecIO;
    }

    if( rc == 0) {
        *dataLength = 0;
        return errSSLClosedGraceful;
    }

    if( rc < *dataLength) {
        *dataLength = rc;
        return errSSLWouldBlock;
    }

    return 0;
}

- (OSStatus)internalRead:(void*)data
                  length:(size_t*)dataLength
{
    NSInteger rc;
    if( _fd >= 0) {
        rc = (NSInteger)recv(_fd, data, *dataLength, 0);
        if( rc < 0)
            NSLog(@"Wrapper: Read error: %s", strerror(errno));
        if( rc == 0)
            NSLog(@"Wrapper: Apparent EOF on read: %s", strerror(errno));
    } else {
        rc = [_in read:data maxLength:*dataLength];
        if( rc < 0)
            NSLog(@"Wrapper: Read error");
        if( rc == 0)
            NSLog(@"Wrapper: Apparent EOF on read");
    }

    if( rc < 0) {
        *dataLength = 0;
        return errSecIO;
    }

    if( rc == 0) {
        *dataLength = 0;
        return errSSLClosedGraceful;
    }

    if( rc < *dataLength) {
        *dataLength = rc;
        return errSSLWouldBlock;
    }

    return 0;
}

+ (SecIdentityRef)secIDforIdentity:(NSData*)identity
{
    // Load the identity from the p12 data
    CFArrayRef idItems = NULL;
    OSStatus rc = SecPKCS12Import((__bridge CFDataRef)identity,
                                  (__bridge CFDictionaryRef)@{(__bridge id)kSecImportExportPassphrase : @"p12Password" },
                                  &idItems);
    if(rc) {
        NSLog(@"Wrapper: Invalid p12 file, %d", (int)rc);
        return NULL;
    }
    CFDictionaryRef idAndTrust = CFArrayGetValueAtIndex(idItems, 0);
    SecIdentityRef secID = (SecIdentityRef)CFDictionaryGetValue(idAndTrust, kSecImportItemIdentity);
    CFRetain(secID);
    CFRelease(idItems);
    return secID;
}

- (NSInteger)read:(uint8_t *)buffer
        maxLength:(NSUInteger)len
{
    size_t processed = len;

    OSStatus rc = (dummyTLS ? [self internalRead:buffer length:&processed] :
                   SSLRead(_context, buffer, len, &processed));

    if(rc != 0 && rc != errSSLWouldBlock && rc != errSSLClosedGraceful) {
        NSLog(@"Wrapper: SSL Read Error: %d", (int)rc);
        NSLog(@"Wrapper: Done reading on %@", self);
        return -1;
    }

    return processed;
}

- (NSInteger)write:(const uint8_t *)buffer
         maxLength:(NSUInteger)len
{
    size_t processed = len;

    OSStatus rc = (dummyTLS ? [self internalWrite:buffer length:&processed] :
                   SSLWrite(_context, buffer, len, &processed));

    if(rc != 0 && rc != errSSLWouldBlock && rc != errSSLClosedGraceful) {
        NSLog(@"Wrapper: SSL Write Error: %d", (int)rc);
        return -1;
    }
    return processed;
}

@end
