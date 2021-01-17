//  MIT Licence
//
//  Created on 02/09/2012.
//
//  Copyright (c) 2012 Brice Rosenzweig.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//  

#import "GCWebConnect.h"

// signed in failed
// query failed need login
// parsing failed
// user name is valid
//
// logging failed message: @"Invalid username/password combination."
// logging succeede message: @"You are signed in as"
// query failed need login: @"HTTP Status 403 - Access is denied"

NSString * GCWebStatusDescription(GCWebStatus status){
    NSString * rv = @"";
    switch (status) {
        case GCWebStatusOK:
            rv = NSLocalizedString(@"Ok", @"GCWebStatus");
            break;
        case GCWebStatusAccessDenied:
            rv = NSLocalizedString(@"Access denied", @"GCWebStatus");
            break;
        case GCWebStatusParsingFailed:
            rv = NSLocalizedString(@"Parsing failed", @"GCWebStatus");
            break;
        case GCWebStatusConnectionError:
            rv = NSLocalizedString(@"Connection error", @"GCWebStatus");
            break;
        case GCWebStatusLoginFailed:
            rv = NSLocalizedString(@"Invalid name or password", @"GCWebStatus");
            break;
        case GCWebStatusTempUnavailable:
            rv = NSLocalizedString(@"Temporarily Unavailable", @"GCWebStatus");
            break;
        case GCWebStatusDeletedActivity:
            rv = NSLocalizedString(@"Activity was deleted", @"GCWebStatus");
            break;
        case GCWebStatusInternalLogicError:
            rv = NSLocalizedString(@"Internal Logic Error", @"GCWebStatus");
            break;
        case GCWebStatusServiceLogicError:
            rv = NSLocalizedString(@"Service Logic Error", @"GCWebStatus");
            break;
        case GCWebStatusRequireModern:
            rv = NSLocalizedString(@"Switch to Garmin Connect Modern required", @"GCWebStatus");
            break;
        case GCWebStatusRequirePasswordRenew:
            rv = NSLocalizedString(@"Your password needs to be renewed on Garmin Connect. Please login via a browser to garmin, change your password and try again.", @"GCWebStatus");
            break;
        case GCWebStatusCustomMessage:
            rv = NSLocalizedString(@"Custom Message", @"GCWebStatus");
            break;
        case GCWebStatusAccountLocked:
            rv = NSLocalizedString(@"Account Locked", @"GCWebStatus");
            break;

    }
    return rv;
}

NSString * GCWebStatusShortDescription(GCWebStatus status){
    NSString * rv = @"";
    switch (status) {
        case GCWebStatusOK:
            rv = @"OK";
            break;
        case GCWebStatusAccessDenied:
            rv = @"AccessDenied";
            break;
        case GCWebStatusParsingFailed:
            rv = @"ParsingFailed";
            break;
        case GCWebStatusConnectionError:
            rv = @"ConnectionError";
            break;
        case GCWebStatusLoginFailed:
            rv = @"LoginFailed";
            break;
        case GCWebStatusTempUnavailable:
            rv = @"TempUnavailable";
            break;
        case GCWebStatusDeletedActivity:
            rv = @"DeletedActivity";
            break;
        case GCWebStatusInternalLogicError:
            rv = @"InternalLogicError";
            break;
        case GCWebStatusServiceLogicError:
            rv = @"ServiceInternalError";
            break;
        case GCWebStatusRequireModern:
            rv = @"RequireModern";
            break;
        case GCWebStatusRequirePasswordRenew:
            rv = @"RequirePasswordRenew";
            break;
        case GCWebStatusCustomMessage:
            rv = @"CustomMessage";
            break;
        case GCWebStatusAccountLocked:
            rv = @"AccountLocked";
            break;
    }
    return rv;
}


@interface GCServiceStatusHolder : NSObject

@property (nonatomic,assign) GCWebStatus status;
@property (nonatomic,assign) BOOL loginSuccessful;
@property (nonatomic,assign) BOOL secondTry;
@property (nonatomic,retain) NSError * lastError;
@property (nonatomic,retain) NSString * customMessage;
+(GCServiceStatusHolder*)statusHolder;
@end

@implementation GCServiceStatusHolder
#if !__has_feature(objc_arc)
-(void)dealloc{
    [_lastError release];
    [_customMessage release];
    [super dealloc];
}
#endif
+(GCServiceStatusHolder*)statusHolder{
    GCServiceStatusHolder * rv = RZReturnAutorelease([[GCServiceStatusHolder alloc] init]);
    return rv;
}

-(NSString*)description{
    return [NSString stringWithFormat:@"<GCServiceStatus: %@(%d) %@>",
            GCWebStatusShortDescription(_status),
            (int)_status,
            _loginSuccessful?@"Logged in":@"No Login"];
}
@end

#pragma mark -

@interface GCWebConnect ()
@property (retain,nonatomic) NSMutableArray<id<GCWebRequest>> * requests;
@property (retain,nonatomic) NSMutableArray<id<GCWebRequest>> * doneRequests;
@property (nonatomic,assign) NSUInteger lastBandwidth;
@property (nonatomic,retain) RZRemoteDownload * remoteDownload;
@property (nonatomic,retain) id<GCWebRequest> currentRequestObject;
@property (nonatomic,retain) NSMutableArray<GCServiceStatusHolder*> * serviceStatus;
@property (nonatomic,assign) BOOL started;
@end

@implementation GCWebConnect

-(GCWebConnect*)init{
    self = [super init];
	if( self ){
        self.requests = [NSMutableArray array];
        self.doneRequests = [NSMutableArray array];
        self.currentRequestObject = nil;
        self.started = false;

        self.serviceStatus = [NSMutableArray arrayWithCapacity:gcWebServiceEnd];
        for (NSUInteger i=0; i<gcWebServiceEnd; i++) {
            [self.serviceStatus addObject:[GCServiceStatusHolder statusHolder]];
        }

    }
    return self;
}

#if !__has_feature(objc_arc)
-(void)dealloc{
    [_remoteDownload release];
    [_requests release];
    [_doneRequests release];
    [_currentRequestObject release];
    [_serviceStatus release];
    [_lastError release];
    [_worker release];
    
    [_validateNextSearch release];
    
    [super dealloc];
}
#endif

-(NSString*)webServiceDescription:(gcWebService)service{
    switch (service) {
        case gcWebServiceStrava:
            return @"Strava";
        case gcWebServiceGarmin:
            return @"Garmin";
        case gcWebServiceHealthStore:
            return @"HealthStore";
        case gcWebServiceConnectStats:
            return @"ConnectStats";
        case gcWebServiceEnd:
        case gcWebServiceNone:
            return @"Other";
    }
    return nil;
}
-(NSString*)statusDescriptionForService:(gcWebService)service{
    GCServiceStatusHolder * holder = [self serviceHolderFor:service];
    if (holder.status == GCWebStatusConnectionError && holder.lastError) {
        return [NSString stringWithFormat:@"%@: %@", GCWebStatusDescription(holder.status),holder.lastError.localizedDescription];
    }else if( holder.status == GCWebStatusCustomMessage && holder.customMessage != nil){
        return holder.customMessage;
    }else{
        return GCWebStatusDescription(holder.status);
    }
}

-(GCServiceStatusHolder*)serviceHolderFor:(gcWebService)service{
    return service < _serviceStatus.count ? self.serviceStatus[service] : nil;
}

-(GCWebStatus)statusForService:(gcWebService)service{
    return [self serviceHolderFor:service].status;
}
-(void)loginSuccess:(gcWebService)service{
    [[self serviceHolderFor:service] setLoginSuccessful:YES];
}
-(void)requireLogin:(gcWebService)service{
    [[self serviceHolderFor:service] setLoginSuccessful:NO];
}

-(BOOL)didLoginSuccessfully:(gcWebService)service{
    return [self serviceHolderFor:service].loginSuccessful;
}

-(void)resetSuccessfulLogin{
    for (NSUInteger i=0; i<_serviceStatus.count; i++) {
        [self serviceHolderFor:i].loginSuccessful=false;
    }
}
#pragma mark - login logout

-(void)clearCookies{
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *each in cookieStorage.cookies) {
        [cookieStorage deleteCookie:each];
    }
}


#pragma mark - processing

-(BOOL)checkRequestExists:(id<GCWebRequest>)req{
    BOOL already = false;
    for (id<GCWebRequest> exreq in _requests) {
        if ([exreq isMemberOfClass:[req class]]) {
            if ([req respondsToSelector:@selector(isSameAsRequest:)]) {
                already = [exreq isSameAsRequest:req];
            }else if ([[exreq url] isEqualToString:[req url]]){
                already = true;
            }
        }
    }
    return already;
}

-(void)resetStatus{
    for (gcWebService i=0; i<gcWebServiceEnd; i++) {
        GCServiceStatusHolder * holder=[self serviceHolderFor:i];
        holder.status = GCWebStatusOK;
        holder.secondTry = false;

    }
    _status = GCWebStatusOK;
}

-(void)addRequest:(id<GCWebRequest>)req{
    [self addRequest:req priority:false];
}

-(void)clearRequests{
    @synchronized (_requests) {
        [self.requests removeAllObjects];
    }
}

-(void)clearDoneRequests{
    // dispatch on main queue this is where some notification/user update on ui may still
    // be processing
    dispatch_async(dispatch_get_main_queue(), ^(){
        @synchronized (self.requests) {
            [self.doneRequests removeAllObjects];
        }
    });
}
-(void)addRequest:(id<GCWebRequest>)req priority:(BOOL)isPriority{
    if (!req) {
        return;
    }

    // First new request, reset status
    if ( ! self.started ) {
        [self resetStatus];
        self.started = true;
    }

    @synchronized (_requests) {
        if (![self checkRequestExists:req]) {
        // if priority: add it to next slot, else at the end
            if (isPriority || ([req respondsToSelector:@selector(priorityRequest)] &&
                               [req priorityRequest]) ) {
                [_requests insertObject:req atIndex:0];
            }else{
                [_requests addObject:req];
            }
        }
    }
    [self next];
}

-(NSString*)describeReq:(id<GCWebRequest>)req{
    NSString * rv = [req debugDescription];
    return rv ?: @"<NullReq>";
}

-(void)log:(id<GCWebRequest>)req stage:(NSString*)stage{
    RZLog(RZLogInfo, @"%@ %@ %@",stage,[RZMemory formatMemoryInUse],[req debugDescription]);
}

-(void)executeCurrentRequest{
    id<GCWebRequest> req = self.currentRequestObject;
    
    if ([req respondsToSelector:@selector(preConnectionSetup)]) {
        [req preConnectionSetup];
    }

    if ([req respondsToSelector:@selector(preparedUrlRequest)]) {
        NSURLRequest * preparedUrlRequest = [req preparedUrlRequest];
        if (preparedUrlRequest==nil) {
            self.remoteDownload = nil;
            if(self.worker){
                dispatch_async(self.worker,^(){
                    [self downloadNoUrl];
                });
            }else{
                [self downloadNoUrl];
            }

        }else{
            self.remoteDownload = RZReturnAutorelease([[RZRemoteDownload alloc] initWithURLRequest:preparedUrlRequest andDelegate:self]);
        }
    }else{
        NSString * url = [req url];
        if (url == nil) {
            self.remoteDownload = nil;
            if(self.worker){
                dispatch_async(self.worker,^(){
                    [self downloadNoUrl];
                });
            }else{
                [self downloadNoUrl];
            }
        }else{
            NSData * fileData = nil;
            NSString * fileName = nil;
            NSDictionary * postData = nil;
            NSDictionary * deleteData = nil;
            NSDictionary * postJson = nil;
            
            BOOL hasFiledata = false;
            BOOL hasPost = false;
            BOOL hasDelete = false;
            BOOL hasPostJson = false;
            
            if( [req respondsToSelector:@selector(fileData)]){
                fileData = [req fileData];
                hasFiledata = fileData != nil;
                if( [req respondsToSelector:@selector(fileName)]){
                    fileName = [req fileName];
                }else{
                    fileName = @"temp";
                }
            }
            
            if( [req respondsToSelector:@selector(postData)]){
                postData = [req postData];
                hasPost = postData != nil;
            }
            
            if( [req respondsToSelector:@selector(deleteData)]){
                deleteData = [req deleteData];
                hasDelete = (deleteData != nil );
            }
            
            if( [req respondsToSelector:@selector(postJson)]){
                postJson = [req postJson];
                hasPostJson = postJson != nil;
            }
            
            if (hasFiledata) {
                self.remoteDownload = RZReturnAutorelease([[RZRemoteDownload alloc] initWithURL:url
                                                                    postData:postData
                                                                    fileName:fileName
                                                                    fileData:fileData
                                                                 andDelegate:self]);
            }else if (hasPost) {
                self.remoteDownload = RZReturnAutorelease([[RZRemoteDownload alloc] initWithURL:url
                                                                    postData:postData
                                                                 andDelegate:self]);
            }else if(hasPostJson){
                self.remoteDownload = RZReturnAutorelease([[RZRemoteDownload alloc] initWithURL:url
                                                                    postJson:postJson
                                                                 andDelegate:self]);


            }else if (hasDelete){
                self.remoteDownload = RZReturnAutorelease([[RZRemoteDownload alloc] initWithURL:url
                                                                  deleteData:deleteData
                                                                 andDelegate:self]);
            }else{
                self.remoteDownload = RZReturnAutorelease([[RZRemoteDownload alloc] initWithURL:url
                                                                 andDelegate:self]);
            }
        }
    }

}

-(void)next{
    if (self.currentRequestObject==nil && _requests.count > 0) { // not currently processing one

        @synchronized (_requests) {
            self.currentRequestObject = _requests[0];
            [_requests removeObjectAtIndex:0];
            // Add to holder so they stay in memory until all done for async notifications
            [self.doneRequests addObject:self.currentRequestObject];
        }
        id<GCWebRequest> req = self.currentRequestObject;

        gcWebService service = [req service];
        GCWebStatus serviceStatus = [self serviceHolderFor:service].status;

        if (serviceStatus != GCWebStatusOK) {
            // skip this one
            self.currentRequestObject = nil;
            if(self.worker){
                dispatch_async(self.worker,^(){
                [self next];
                });
            }else{
                [self next];
            }
            return;
        }
        self.lastError = nil;
        [self log:req stage:@"start"];
        
        [self executeCurrentRequest];
        
        [self notifyForString:NOTIFY_NEXT safeTries:5];
    }else{
        if (_requests.count == 0) {
            RZLog(RZLogInfo, @"end data=%@", [GCUnit formatBytes:[RZRemoteDownload totalDataUsage]]);
            self.currentRequestObject = nil;

            BOOL someError = false;
            for (gcWebService i=0; i<gcWebServiceEnd; i++) {
                if ([self serviceHolderFor:i].status!=GCWebStatusOK) {
                    someError = true;
                }
            }
            self.started = false;
            if (someError) {
                [self notifyForString:NOTIFY_ERROR];
                [self clearDoneRequests];
            }else{
                [self notifyForString:NOTIFY_END];
                [self clearDoneRequests];
            }
        }
    }
}
-(NSString*)currentUrl{
    NSString * rv = @"";
    if (self.currentRequestObject) {
        rv = [self.currentRequestObject url];
    }
    return rv;
}

-(NSString*)parentCurrentDescription{
    return [self currentDescription];
}

-(NSString*)currentDebugDescription{
    NSString * rv = @"No Requests";

    if ([self.currentRequestObject respondsToSelector:@selector(debugDescription)]) {
        rv = [self.currentRequestObject debugDescription];
    }
    return rv;
}

-(NSString*)currentDescription{
    NSString * rv = @"";

    if (self.currentRequestObject) {
        rv = [self.currentRequestObject description];
    }
    return rv;
}

-(void)downloadNoUrl{
    [self downloadStringSuccessful:nil string:nil];
}

-(void)downloadFailed:(RZRemoteDownload*)connection{
    RZLog(RZLogWarning, @"connection error %@ %@", [self describeReq:self.currentRequestObject], self.currentRequestObject.url);
    self.lastError = connection.lastError;
    self.currentRequestObject = nil;
    _status = GCWebStatusConnectionError;
    id<GCWebRequest> req = self.currentRequestObject;

    gcWebService service = [req service];
    if (service < _serviceStatus.count) {
        [self serviceHolderFor:service].status = _status;
        [self serviceHolderFor:service].lastError = connection.lastError;
    }

    [self notifyForString:NOTIFY_ERROR];
}

-(void)downloadDataSuccessful:(RZRemoteDownload *)connection data:(NSData *)data{
    if (![self checkState]) {
        return;
    }

    id<GCWebRequest> req = self.currentRequestObject;
    self.lastStatusCode  = connection ? [connection responseCode] : 0;
    if ([req respondsToSelector:@selector(process: andDelegate:)]) {
        [req process:data andDelegate:self];
    }else{
        RZLog(RZLogWarning, @"Expected text but received data from %@", [self describeReq:req]);
        NSStringEncoding encoding = NSUTF8StringEncoding;
        NSString * theString = RZReturnAutorelease([[NSString alloc] initWithData:data encoding:encoding]);

        [req process:theString encoding:encoding andDelegate:self ];
    }

}
-(void)downloadStringSuccessful:(id)connection string:(NSString*)theString{
    if (![self checkState]) {
        return;
    }

    id<GCWebRequest> req = self.currentRequestObject;
    self.lastStatusCode  = connection ? [connection responseCode] : 0;
    [req process:theString encoding:connection ? [connection receivedEncoding] : NSUTF8StringEncoding andDelegate:self ];
}

-(void)authorizeRequest:(nonnull NSMutableURLRequest *)request completionHandler:(void (^_Nonnull)(NSError * _Nullable error))handler{
    if( [self.currentRequestObject respondsToSelector:@selector(authorizeRequest:completionHandler:)]){
        [self.currentRequestObject authorizeRequest:request completionHandler:handler];
    }else{
        // no error
        handler(nil);
    }
}

-(RemoteDownloadPrepareUrl)prepareUrlFunc{
    if ([self.currentRequestObject respondsToSelector:@selector(prepareUrlFunc)]) {
        return [self.currentRequestObject prepareUrlFunc];
    }
    return nil;
}

-(NSString*)httpUserAgent{
    if ([self.currentRequestObject respondsToSelector:@selector(httpUserAgent)]) {
        return [self.currentRequestObject httpUserAgent];
    }
    return nil;
}

-(void)processNewStage{
    [self notifyForString:NOTIFY_CHANGE];
}

-(BOOL)checkState{
    return true;
}

-(BOOL)isProcessing{
    return self.currentRequestObject != nil;
}

-(void)processDone:(id)areq{
    if (![self checkState]) {
        return;
    }
    id<GCWebRequest> req = self.currentRequestObject;
    if (req != areq) {
        RZLog(RZLogError,@"Inconsistent req %@",[self currentDescription]);
    }

    _status = [req status];
    gcWebService service = [req service];
    if (service < _serviceStatus.count) {
        [self serviceHolderFor:service].status = _status;
        
        if( _status == GCWebStatusCustomMessage ){
            if( [req respondsToSelector:@selector(customMessage)]){
                [self serviceHolderFor:service].customMessage = req.customMessage;
            }
        }
        if ([req respondsToSelector:@selector(lastError)]) {
            self.lastError = [req lastError];
            [self serviceHolderFor:service].lastError = self.lastError;
        }
    }

    id<GCWebRequest> nextreq = [req nextReq];
    RZRetain(req);// make sure doesn't go away when set currentRequestObject to nil
    if (_status == GCWebStatusOK) {
        if (nextreq) {
            [self addRequest:nextreq];
        }
        // important processing=false AFTER the addRequest above
        self.currentRequestObject = nil;
        if ([req respondsToSelector:@selector(activityId)]) {
            [self notifyForString:[req activityId]];
        }
    }else{
        BOOL reportError = true;
        if ([req respondsToSelector:@selector(remediationReq)]) {
            id<GCWebRequest> remreq = [req remediationReq];
            if (remreq && [self serviceHolderFor:service].secondTry==false) {
                //[self clearCookies];
                RZLog(RZLogInfo, @"%@ %@: trying remediation req %@", GCWebStatusShortDescription(_status), [self describeReq:req], [self describeReq:remreq]);

                //Put it back at top of queue, with remediation request
                [self addRequest:req priority:YES];
                [self addRequest:remreq priority:YES];
                [self serviceHolderFor:service].secondTry = true;
                [self serviceHolderFor:service].status = GCWebStatusOK;
                _status = GCWebStatusOK;
                reportError = false;
            }
        }
        if (reportError) {
            RZLog(RZLogWarning, @"error %@ %@ %@ %@",[self describeReq:req],GCWebStatusDescription(_status),[req description],[req url]);
        }
        self.currentRequestObject = nil;
    }
    if (self.worker) {
        dispatch_async(self.worker,^(){
            [self next];
        });
    }else{
        if(self.worker){
            dispatch_async(self.worker,^(){
                [self next];
            });
        }else{
            [self next];
        }
    }

    RZRelease(req);
}


+(void)sanityCheck{

}

@end
