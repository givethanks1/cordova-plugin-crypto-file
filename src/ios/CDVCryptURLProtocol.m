//
//  CDVCryptURLProtocol.m
//  CordovaLib
//
//  Created by tkyaji on 2015/07/15.
//  updates based on https://www.raywenderlich.com/2509-nsurlprotocol-tutorial and @mjacques-notur
//    and others

#import "CDVCryptURLProtocol.h"

#import <MobileCoreServices/MobileCoreServices.h>
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>

@interface MyURLProtocol () <NSURLConnectionDelegate>
@property (nonatomic, strong) NSURLConnection *connection;
@end

static NSString* const kCryptKey = @" ";
static NSString* const kCryptIv = @" ";

static int const kIncludeFileLength = 1;
static int const kExcludeFileLength = 0;
static NSString* const kIncludeFiles[] = { @"\\.(htm|html|js|css|txt)$" };
static NSString* const kExcludeFiles[] = { };
NSString *retrievePath;
NSString *wwwPath;
NSString *checkPath;

@implementation CDVCryptURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest*)theRequest
{
    NSLog(@"the url inside the init request: %@",theRequest);
    if ([self checkCryptFile:theRequest.URL]) {
        return YES;
    }
    
    return [super canInitWithRequest:theRequest];
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (void)startLoading
{
    NSURL* url = self.request.URL;

    wwwPath = [[NSBundle mainBundle].resourcePath stringByAppendingString:@"/www"];
    NSString *urling    = [@"file://"stringByAppendingString:wwwPath];
    NSString *urlings   = [urling stringByAppendingString:checkPath];
    NSString *finalUrl  = [urlings stringByReplacingOccurrencesOfString:@" " withString:@"%20"];

    NSURL *urls = [[NSURL alloc] initWithString:finalUrl];
    url         = urls;
    //if ([[self class] checkCryptFile:url]) {
        NSString *mimeType = [self getMimeType:url];
        
        NSError* error;
        NSString* content = [[NSString alloc] initWithContentsOfFile:url.path encoding:NSUTF8StringEncoding error:&error];
        if (!error) {
            NSLog(@"Decrypt: %@",url);
            NSData* data = [self decryptAES256WithKey:kCryptKey iv:kCryptIv data:content];
            [self sendResponseWithResponseCode:200 data:data mimeType:mimeType];
        } else {
	        NSLog(@"The error while loading: %@",error);
	    }
    //}
    
    [super startLoading];
}

- (void)stopLoading {
    [self.connection cancel];
    self.connection = nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];

    self.response = response;
    self.mutableData = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.client URLProtocol:self didLoadData:data];
    [self.mutableData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self.client URLProtocolDidFinishLoading:self];
	// [self saveCachedResponse];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
}

+ (BOOL)checkCryptFile:(NSURL *)url {
    if (![url.scheme isEqual: @"file"]) {
        return NO;
    }

    NSLog(@"%@", url.path);
    
    NSString *wwwPath = [[NSBundle mainBundle].resourcePath stringByAppendingString:@"/www/"];
    NSString *checkPath = [url.path stringByReplacingOccurrencesOfString:wwwPath withString:@""];
    
    if (![self hasMatch:checkPath regexArr:kIncludeFiles length:kIncludeFileLength]) {
        return NO;
    }
    if ([self hasMatch:checkPath regexArr:kExcludeFiles length:kExcludeFileLength]) {
        return NO;
    }

    return YES;
}

+ (BOOL)hasMatch:(NSString *)text regexArr:(NSString* const [])regexArr length:(int)length {
    for (int i = 0; i < length; i++) {
        NSString* const regex = regexArr[i];
        if ([self isMatch:text pattern:regex]) {
            return YES;
        }
    }
    return NO;
}

+ (BOOL)isMatch:(NSString *)text pattern:(NSString *)pattern {
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    if (error) {
        return NO;
    }
    if ([regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)]) {
        return YES;
    }
    return NO;
}

- (NSString*)getMimeType:(NSURL *)url
{
    NSString *fullPath = url.path;
    NSString *mimeType = nil;
    
    if (fullPath) {
        CFStringRef typeId = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[fullPath pathExtension], NULL);
        if (typeId) {
            mimeType = (__bridge_transfer NSString*)UTTypeCopyPreferredTagWithClass(typeId, kUTTagClassMIMEType);
            if (!mimeType) {
                // special case for m4a
                if ([(__bridge NSString*)typeId rangeOfString : @"m4a-audio"].location != NSNotFound) {
                    mimeType = @"audio/mp4";
                } else if ([[fullPath pathExtension] rangeOfString:@"wav"].location != NSNotFound) {
                    mimeType = @"audio/wav";
                } else if ([[fullPath pathExtension] rangeOfString:@"css"].location != NSNotFound) {
                    mimeType = @"text/css";
                }
            }
            CFRelease(typeId);
        }
    }
    return mimeType;
}

- (NSData *)decryptAES256WithKey:(NSString *)key iv:(NSString *)iv data:(NSString *)base64String {
    
    NSData *data = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
    
    size_t bufferSize = [data length] + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    size_t numBytesDecrypted = 0;
    
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    NSData *ivData = [iv dataUsingEncoding:NSUTF8StringEncoding];
    
    CCCryptorStatus status = CCCrypt(kCCDecrypt,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     keyData.bytes,
                                     kCCKeySizeAES256,
                                     ivData.bytes,
                                     data.bytes,
                                     data.length,
                                     buffer,
                                     bufferSize,
                                     &numBytesDecrypted);
    
    if (status == kCCSuccess) {
        return [NSData dataWithBytes:buffer length:numBytesDecrypted];
    }
    free(buffer);
    
    return nil;
}

- (NSString*)getMimeTypeFromPath:(NSString*)fullPath
{
    NSString* mimeType = nil;
    
    if (fullPath) {
        CFStringRef typeId = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[fullPath pathExtension], NULL);
        if (typeId) {
            mimeType = (__bridge_transfer NSString*)UTTypeCopyPreferredTagWithClass(typeId, kUTTagClassMIMEType);
            if (!mimeType) {
                // special case for m4a
                if ([(__bridge NSString*)typeId rangeOfString : @"m4a-audio"].location != NSNotFound) {
                    mimeType = @"audio/mp4";
                } else if ([[fullPath pathExtension] rangeOfString:@"wav"].location != NSNotFound) {
                    mimeType = @"audio/wav";
                } else if ([[fullPath pathExtension] rangeOfString:@"css"].location != NSNotFound) {
                    mimeType = @"text/css";
                }
            }
            CFRelease(typeId);
        }
    }
    return mimeType;
}

- (void)sendResponseWithResponseCode:(NSInteger)statusCode data:(NSData*)data mimeType:(NSString*)mimeType
{
    NSLog(@"inside response");
    if (mimeType == nil) {
        mimeType = @"text/plain";
    }
    
    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:[[self request] URL] statusCode:statusCode HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type" : mimeType}];
    
    [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    if (data != nil) {
        [[self client] URLProtocol:self didLoadData:data];
    }
    [[self client] URLProtocolDidFinishLoading:self];
}

+ (NSURLRequest*)canonicalRequestForRequest:(NSURLRequest*)request
{
    NSLog(@"%@ received %@", self, NSStringFromSelector(_cmd));
    return request;
}

@end
