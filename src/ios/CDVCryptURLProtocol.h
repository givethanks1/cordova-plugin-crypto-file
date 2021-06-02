//
//  CDVCryptURLProtocol.h
//  CordovaLib
//
//  Created by tkyaji on 2015/07/15.
//  Update based on: https://www.raywenderlich.com/2509-nsurlprotocol-tutorial
//


#import <Foundation/Foundation.h>

@property (nonatomic, strong) NSMutableData *mutableData;
@property (nonatomic, strong) NSURLResponse *response;

@interface CDVCryptURLProtocol : NSURLProtocol

@end
