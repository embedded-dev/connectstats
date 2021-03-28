//
//  GCTestsSamples.m
//  GarminConnect
//
//  Created by Brice Rosenzweig on 01/02/2014.
//  Copyright (c) 2014 Brice Rosenzweig. All rights reserved.
//

#import "GCTestsSamples.h"
#import "GCActivity.h"
#import "GCActivity+Database.h"
#import "GCActivitiesOrganizer.h"
#import "GCHealthOrganizer.h"

@implementation GCTestsSamples


// {1.2,1.3,2.1}
// {3.2,2.1,3.2,2.3,2.9,3.0,2.1,1.5,5.2,4.2,3.7}
// {0.2}
+(NSDictionary*)aggregateSample{
    // CutOff November 13 (last):
    //    Nov -> Cnt 1, Sum 0.2
    //    Oct -> Cnt 2, Sum 3.2+2.1=5.3
    //    Sep -> Cnt 1, Sum 1.2
    NSDictionary * sample = @{
                              @"2012-09-13T18:48:16.000Z":@(1.2), //thu
                              @"2012-09-14T19:10:16.000Z":@(1.3), //fri
                              @"2012-09-21T18:10:01.000Z":@(2.1), //fri
                              @"2012-10-10T15:00:01.000Z":@(3.2), //wed
                              @"2012-10-11T15:00:01.000Z":@(2.1), //thu
                              @"2012-10-21T15:00:01.000Z":@(3.2), //sun
                              @"2012-10-22T15:00:01.000Z":@(2.3), //mon
                              @"2012-10-23T15:00:01.000Z":@(2.9), //tue
                              @"2012-10-24T15:00:01.000Z":@(3.0), //wed
                              @"2012-10-25T15:00:01.000Z":@(2.1), //thu
                              @"2012-10-26T15:00:01.000Z":@(1.5), //fri
                              @"2012-10-27T15:00:01.000Z":@(5.2), //sat
                              @"2012-10-28T15:00:01.000Z":@(4.2), //sun
                              @"2012-10-29T15:00:01.000Z":@(3.7), //mon
                              @"2012-11-13T16:01:02.000Z":@(0.2), //tue
                              };
    return sample;
}
+(NSDictionary*)aggregateExpected{
    NSDictionary * expected = @{
                                @"2012-09-09T18:48:16.000Z":@[  @(1.25),        @(2.5),     @(1.3) ],
                                @"2012-09-16T18:48:16.000Z":@[  @(2.1),         @(2.1),     @(2.1) ],
                                @"2012-10-07T15:00:01.000Z":@[  @(2.65),        @(5.3),     @(3.2) ],
                                @"2012-10-21T15:00:01.000Z":@[  @(2.885714286), @(20.2),    @(5.2) ],
                                @"2012-10-28T18:48:16.000Z":@[  @(3.95),        @(7.9),     @(4.2) ],
                                @"2012-11-11T18:48:16.000Z":@[  @(0.2),         @(0.2),     @(0.2) ]
                                };
    return expected;
}


+(GCActivity*)sampleCycling{
    GCActivity * rv = [[[GCActivity alloc] init] autorelease];
    [rv changeActivityType:[GCActivityType cycling]];
    rv.activityId = @"100";
    rv.activityName = @"Untitled";
    rv.trackFlags = gcFieldFlagWeightedMeanSpeed|gcFieldFlagWeightedMeanHeartRate;
    rv.flags = gcFieldFlagWeightedMeanHeartRate|gcFieldFlagWeightedMeanSpeed;

    rv.date = [NSDate dateForRFC3339DateTimeString:@"2012-11-11T18:48:16.000Z"];
    rv.location = @"London, GC";
    
    /*
    double speedKph = 15.;
    double durationSecond = 60.;
    double distanceKph = speedKph*durationSecond/3600.;
    double heartRateBpm = 130.;
    NSArray * metaDataInfo = @[ @[@"eventType", @"Uncategorized", @"uncategorized"], @[@"device", @"Garmin Edge 510", @"edge510"]];
    NSArray * summaryDataInfo = @[@[@"WeightedMeanSpeed",@"kph",@(speedKph)],
                                  @[@"SumDistance", @"kilometer", @(distanceKph)],
                                  @[@"WeightedMeanHeartRate", @"bpm", @(heartRateBpm)]
                                  
                                  ];
    */
    return rv;
}

+(FMDatabase*)createEmptyActivityDatabase:(NSString*)name{
    [RZFileOrganizer removeEditableFile:name];
    FMDatabase * db = [FMDatabase databaseWithPath:[RZFileOrganizer writeableFilePath:name]];
    [db open];
    [GCActivitiesOrganizer ensureDbStructure:db];

    return db;
}
+(GCActivitiesOrganizer*)createEmptyOrganizer:(NSString*)dbname{
    NSString * dbfp = [RZFileOrganizer writeableFilePath:dbname];
    [RZFileOrganizer removeEditableFile:dbname];
    FMDatabase * db = [FMDatabase databaseWithPath:dbfp];
    [db open];
    [GCActivitiesOrganizer ensureDbStructure:db];
    [GCHealthOrganizer ensureDbStructure:db];
    GCActivitiesOrganizer * organizer = [[[GCActivitiesOrganizer alloc] initTestModeWithDb:db] autorelease];
    GCHealthOrganizer * health = [[[GCHealthOrganizer alloc] initWithDb:db andThread:nil] autorelease];
    organizer.health = health;

    return organizer;
}
+(FMDatabase*)sampleActivityDatabase:(NSString*)name{

    [RZFileOrganizer createEditableCopyOfFile:name forClass:self];
    FMDatabase * db = [FMDatabase databaseWithPath:[RZFileOrganizer writeableFilePath:name]];
    [db open];
    int versionInitial = [db intForQuery:@"SELECT MAX(version) FROM gc_version"];
    [GCActivity ensureDbStructure:db];
    int versionFinal = [db intForQuery:@"SELECT MAX(version) FROM gc_version"];

    if( versionInitial != versionFinal) {
        RZLog(RZLogInfo, @"Database for %@ upgraded from version %@ to %@", name, @(versionInitial), @(versionFinal));
    }
    
    return db;
}
+(NSString*)sampleActivityDatabasePath:(NSString*)name{
    return [[self sampleActivityDatabase:name] databasePath];
}

+(void)ensureSampleDbStructure{
    NSArray<NSString*>*samples = @[
        // ConnectStatsTestApp
        @"test_activity_running_828298988.db", // GCTestUISamples sample13_compareStats
        @"test_activity_running_1266384539.db", // GCTestUISamples sample13_compareStats
        @"test_activity_running_837769405.db", // GCTestUISamples sample9_trackFieldMultipleLineGraphs
                                                // GCTestUISamples sample_12_trackStats
                                                // GCTestUISamples sampleActivities
        @"test_activity_swimming_439303647.db", // GCTestUISamples sampleActivities
        @"test_activity_cycling_940863203.db",  // GCTestUISamples sampleActivities
        @"test_activity_day___healthkit__Default_20151106.db", // GCTestUISamples sampleDayActivities
        @"test_activity_day___healthkit__Default_20151109.db", // GCTestUISamples sampleDayActivities
        
        // XCTests
        @"activities_duplicate.db", // GCTestsActivities testSearchDuplicateActivities
        
        @"test_activity_running_837769405.db", // GCTestsActivities testActivityStatsRunning
                                               // GCTestsPerformance testPerformanceTrackpoints
        @"test_activity_running_1266384539.db", // GCtestsActivities testCompareActivitiesRunning
        @"test_activity_running_828298988.db", // GCtestsActivities testCompareActivitiesRunning
        
        @"test_activity_running_837769405.db", // GCTestsActivities testBucketVersusLaps
                                            // GCTestsActivities testActivityThumbnails
        @"test_activity_day___healthkit__20150622.db", // GCTestsActivities testActivityStatsDayHeartRate
        @"test_activity_cycling_1404395287.db", // GCTestsActivities testActivityCalculated
        
        @"activities_duplicate.db", // GCTestsPerformance testPerformanceOrganizerLoad
        @"activities_stats.db", // GCTestsPerformance testPerformanceOrganizerStatistics
    ];
    
    
    for (NSString*dbname in samples) {
        NSString * path = [RZFileOrganizer bundleFilePathIfExists:dbname forClass:self];
        if( path ){
            @autoreleasepool {
                [self sampleActivityDatabase:dbname];
            }
        }
    }
}

-(NSArray<NSString*>*)activityIdSamples{
    //Deleted @"1089803211", @"1108367966", @"1108368135", @"924421177"

    
    
    NSArray<NSString*>*samples = @[
        // Garmin
        
        @"217470507", // in samples/tcx: swimming, fit, json modern, tcx
        @"234721416", // in samples/tcx: cycling london commute 10k 2012, fit, json modern, tcx
        @"234979239", // in samples/tcx: running london commute 10k 2012, fit, json modern, tcx
        
        @"2477200414", // in activity_merge_fit: running, battersea, 2018, running power, fit, json modern, activitydb
        
        @"3988198230", // in flying: flying, modern json, contained in last_modern_search_flying.json
        
        @"1083407258", // in fit_files: cross country skiing 2016, modern json, fit
        @"2545022458", // in fit_files: running, 2018, running pwer from garmin, fit
        
        // ConnectStats
        
        @"857090", // in activity_derived: running, battersea 2020, running power, fit
        @"834323", // in activity_derived: running, southpark laps 2020, running power, fit
        @"777501", // in activity_derived: running, southpark laps 2020, running power, fit
        @"728599", // in activity_derived: running, southpark laps 2020, running power, fit
        @"1451", // in fit_files: multi_sport triathlon, 2018, fit
        @"1525", // in fit_files: swimming, 2019, fit
        @"544406", // in fit_files: running river 2020, running power, fit
        
    ];
    
    return samples;
}

@end
