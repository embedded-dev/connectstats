//  MIT Licence
//
//  Created on 19/09/2016.
//
//  Copyright (c) 2016 Brice Rosenzweig.
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

#import "GCAppDelegate+Swift.h"
#import "ConnectStats-Swift.h"
#import "GCWebConnect+Requests.h"

@import UserNotifications;

#define GC_STARTING_FILE @"starting.log"

BOOL kOpenTemporary = false;

@implementation GCAppDelegate (Swift)

-(void)handleAppRating{
    [self initiateAppRating];
}

-(void)registerForPushNotifications{
    [[GCAppGlobal profile] configSet:CONFIG_NOTIFICATION_ENABLED boolVal:true];
    
    if( [[GCAppGlobal profile] serviceEnabled:gcServiceConnectStats] && [[GCAppGlobal profile] configGetBool:CONFIG_NOTIFICATION_ENABLED defaultValue:false]) {
        RZLog(RZLogInfo, @"connectstats enabled requesting notification");
        [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:UNAuthorizationOptionAlert completionHandler:^(BOOL granted, NSError*error){
            if( granted ){
                [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings*setting){
                    if( setting.authorizationStatus == UNAuthorizationStatusAuthorized ){
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            RZLog(RZLogInfo, @"Push Notification Granted, registering");
                            [[UIApplication sharedApplication] registerForRemoteNotifications];
                        });
                    }else{
                        RZLog(RZLogInfo, @"Push Notification Not Authorized");
                        if( [[GCAppGlobal profile] configGetBool:CONFIG_NOTIFICATION_PUSH_TYPE defaultValue:gcNotificationPushTypeNone] != gcNotificationPushTypeNone){
                            // Status changed from what was recorded, save it
                            dispatch_async(dispatch_get_main_queue(), ^(){
                                [[GCAppGlobal profile] configSet:CONFIG_NOTIFICATION_PUSH_TYPE boolVal:gcNotificationPushTypeNone];
                                [GCAppGlobal saveSettings];
                            });
                        }
                    }
                }];
            }else{
                RZLog(RZLogInfo, @"Not granted %@", error);
                if( [[GCAppGlobal profile] configGetBool:CONFIG_NOTIFICATION_PUSH_TYPE defaultValue:gcNotificationPushTypeNone] != gcNotificationPushTypeNone){
                    // Status changed from what was recorded, save it
                    dispatch_async(dispatch_get_main_queue(), ^(){
                        [[GCAppGlobal profile] configSet:CONFIG_NOTIFICATION_PUSH_TYPE boolVal:gcNotificationPushTypeNone];
                        [GCAppGlobal saveSettings];
                    });
                }
            }
        }];
    }
}

-(void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler{
    if( userInfo[@"activity_id"] != nil){
        RZLog(RZLogInfo,@"remote notification for activity %@",userInfo[@"activity_id"]);
    }else{
        RZLog(RZLogInfo,@"remote notification %@", userInfo);
    }
    //application.applicationIconBadgeNumber = 1;
    
    self.web.notificationHandler = ^(gcWebNotification notification){
        if( notification == gcWebNotificationError){
            self.web.notificationHandler = nil;
            completionHandler(UIBackgroundFetchResultFailed);
        }
        if( notification == gcWebNotificationEnd){
            self.web.notificationHandler = nil;
            completionHandler(UIBackgroundFetchResultNewData);
        }
    };
    
    if( ! [self.web servicesBackgroundUpdate]){
        self.web.notificationHandler = nil;
        completionHandler(UIBackgroundFetchResultNoData);
    }
    // Don't keep startup file
    [RZFileOrganizer removeEditableFile:GC_STARTING_FILE];
}


-(void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken{
    const uint8_t * data = deviceToken.bytes;
    
    NSMutableString * token = [NSMutableString string];
    for (NSUInteger i=0; i<deviceToken.length; i++) {
        [token appendFormat:@"%02hhX", data[i]];
    }
    NSString * existingToken = [[GCAppGlobal profile] configGetString:CONFIG_NOTIFICATION_DEVICE_TOKEN defaultValue:@""];
    if( ![token isEqualToString:existingToken] ){
        RZLog(RZLogInfo,@"remote notification registered with new token: %@", token);
        [[GCAppGlobal profile] configSet:CONFIG_NOTIFICATION_DEVICE_TOKEN stringVal:token];
        dispatch_async(dispatch_get_main_queue(), ^(){
            [GCAppGlobal saveSettings];
        });
        
    }else{
        RZLog(RZLogInfo,@"remote notification registered with same token: %@", token);
    }
}

-(void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error{
    NSLog(@"Failed to register %@", error);
}

-(void)handleFitFile:(NSData*)fitData{
    if( fitData.length  > 12){// minimum size for fit file include headers
        GCActivity * fitAct = RZReturnAutorelease([[GCActivity alloc] initWithId:[self.urlToOpen.path lastPathComponent] fitFileData:fitData fitFilePath:self.urlToOpen.path startTime:[NSDate date]]);
        RZLog(RZLogInfo, @"Opened temp fit %@", [RZMemory formatMemoryInUse]);
        if( kOpenTemporary ){
            [self.organizer registerTemporaryActivity:fitAct forActivityId:fitAct.activityId];
        }else{
            
            [self.organizer registerActivity:fitAct forActivityId:fitAct.activityId];
            [self.organizer registerActivity:fitAct.activityId withTrackpoints:fitAct.trackpoints andLaps:fitAct.laps];
        }
        dispatch_async(dispatch_get_main_queue(), ^(){
            [self handleFitFileDone:fitAct.activityId];
        });
    }else{
        RZLog(RZLogWarning, @"Handling fit file with no data")
    }
}

-(void)handleFitFileDone:(NSString*)aId{
    [self.actionDelegate focusOnActivityId:aId];
}
-(void)stravaSignout{
    [GCStravaRequestBase signout];
}

-(BOOL)startInit{
    NSString * filename = [RZFileOrganizer writeableFilePathIfExists:GC_STARTING_FILE];
    NSUInteger attempts = 1;
    NSError * e = nil;

    if (filename) {

        NSString * sofar = [NSString stringWithContentsOfFile:filename
                                            encoding:NSUTF8StringEncoding error:&e];

        if (sofar) {
            attempts = MAX(1, [sofar integerValue]+1);
        }else{
            RZLog(RZLogError, @"Failed to read initfile %@", e.localizedDescription);
        }
    }

    NSString * already = [NSString stringWithFormat:@"%lu",(unsigned long)attempts];
    if(![already writeToFile:[RZFileOrganizer writeableFilePath:GC_STARTING_FILE] atomically:YES encoding:NSUTF8StringEncoding error:&e]){
        RZLog(RZLogError, @"Failed to save startInit %@", e.localizedDescription);
    }

    return attempts < 3;
}

-(void)startSuccessful{
    static BOOL once = false;
    if (!once) {
        RZLog(RZLogInfo, @"Started");
        [RZFileOrganizer removeEditableFile:GC_STARTING_FILE];
        once = true;
        
        [self settingsUpdateCheckPostStart];
        [self startSuccessfulSwift];
        //[UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    }
}

@end
