//
//  LRRestyClient.m
//  LRResty
//
//  Created by Luke Redpath on 03/08/2010.
//  Copyright 2010 LJR Software Limited. All rights reserved.
//

#import "LRRestyClient.h"
#import "LRRestyResponse.h"
#import "LRRestyClientDelegate.h"
#import "NSDictionary+QueryString.h"

@interface LRRestyRequest : NSOperation
{
  NSURL *requestURL;
  NSString *requestMethod;
  LRRestyClient *client;
  NSDictionary *requestHeaders;
  id<LRRestyClientDelegate> delegate;
  BOOL _isExecuting;
  BOOL _isFinished;
  NSError *connectionError;
  NSMutableData *responseData;
  NSHTTPURLResponse *response;
}
@property (nonatomic, retain) NSHTTPURLResponse *response;
@property (nonatomic, retain) NSData *responseData;
@property (nonatomic, retain) NSError *connectionError;

- (id)initWithURL:(NSURL *)aURL method:(NSString *)httpMethod client:(LRRestyClient *)theClient delegate:(id<LRRestyClientDelegate>)theDelegate;
- (void)setExecuting:(BOOL)isExecuting;
- (void)setFinished:(BOOL)isFinished;
- (void)finish;
- (void)setQueryParameters:(NSDictionary *)parameters;
- (void)setHeaders:(NSDictionary *)headers;
@end

@implementation LRRestyClient

- (id)init
{
  if (self = [super init]) {
    operationQueue = [[NSOperationQueue alloc] init];
  }
  return self;
}

- (void)dealloc
{
  [operationQueue release];
  [super dealloc];
}

- (void)get:(NSString *)urlString delegate:(id<LRRestyClientDelegate>)delegate;
{
  [self get:urlString parameters:nil delegate:delegate];
}

- (void)get:(NSString *)urlString parameters:(NSDictionary *)parameters delegate:(id<LRRestyClientDelegate>)delegate;
{
  [self get:urlString parameters:parameters headers:nil delegate:delegate];
}

- (void)get:(NSString *)urlString parameters:(NSDictionary *)parameters headers:(NSDictionary *)headers delegate:(id<LRRestyClientDelegate>)delegate;
{
  [self getURL:[NSURL URLWithString:urlString] parameters:parameters headers:headers delegate:delegate];
}

- (void)getURL:(NSURL *)url parameters:(NSDictionary *)parameters headers:(NSDictionary *)headers delegate:(id<LRRestyClientDelegate>)delegate;
{
  LRRestyRequest *request = [[LRRestyRequest alloc] initWithURL:url method:@"GET" client:self delegate:delegate];
  [request setQueryParameters:parameters];
  [request setHeaders:headers];
  [operationQueue addOperation:request];
  [request release];
}

@end

@implementation LRRestyRequest

@synthesize connectionError;
@synthesize responseData;
@synthesize response;

- (id)initWithURL:(NSURL *)aURL method:(NSString *)httpMethod client:(LRRestyClient *)theClient delegate:(id<LRRestyClientDelegate>)theDelegate;
{
  if (self = [super init]) {
    requestURL = [aURL retain];
    requestMethod = [httpMethod copy];
    delegate = [theDelegate retain];
    client = theClient;
  }
  return self;
}

- (void)dealloc
{
  [requestURL release];
  [requestMethod release];
  [delegate release];
  [super dealloc];
}

- (void)setQueryParameters:(NSDictionary *)parameters;
{
  if (parameters == nil) return;
  
  NSURL *URLWithParameters = [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@", [requestURL absoluteString], [parameters stringWithFormEncodedComponents]]];
  [requestURL release];
  requestURL = [URLWithParameters retain];
}

- (void)setHeaders:(NSDictionary *)headers
{
  if (headers == nil) return;
  
  [requestHeaders release];
  requestHeaders = [headers copy];
}

- (BOOL)isConcurrent
{
  return YES;
}

- (BOOL)isExecuting
{
  return _isExecuting;
}

- (BOOL)isFinished
{
  return _isFinished;
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"%@ %@ <LRRestyRequest>", requestMethod, requestURL];
}

- (void)start
{
  if (![NSThread isMainThread]) {
    return [self performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:YES];
  }
  [self setExecuting:YES];
  
  NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:requestURL];
  [requestHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
    [URLRequest addValue:value forHTTPHeaderField:key];
  }];
  
  NSURLConnection *connection = [NSURLConnection 
      connectionWithRequest:URLRequest
                   delegate:self];
    
  if (connection == nil) {
    [self setFinished:YES]; 
  }
}

#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)theResponse
{
  if (responseData == nil) {
    responseData = [[NSMutableData alloc] init];
  }
  self.response = (NSHTTPURLResponse *)theResponse;
  
  if ([self isCancelled]) {
    [connection cancel];
    [self finish];
  }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
  [responseData appendData:data]; 
  
  if ([self isCancelled]) {
    [connection cancel];
    [self finish];
  }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
  [self finish];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
  self.connectionError = error;
 
  [self setFinished:YES];
}

- (void)finish;
{
  LRRestyResponse *restResponse = [[LRRestyResponse alloc] 
          initWithStatus:self.response.statusCode 
            responseData:self.responseData 
                 headers:[self.response allHeaderFields]];
  
  [delegate restClient:client receivedResponse:restResponse];
  
  [restResponse release];
  [self setFinished:YES];
}

#pragma mark Private methods

- (void)setExecuting:(BOOL)isExecuting;
{
  [self willChangeValueForKey:@"isExecuting"];
  _isExecuting = isExecuting;
  [self didChangeValueForKey:@"isExecuting"];
}

- (void)setFinished:(BOOL)isFinished;
{
  [self willChangeValueForKey:@"isFinished"];
  [self setExecuting:NO];
  _isFinished = isFinished;
  [self didChangeValueForKey:@"isFinished"];
}

@end

