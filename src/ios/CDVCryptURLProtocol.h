//
//  CDVCryptURLProtocol.h
//  CordovaLib
//
//  Created by tkyaji on 2015/07/15.
//
//

// #import <Cordova/CDVURLProtocol.h>

// @interface CDVCryptURLProtocol : CDVURLProtocol

// @end

#import <Foundation/Foundation.h>

@property (nonatomic, strong) NSMutableData *mutableData;
@property (nonatomic, strong) NSURLResponse *response;

@interface CDVCryptURLProtocol : NSURLProtocol

// - (instancetype)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id<NSURLProtocolClient>)client;

@end
