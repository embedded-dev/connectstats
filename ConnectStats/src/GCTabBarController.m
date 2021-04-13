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

#import "GCTabBarController.h"
#import "GCAppGlobal.h"
#import "Flurry.h"
@import RZExternal;
#import "GCViewIcons.h"
#import "GCWebConnect+Requests.h"

@interface GCTabBarController ()
@property (nonatomic,retain)  GCActivityListViewController * activityListViewController;
@property (nonatomic,retain)  GCActivityDetailViewController * activityDetailViewController;
@property (nonatomic,retain)  KalViewController * calendarViewController;
@property (nonatomic,retain)  GCStatsMultiFieldViewController * fieldListViewController;
@property (nonatomic,retain)  GCSettingsViewController * settingsViewController;
@property (nonatomic,retain)  GCCalendarDataSource * calendarDataSource;

@property (nonatomic,retain) UITabBarItem * settingsItem;
@end

@implementation GCTabBarController

-(void)dealloc{
    [_activityDetailViewController release];
    [_activityListViewController release];
    [_calendarViewController release];
    [_fieldListViewController release];
    [_settingsViewController release];
    [_calendarDataSource release];
    [_settingsItem release];
    
    [super dealloc];
}

-(void)startWorkflow{
    if ([GCAppGlobal connectStatsVersion]) {
        [self startWorkflowConnectStats];
    }else{
        [self startWorkflowHealthStats];
    }
}

-(void)startWorkflowHealthStats{
    NSInteger last_version = [GCAppGlobal configGetInt:CONFIG_LAST_USED_VERSION defaultValue:0];
    if (last_version == 0) {
        [GCAppGlobal configSet:CONFIG_LAST_USED_VERSION intVal:1];
    }

    if (![[GCAppGlobal profile] configGetBool:CONFIG_HEALTHKIT_SOURCE_CHECKED defaultValue:false]) {
        [[GCAppGlobal web] healthStoreCheckSource];
        [GCAppGlobal saveSettings];
        self.selectedIndex = 4;
        [self.settingsViewController showServices];
    }else{
        if ([[GCAppGlobal profile] profileRequireSetup]) {
            self.selectedIndex = 4;
            [self.settingsViewController showServices];
        }else{
            self.selectedIndex = 2;
        }
    }
}

-(void)startWorkflowConnectStats{
    NSInteger last_version = [GCAppGlobal configGetInt:CONFIG_LAST_USED_VERSION defaultValue:0];
    if (last_version == 0) {

        NSString * msg = NSLocalizedString(@"Setup your service, enter your user name and password to start downloading your activities", @"Initial");

        [self presentSimpleAlertWithTitle:NSLocalizedString(@"Welcome", @"Initial") message:msg];

        [GCAppGlobal configSet:CONFIG_LAST_USED_VERSION intVal:1];
        [GCAppGlobal saveSettings];
        self.selectedIndex = 4;
        [self.settingsViewController showServices];

    }else{
        if ([[GCAppGlobal profile] profileRequireSetup]) {
            self.selectedIndex = 4;
            [self.settingsViewController showServices];
        }
    }
}
-(void)loadView{
    [super loadView];
    self.delegate = self;

    _activityListViewController = [[GCActivityListViewController		alloc] init];
    _activityDetailViewController = [[GCActivityDetailViewController alloc] init];
    _activityListViewController.detailController = _activityDetailViewController;
    _calendarViewController = [[KalViewController alloc] init];
    _calendarDataSource = [[GCCalendarDataSource alloc] init];
    _calendarDataSource.presentingViewController = _calendarViewController;
    _calendarViewController.dataSource = _calendarDataSource;
    _calendarViewController.delegate = _calendarDataSource;
    _fieldListViewController = [[GCStatsMultiFieldViewController alloc] initWithStyle:UITableViewStylePlain];
    _settingsViewController = [[GCSettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
    
    UIImage * activityImg = [GCViewIcons tabBarIconFor:gcIconTabList];
    UIImage * detailImg   = [GCViewIcons tabBarIconFor:gcIconTabMap];
    UIImage * calendarImg = [GCViewIcons tabBarIconFor:gcIconTabCalendar];
    UIImage * statsImg    = [GCViewIcons tabBarIconFor:gcIconTabStats];
    UIImage * configImg   = [GCViewIcons tabBarIconFor:gcIconTabSettings];

    NSString * detailsTitle = NSLocalizedString(@"Details",     @"TabBar Title");
    NSString * activityTitle = NSLocalizedString(@"Activities",  @"TabBar Title");

    UITabBarItem * activityItem	= [[UITabBarItem alloc] initWithTitle:activityTitle                                         image:activityImg tag:0];
    UITabBarItem * detailItem	= [[UITabBarItem alloc] initWithTitle:detailsTitle                                          image:detailImg tag:0];
    UITabBarItem * calendarItem	= [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Calendar",    @"TabBar Title")	image:calendarImg tag:0];
    UITabBarItem * statsItem	= [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Stats",       @"TabBar Title")	image:statsImg tag:0];
    UITabBarItem * settingsItem	= [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Config",      @"TabBar Title")	image:configImg tag:0];
    self.settingsItem = settingsItem;
    
    UINavigationController *activityNav	= [[UINavigationController alloc] initWithRootViewController:_activityListViewController];
    UINavigationController *detailNav	= [[UINavigationController alloc] initWithRootViewController:_activityDetailViewController];
    UINavigationController *calendarNav	= [[UINavigationController alloc] initWithRootViewController:_calendarViewController];
    UINavigationController *statsNav	= [[UINavigationController alloc] initWithRootViewController:_fieldListViewController];
    UINavigationController *settingsNav	= [[UINavigationController alloc] initWithRootViewController:_settingsViewController];

    (statsNav.navigationBar).titleTextAttributes = @{NSFontAttributeName:[GCViewConfig boldSystemFontOfSize:16.]};

    detailNav.delegate = self;

    UIBarStyle style = UIBarStyleDefault;

    activityNav.navigationBar.barStyle						= style;
    detailNav.navigationBar.barStyle						= style;
    calendarNav.navigationBar.barStyle                      = style;
    statsNav.navigationBar.barStyle                         = style;
    settingsNav.navigationBar.barStyle                      = style;

    [detailNav setNavigationBarHidden:NO animated:YES];
    [activityNav setNavigationBarHidden:NO animated:YES];
    [statsNav setNavigationBarHidden:NO animated:YES];
    [settingsNav setNavigationBarHidden:NO animated:YES];
    [calendarNav setNavigationBarHidden:NO animated:YES];

    activityNav.tabBarItem	= activityItem;
    detailNav.tabBarItem = detailItem;
    calendarNav.tabBarItem = calendarItem;
    statsNav.tabBarItem = statsItem;
    settingsNav.tabBarItem = settingsItem;

    self.view.autoresizesSubviews = YES;
    self.view.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);

    self.viewControllers = @[activityNav,detailNav,statsNav,calendarNav,settingsNav];

    [GCViewConfig setupViewController:_fieldListViewController];
    [GCViewConfig setupViewController:_activityListViewController];
    [GCViewConfig setupViewController:_activityDetailViewController];
    [GCViewConfig setupViewController:_calendarViewController];
    [GCViewConfig setupViewController:_settingsViewController];

    [activityItem release];
    [detailItem release];
    [calendarItem release];
    [statsItem release];
    [settingsItem release];

    [activityNav release];
    [detailNav release];
    [calendarNav release];
    [statsNav release];
    [settingsNav release];

    [self startWorkflow];
}
-(void)viewDidAppear:(BOOL)animated{

    [super viewDidAppear:animated];
    
    [GCAppGlobal startSuccessful];

}

-(void)updateBadge:(NSUInteger)count{
    dispatch_async(dispatch_get_main_queue(), ^(){
        if([GCAppGlobal configGetBool:CONFIG_ENABLE_REMOTE_STATUS defaultValue:TRUE]){
            self.settingsItem.badgeValue = count > 0 ? [@(count) stringValue] : nil;
        }else{
            self.settingsItem.badgeValue = nil;
        }
        [self.view setNeedsDisplay];
    });
}

-(void)beginRefreshing{
    self.selectedIndex = 0;
    //[[GCAppGlobal web] garminLogin];
    [self.activityListViewController beginRefreshing];
}

-(void)login{
    self.selectedIndex = 0;
    [[GCAppGlobal web] garminLogin];
    [self.activityListViewController beginRefreshing];
    [self.activityListViewController refreshData];
}

-(void)logout{
    self.selectedIndex = 0;
    [[GCAppGlobal web] garminLogout];
    [self.activityListViewController beginRefreshing];
    //[activityListViewController refreshData];
}

-(void)focusOnActivityAtIndex:(NSUInteger)aIdx{
    GCActivitiesOrganizer * organizer = [GCAppGlobal organizer];
    organizer.currentActivityIndex = aIdx;
    [self.activityDetailViewController.navigationController popToRootViewControllerAnimated:YES];
    self.selectedIndex = 1;
    [self.activityDetailViewController.navigationController setNavigationBarHidden:YES animated:YES];
    [self.activityDetailViewController notifyCallBack:nil info:nil];
    [organizer notifyOnMainThread:NOTIFY_CHANGE];
}

-(void)focusOnActivityId:(NSString*)aId{
    GCActivitiesOrganizer * organizer = [GCAppGlobal organizer];
    [organizer setCurrentActivityId:aId];
    [self.activityDetailViewController notifyCallBack:nil info:nil];
    [self.activityDetailViewController.navigationController popToRootViewControllerAnimated:YES];
    self.selectedIndex = 1;
    [self.activityDetailViewController.navigationController setNavigationBarHidden:YES animated:YES];
}
-(void)focusOnListWithFilter:(NSString*)aFilter{
    [self.activityListViewController setupFilterForString:aFilter];
    [self setSelectedIndex:0];
}
-(void)focusOnActivityList{
    self.selectedIndex = 0;
}
-(void)focusOnStatsSummary{
    self.selectedIndex = 2;
}

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
}

- (void)navigationController:(UINavigationController *)navigationController
       didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (viewController == self.activityDetailViewController) {
        [navigationController setNavigationBarHidden:YES animated:YES];
    }
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController{
    if (viewController == self.calendarViewController.navigationController) {
        if ([[GCAppGlobal organizer] countOfActivities]) {
            [self.calendarViewController showAndSelectDate:[[GCAppGlobal organizer] currentActivity].date];
        }
        [Flurry logEvent:EVENT_CALENDAR];
    }
}

- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController{
    return TRUE;
}
-(UINavigationController*)currentNavigationController{
    UIViewController * vc = self.selectedViewController;
    if ([vc isKindOfClass:[UINavigationController class]]) {
        return (UINavigationController*)vc;
    }
    return vc.navigationController;
}


@end
