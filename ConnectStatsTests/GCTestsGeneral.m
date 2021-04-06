//
//  GarminConnectTests.m
//  GarminConnectTests
//
//  Created by Brice Rosenzweig on 02/09/2012.
//  Copyright (c) 2012 Brice Rosenzweig. All rights reserved.
//  $Id$

#import "GCTestCase.h"
#import "GCActivitiesOrganizer.h"
#import "GCActivitySearch.h"
#import "GCHistoryAggregatedActivityStats.h"
#import "GCAppProfiles.h"
#import "GCActivity+CalculatedLaps.h"
#import "GCFieldsCalculated.h"
#import "GCActivityCalculatedValue.h"
#import "GCActivitiesCacheManagement.h"
#import "GCAppGlobal.h"
#import "GCHistoryFieldDataSerie.h"
#import "GCViewIcons.h"
#import "GCTrackFieldChoices.h"
#import "GCSimpleGraphCachedDataSource+Templates.h"
#import "GCWebConnect.h"
#import "GCTestsSamples.h"
#import "GCHistoryFieldSummaryStats.h"
#import "GCActivity+CalculatedTracks.h"
#import "GCHistoryPerformanceAnalysis.h"
#import "GCActivity+Fields.h"
#import "GCTestsHelper.h"
#import "GCActivity+Database.h"
#import "GCActivity+Import.h"
#import "GCActivity+TrackTransform.h"
#import "GCActivity+TestBackwardCompat.h"
#import "GCStatsCalendarAggregationConfig.h"
#import "GCActivity.h"
#import "GCHistoryFieldDataHolder.h"

@interface GCTestsGeneral : GCTestCase
@end

#define EPS 1e-10

#define FAST_MODE 1


@implementation GCTestsGeneral

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{

    [super tearDown];
}

#pragma mark - Helpers

-(GCActivity*)buildActivityWithTrackpoints:(NSArray*)defs activityType:(GCActivityType*)aType{
    GCActivity * act= [[[GCActivity alloc] init] autorelease];
    [act changeActivityType:aType];
    NSMutableArray * tracks = [NSMutableArray arrayWithCapacity:100];

    double dist = 0.;
    NSDate * time = [NSDate date];
    NSUInteger lapIndex = 0;
    for (NSDictionary * def in defs) {
        double speed = [[def objectForKey:@"speed"] doubleValue];
        NSUInteger n = [[def objectForKey:@"n"] integerValue];
        double hr    = [[def objectForKey:@"hr"] doubleValue];
        double elapsed = [[def objectForKey:@"elapsed"] doubleValue];
        
        for (NSUInteger i = 0; i<n; i++) {
            time= [time dateByAddingTimeInterval:elapsed];
            GCTrackPoint * point = [[GCTrackPoint alloc] init];
            dist += speed*elapsed;
            point.distanceMeters = dist;
            point.elapsed = elapsed;
            point.time = time;
            
            [point setNumberWithUnit:[GCNumberWithUnit numberWithUnitName:@"mps" andValue:speed]
                            forField:[GCField fieldForFlag:gcFieldFlagWeightedMeanSpeed andActivityType:act.activityType]
                          inActivity:act];
            [point setNumberWithUnit:[GCNumberWithUnit numberWithUnitName:@"bpm" andValue:hr]
                            forField:[GCField fieldForFlag:gcFieldFlagWeightedMeanHeartRate andActivityType:act.activityType]
                          inActivity:act];
            point.lapIndex = lapIndex;
            point.trackFlags |= gcFieldFlagSumDistance|gcFieldFlagSumDuration;
            
            [tracks addObject:point];
            [point release];
        }
        lapIndex++;
    }
    [act setTrackpoints:tracks];
    return act;
}

-(GCActivitySummaryValue*)sumVal:(GCField*)k val:(double)val uom:(NSString*)uom{
    GCActivitySummaryValue * rv = [[[GCActivitySummaryValue alloc] init] autorelease];
    rv.numberWithUnit = [GCNumberWithUnit numberWithUnitName:uom andValue:val];
    rv.field = k;
    return rv;
}

-(void)addDummyActivity:(double)val andDate:(NSDate*)date in:(GCActivitiesOrganizer*)organizer{
    NSMutableArray * tmp = [NSMutableArray arrayWithArray:[organizer activities]];
    GCActivity * act = [[GCActivity alloc] init];
    act.activityId = [NSString stringWithFormat:@"Test_%@_%@", GC_TYPE_RUNNING, date.YYYYMMDD];
    [act setDate:date];
    [act setSumDistanceCompat:val];
    [act setSumDurationCompat:val*2.];
    [act setWeightedMeanHeartRateCompat:val*3.];
    [act setWeightedMeanSpeedCompat:val*4.];
    [act setFlags:gcFieldFlagSumDistance+gcFieldFlagSumDuration+gcFieldFlagWeightedMeanHeartRate+gcFieldFlagWeightedMeanSpeed];
    [act changeActivityType:[GCActivityType running]];
    
    [act setSummaryDataFromKeyDict:@{
        @"SumDuration" :           [self sumVal:[self fldFor:@"SumDuration" act:act]            val:act.sumDurationCompat             uom:@"second" ],
        @"SumDistance" :           [self sumVal:[self fldFor:@"SumDistance" act:act]            val:act.sumDistanceCompat             uom:@"meter" ],
        @"WeightedMeanHeartRate":  [self sumVal:[self fldFor:@"WeightedMeanHeartRate" act:act]  val:act.weightedMeanHeartRateCompat   uom:@"bpm"  ],
    }];
    
    [tmp addObject:act];
    [act release];
    
    act = [[GCActivity alloc] init];
    act.activityId = [NSString stringWithFormat:@"Test_%@_%@", GC_TYPE_CYCLING, date.YYYYMMDD];
    [act setDate:date];
    [act setSumDistanceCompat:val*5.];
    [act setSumDurationCompat:val*6.];
    [act setWeightedMeanHeartRateCompat:val*7.];
    [act setWeightedMeanSpeedCompat:val*8.];
    [act setFlags:gcFieldFlagSumDistance+gcFieldFlagSumDuration+gcFieldFlagWeightedMeanHeartRate+gcFieldFlagWeightedMeanSpeed];
    [act changeActivityType:[GCActivityType cycling]];
    
    [act setSummaryDataFromKeyDict:@{
        @"SumDuration" :           [self sumVal:[self fldFor:@"SumDuration" act:act]            val:act.sumDurationCompat             uom:@"second" ],
        @"SumDistance" :           [self sumVal:[self fldFor:@"SumDistance" act:act]            val:act.sumDistanceCompat             uom:@"meter" ],
        @"WeightedMeanHeartRate":  [self sumVal:[self fldFor:@"WeightedMeanHeartRate" act:act]  val:act.weightedMeanHeartRateCompat   uom:@"bpm"  ],
    }];

    [tmp addObject:act];
    [act release];
    [organizer setActivities:[NSArray arrayWithArray:tmp]];
}




#pragma mark - GCActivity

-(GCField*)fldFor:(NSString*)key act:(GCActivity*)act{
    return [GCField fieldForKey:key andActivityType:act.activityType];
}

-(void)testCalculatedFields{
    GCActivity * act = [[GCActivity alloc] init];
    [act changeActivityType:[GCActivityType cycling]];
    
    [act updateSummaryData:@{
        [self fldFor:@"SumDuration" act:act] :              [self sumVal:[self fldFor:@"SumDuration" act:act]             val:3       uom:@"second" ],
        [self fldFor:@"WeightedMeanPower" act:act]:         [self sumVal:[self fldFor:@"WeightedMeanPower" act:act]       val:3000    uom:@"watt" ],
        [self fldFor:@"WeightedMeanSpeed" act:act]:         [self sumVal:[self fldFor:@"WeightedMeanSpeed" act:act]       val:10.8    uom:@"kph" ],
        [self fldFor:@"WeightedMeanRunCadence" act:act]:    [self sumVal:[self fldFor:@"WeightedMeanRunCadence" act:act]  val:90      uom:@"stepsPerMinute" ]
    }
     ];
    GCFieldCalcKiloJoules * kj = [[GCFieldCalcKiloJoules alloc] init];
    GCFieldCalcStrideLength * sl = [[GCFieldCalcStrideLength alloc] init];
    GCActivityCalculatedValue * rv = nil;

    rv = [kj evaluateForActivity:act];
    XCTAssertEqualObjects(rv.uom, @"kilojoule", @"Right unit");
    XCTAssertEqualWithAccuracy(rv.value, 9., 1.e-7, @"sample is 9");

    rv = [sl evaluateForActivity:act];
    XCTAssertNil(rv, @"Computing Run Calc Field on cycle activity");
    
    [act changeActivityType:[GCActivityType running]];
    [act updateSummaryData:@{
        [self fldFor:@"SumDuration" act:act] :              [self sumVal:[self fldFor:@"SumDuration" act:act]              val:3       uom:@"second" ],
        [self fldFor:@"WeightedMeanSpeed" act:act]:         [self sumVal:[self fldFor:@"WeightedMeanSpeed" act:act]       val:10.8    uom:@"kph" ],
        [self fldFor:@"WeightedMeanRunCadence" act:act]:    [self sumVal:[self fldFor:@"WeightedMeanRunCadence" act:act]  val:90      uom:@"stepsPerMinute" ]
    }
     ];
    
    rv = [sl evaluateForActivity:act];
    XCTAssertEqualObjects(rv.uom, @"stride", @"Right unit for stride length");
    XCTAssertEqualWithAccuracy(rv.value, 2., 1.e-7, @"sample is 2 meters");

    [GCFieldsCalculated addCalculatedFields:act];
    //ToTest
    //XCTAssertTrue([act hasField:[sl field]], @"stride there");
    //XCTAssertTrue([act hasField:[kj field]], @"kj there");
    GCNumberWithUnit * v_sl = [act numberWithUnitForFieldKey:[sl fieldKey]];
    GCNumberWithUnit * v_kj = [act numberWithUnitForFieldKey:[kj fieldKey]];
    
    XCTAssertNil(v_kj);// SHould not be there (no power)
    XCTAssertEqualWithAccuracy(v_sl.value, 2., 1.e-7, @"sl sample");
    
    
    [kj release];
    [sl release];
    
    [act release];
    
}


-(void)testCalculatedFieldsTrackPoints{
    GCActivity * act = [[GCActivity alloc] init];
    [act changeActivityType:[GCActivityType running]];

    NSDictionary * d = @{ @"averageRunningCadenceInStepsPerMinute": @180.0,
                          @"duration": @"3.",
                          @"averageSpeed": @3.,
                          @"averagePower": @3000.0,
                          @"calories":@"9.",
                          @"startTimeGMT":@"2016-03-13T12:46:19.0"
                          
                          };
    
    GCLap * trackpoint = [[GCLap alloc] initWithDictionary:d forActivity:act];
    
    GCFieldCalcStrideLength * sl = [[GCFieldCalcStrideLength alloc] init];
    GCFieldCalcKiloJoules * kj = [[GCFieldCalcKiloJoules alloc] init];
    GCFieldCalcMetabolicEfficiency * me = [[GCFieldCalcMetabolicEfficiency alloc] init];
    
    GCActivityCalculatedValue * v_sl = [sl evaluateForTrackPoint:trackpoint inActivity:act];
    GCActivityCalculatedValue * v_kj = [kj evaluateForTrackPoint:trackpoint inActivity:act];
    GCActivityCalculatedValue * v_me = [me evaluateForTrackPoint:trackpoint inActivity:act];
    
    XCTAssertEqualObjects(v_sl.uom, @"stride", @"Right unit for stride length");
    XCTAssertEqualWithAccuracy(v_sl.value, 2., 1.e-7, @"sample is 2 meters");
    
    XCTAssertEqualObjects(v_kj.uom, @"kilojoule", @"Right unit");
    XCTAssertEqualWithAccuracy(v_kj.value, 9., 1.e-7, @"sample is 9");

    XCTAssertEqualObjects(v_me.uom, @"percent", @"Right unit");
    XCTAssertEqualWithAccuracy(v_me.value, 23.9005736, 1.e-3, @"sample is .239");

    
    [sl release];
    [kj release];
    [me release];
    [trackpoint release];
    
}


-(void)testAggregateActivities{
    GCActivitiesOrganizer * organizer = [[GCActivitiesOrganizer alloc] init];
    NSDictionary * sample  = [GCTestsSamples aggregateSample];
    NSDictionary * expected =[GCTestsSamples aggregateExpected];
    // Create one running/one cycling with distance = val, time = val *2, etc
    for (NSString * datestr in sample) {
        NSNumber * val = [sample objectForKey:datestr];
        [self addDummyActivity:[val doubleValue] andDate:[NSDate dateForRFC3339DateTimeString:datestr] in:organizer];
    }
    organizer.activities = [organizer.activities sortedArrayUsingComparator:^(GCActivity * o1,GCActivity* o2){ return [o2.date compare:o1.date]; }];
    GCStatsDataSerie * e_avg = [[[GCStatsDataSerie alloc] init] autorelease];
    GCStatsDataSerie * e_sum = [[[GCStatsDataSerie alloc] init] autorelease];
    GCStatsDataSerie * e_max = [[[GCStatsDataSerie alloc] init] autorelease];
    for (NSString * datestr in expected) {
        NSDate * d = [NSDate dateForRFC3339DateTimeString:datestr];
        NSArray * a = [expected objectForKey:datestr];
        [e_avg addDataPointWithDate:d andValue:[[a objectAtIndex:0] doubleValue]];
        [e_sum addDataPointWithDate:d andValue:[[a objectAtIndex:1] doubleValue]];
        [e_max addDataPointWithDate:d andValue:[[a objectAtIndex:2] doubleValue]];
    }
    [e_avg sortByReverseDate];
    [e_sum sortByReverseDate];
    [e_max sortByReverseDate];
    
    GCHistoryAggregatedActivityStats * stats = [GCHistoryAggregatedActivityStats aggregatedActivityStatsForActivityType:GC_TYPE_RUNNING];
    [stats setActivitiesFromOrganizer:organizer];
    [stats setActivityTypeSelection:RZReturnAutorelease([[GCActivityTypeSelection alloc] initWithActivityType:GC_TYPE_RUNNING])];
    [stats aggregate:NSCalendarUnitWeekOfYear referenceDate:nil ignoreMode:gcIgnoreModeActivityFocus];
    XCTAssertEqual([e_avg count], [stats count], @"Count");
    
    NSDateFormatter * formatter = [[[NSDateFormatter alloc] init] autorelease];
    NSTimeZone * tz = [NSTimeZone timeZoneWithName:@"GMT"];
    [formatter setTimeZone:tz];
    
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterNoStyle];
    NSCalendar * cal = [NSCalendar currentCalendar];
    
    for(NSUInteger i = 0; i<[e_avg count];i++){
        GCHistoryAggregatedDataHolder * holder = [stats dataForIndex:i];

        if (![[holder date] isSameCalendarDay:[[e_avg dataPointAtIndex:i] date] calendar:cal]) {
            NSLog(@"%d: %@!=%@",(int)i,[holder date], [[e_avg dataPointAtIndex:i] date]);
        }
        XCTAssertTrue([[holder date] isSameCalendarDay:[[e_avg dataPointAtIndex:i] date] calendar:cal], @"same date avg %@ %@", [holder date], [[e_avg dataPointAtIndex:i] date] );
        GCField * f = [GCField fieldForFlag:gcFieldFlagSumDistance andActivityType:GC_TYPE_RUNNING];
        double x = 1.;
        // number with unit on holder report in display unit (km)
        XCTAssertEqualWithAccuracy([holder numberWithUnit:f statType:gcAggregatedAvg].value, [e_avg dataPointAtIndex:i].y_data*x/1000., 1e-6, @"Same Average");
        XCTAssertEqualWithAccuracy([holder numberWithUnit:f statType:gcAggregatedSum].value, [e_sum dataPointAtIndex:i].y_data*x/1000., 1e-6, @"Same sum");
        XCTAssertEqualWithAccuracy([holder numberWithUnit:f statType:gcAggregatedMax].value, [e_max dataPointAtIndex:i].y_data*x/1000., 1e-6, @"Same max");
        
        f = [GCField fieldForFlag:gcFieldFlagSumDuration andActivityType:GC_TYPE_RUNNING];
        x = 2.;
        XCTAssertEqualWithAccuracy([holder numberWithUnit:f statType:gcAggregatedAvg].value, [e_avg dataPointAtIndex:i].y_data*x, 1e-6, @"Same Average");
        XCTAssertEqualWithAccuracy([holder numberWithUnit:f statType:gcAggregatedSum].value, [e_sum dataPointAtIndex:i].y_data*x, 1e-6, @"Same sum");
        XCTAssertEqualWithAccuracy([holder numberWithUnit:f statType:gcAggregatedMax].value, [e_max dataPointAtIndex:i].y_data*x, 1e-6, @"Same max");

        f = [GCField fieldForFlag:gcFieldFlagWeightedMeanHeartRate andActivityType:GC_TYPE_RUNNING];
        x = 3.;
        XCTAssertEqualWithAccuracy([holder numberWithUnit:f statType:gcAggregatedAvg].value, [e_avg dataPointAtIndex:i].y_data*x, 1e-6, @"Same Average");
        XCTAssertEqualWithAccuracy([holder numberWithUnit:f statType:gcAggregatedSum].value, [e_sum dataPointAtIndex:i].y_data*x, 1e-6, @"Same sum");
        XCTAssertEqualWithAccuracy([holder numberWithUnit:f statType:gcAggregatedMax].value, [e_max dataPointAtIndex:i].y_data*x, 1e-6, @"Same max");

        f = [GCField fieldForFlag:gcFieldFlagWeightedMeanSpeed andActivityType:GC_TYPE_RUNNING];
        x = 4.;
        XCTAssertEqualWithAccuracy([[holder numberWithUnit:f statType:gcAggregatedAvg] convertToUnit:GCUnit.mps].value, [e_avg dataPointAtIndex:i].y_data*x, 1e-6, @"Same Average");
        XCTAssertEqualWithAccuracy([[holder numberWithUnit:f statType:gcAggregatedSum] convertToUnit:GCUnit.mps].value, [e_sum dataPointAtIndex:i].y_data*x, 1e-6, @"Same sum");
        XCTAssertEqualWithAccuracy([[holder numberWithUnit:f statType:gcAggregatedMax] convertToUnit:GCUnit.mps].value, [e_max dataPointAtIndex:i].y_data*x, 1e-6, @"Same max");
    }
    
    [stats setActivityTypeSelection:RZReturnAutorelease([[GCActivityTypeSelection alloc] initWithActivityType:GC_TYPE_ALL])];
    [stats aggregate:NSCalendarUnitWeekOfYear referenceDate:nil ignoreMode:gcIgnoreModeActivityFocus];

    GCHistoryFieldSummaryStats * sumStats = [GCHistoryFieldSummaryStats fieldStatsWithActivities:organizer.activities matching:nil referenceDate:nil ignoreMode:gcIgnoreModeActivityFocus];
    GCHistoryAggregatedDataHolder * holder = [stats dataForIndex:0];
    
    GCField * hrfield =[GCField fieldForFlag:gcFieldFlagWeightedMeanHeartRate andActivityType:GC_TYPE_ALL];
    
    XCTAssertEqualWithAccuracy([holder numberWithUnit:hrfield statType:gcAggregatedAvg].value,
                               [[sumStats dataForField:hrfield] averageWithUnit:gcHistoryStatsWeek].value,
                               1.e-7, @"Average equals");
    XCTAssertEqualWithAccuracy([holder numberWithUnit:hrfield statType:gcAggregatedCnt].value,
                               [[sumStats dataForField:hrfield] count:gcHistoryStatsWeek],
                               1.e-7, @"Count equals");
    
    // Check Cutoff aggregate
     [stats setActivityTypeSelection:RZReturnAutorelease([[GCActivityTypeSelection alloc] initWithActivityType:GC_TYPE_RUNNING])];
    NSDate * cutoff = [organizer.activities.lastObject date];
    [stats aggregate:NSCalendarUnitMonth referenceDate:nil cutOff:cutoff ignoreMode:gcIgnoreModeActivityFocus];
    
    // CutOff November 13 (last):
    //    Nov -> Cnt 1, Sum 0.2
    //    Oct -> Cnt 2, Sum 3.2+2.1=5.3
    //    Sep -> Cnt 1, Sum 1.2
    
    // Reconstruct the cut off by field Serie
    GCField * distfield = [GCField fieldForFlag:gcFieldFlagSumDistance andActivityType:GC_TYPE_RUNNING];
    GCHistoryFieldDataSerieConfig * config = [GCHistoryFieldDataSerieConfig configWithFilter:false field:distfield];
    GCHistoryFieldDataSerie * dataserie = [[GCHistoryFieldDataSerie alloc] initFromConfig:config];
    dataserie.organizer = organizer;
    [dataserie loadFromOrganizer];
    GCHistoryFieldDataSerie * withcutoff = [dataserie serieWithCutOff:cutoff inCalendarUnit:NSCalendarUnitMonth withReferenceDate:nil];
    NSDictionary * dict = [withcutoff.history.serie aggregatedStatsByCalendarUnit:NSCalendarUnitMonth
                                                                    referenceDate:nil
                                                                      andCalendar:[GCAppGlobal calculationCalendar]];
    GCStatsDataSerie * histCutSum = dict[@"sum"];
    NSArray * cutOffExpected = @[ @[ @"2012-11-01T00:00:00.000Z", @(0.2/1000.)], @[ @"2012-10-01T00:00:00.000Z", @(5.3/1000.)], @[@"2012-09-01T00:00:00.000Z", @(1.2/1000.)]];
    NSUInteger i=0;
    for (NSArray * one in cutOffExpected) {
        NSDate * date = [NSDate dateForRFC3339DateTimeString:one[0]];
        NSNumber * value = one[1];
        GCHistoryAggregatedDataHolder * holder = [stats dataForIndex:i++];
        GCNumberWithUnit * nu = [holder numberWithUnit:[GCField fieldForFlag:gcFieldFlagSumDistance andActivityType:GC_TYPE_RUNNING] statType: gcAggregatedSum];
        XCTAssertTrue([holder.date isSameCalendarDay:date calendar:[GCAppGlobal calculationCalendar]], @"same date %@ / %@", holder.date, date);
        XCTAssertEqualWithAccuracy( nu.value, value.doubleValue, 1.e-7);
        BOOL found = false;
        for (GCStatsDataPoint * point in histCutSum) {
            if( [point.date isSameCalendarDay:date calendar:[GCAppGlobal calculationCalendar]]){
                XCTAssertEqualWithAccuracy(nu.value, point.y_data, 1.0e-7);
                found = true;
            }
        }
        XCTAssertTrue(found, @"found %@ in History Field Data Serie", date);
    }
    
    
    [organizer release];
}

-(void)atestTrackFieldChoiceOrder{
    GCActivity * activity = [[[GCActivity alloc] init] autorelease];
    [activity changeActivityType:[GCActivityType running]];
    
    activity.trackFlags = gcFieldFlagSumDistance|gcFieldFlagWeightedMeanSpeed|gcFieldFlagWeightedMeanHeartRate;
    
    GCTrackFieldChoices * choices = [GCTrackFieldChoices trackFieldChoicesWithActivity:activity];
    
    NSLog(@"choices %@", choices.choices );
}

-(void)testSearchString{
    GCActivitySearch * search = nil;
    GCActivity * one_true = [[[GCActivity alloc] init] autorelease];
    one_true.activityId = @"1111";
    one_true.date = [NSDate date];
    [one_true changeActivityType:[GCActivityType running]];
    
    GCActivity * one_false =[[[GCActivity alloc] init] autorelease];
    one_false.activityId = @"0000";
    one_false.date = [NSDate date];
    [one_false changeActivityType:[GCActivityType running]];

    one_false.activityId = @"0000";
    [one_true setSumDistanceCompat:20000.];
    [one_false setSumDistanceCompat:2000.];
    
    for (NSString * st in [NSArray arrayWithObjects:@"distance > 10km",@"distance >10 km",@"distance>10km",@"distance> 10", nil]) {
        search = [GCActivitySearch activitySearchWithString:st];
        XCTAssertTrue([search match:one_true], @"%@(20)",st);
        XCTAssertFalse([search match:one_false], @"%@(20)",st);
    }
    for (NSString * st in [NSArray arrayWithObjects:@"distance < 10",@"distance <10",@"distance<10",@"distance< 10", nil]) {
        search = [GCActivitySearch activitySearchWithString:st];
        XCTAssertTrue([search match:one_false], @"%@(20)",st);
        XCTAssertFalse([search match:one_true], @"%@(20)",st);
    }
    
    search = [GCActivitySearch activitySearchWithString:@"1111"];
    XCTAssertFalse([search match:one_false], @"1111");
    XCTAssertTrue([search match:one_true], @"1111");

    [one_true setSumDistanceCompat:2000.];
    [one_false setSumDistanceCompat:1450.];
    search = [GCActivitySearch activitySearchWithString:@"distance > 1.5km"];
    NSString * st = @"2km";
    XCTAssertFalse([search match:one_false], @"%@(20)",st);
    XCTAssertTrue([search match:one_true], @"%@(20)",st);
    
    [one_true setSumDistanceCompat:1.];
    [one_false setSumDistanceCompat:1.];
    [one_true setWeightedMeanSpeedCompat:2.];
    [one_false setWeightedMeanSpeedCompat:1.];
    st = @"speed";
    search = [GCActivitySearch activitySearchWithString:@"speed > 7 kph"];
    XCTAssertFalse([search match:one_false], @"%@(20)",st);
    XCTAssertTrue([search match:one_true], @"%@(20)",st);
    
    
    search = [GCActivitySearch activitySearchWithString:@"touRRette"];
    [one_true setLocation:@"Tourrettes"];
    [one_false setLocation:@"london"];
    XCTAssertTrue([search match:one_true], @"Tourrettes (true)");
    XCTAssertFalse([search match:one_false], @"tourrettes (false)");
    
    [one_false setSumDurationCompat:72.];
    [one_true setSumDurationCompat:82.];
    search = [GCActivitySearch activitySearchWithString:@"duration > 1:20"];
    XCTAssertTrue([search match:one_true],@"82 > 1:20");
    XCTAssertFalse([search match:one_false],@"72s > 1:20");
    
    NSDateComponents * comp = [[[NSDateComponents alloc] init] autorelease];
    NSCalendar * cal = [NSCalendar currentCalendar];
    [comp setDay:17];
    [comp setMonth:11];
    [comp setYear:2012];
    
    NSDate * sampledate = [cal dateFromComponents:comp];
    NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    NSString * weeksample = [NSString stringWithFormat:@"Weekof %@", [dateFormatter stringFromDate:sampledate]];
    
    NSArray * dateSamples = [NSArray arrayWithObjects:
                             @"June 2012",          @"2012-06-13T18:48:16.000Z",@"2012-09-13T18:48:16.000Z",
                             @"Mar 2011",           @"2011-03-13T18:48:16.000Z",@"2012-03-13T18:48:16.000Z",
                             @"2013",               @"2013-03-13T18:48:16.000Z",@"2011-03-13T18:48:16.000Z",
                             @"Saturday",           @"2012-11-17T18:48:16.000Z",@"2012-11-18T18:48:16.000Z",
                             weeksample,            @"2012-11-13T18:48:16.000Z",@"2012-11-22T18:48:16.000Z",
                             nil];
    
    for (NSUInteger i = 0; i<[dateSamples count]; i+=3) {
        NSString * searchStr = [dateSamples objectAtIndex:i];
        NSString * trueStr   = [dateSamples objectAtIndex:i+1];
        NSString * falseStr  = [dateSamples objectAtIndex:i+2];
        
        search = [GCActivitySearch activitySearchWithString:searchStr];
        [one_false setDate:[NSDate dateForRFC3339DateTimeString:falseStr]];
        [one_true setDate:[NSDate dateForRFC3339DateTimeString:trueStr]];
        
        XCTAssertTrue([search match:one_true],   @"%@ %@->%@", searchStr, trueStr, one_true.date);
        XCTAssertFalse([search match:one_false], @"%@ %@->%@", searchStr, falseStr, one_false.date);
        
    }
    
    /*
     search = [GCActivitySearch activitySearchWithString:@"Mar 2012"];
     search = [GCActivitySearch activitySearchWithString:@"Fri"];
     search = [GCActivitySearch activitySearchWithString:@"Thursday"];
     search = [GCActivitySearch activitySearchWithString:@"2012"];
     search = [GCActivitySearch activitySearchWithString:@"Weekof 11/16/12"];
     */
}

-(void)testLapBreakdown{
    
    NSArray * samples = @[ @{@"speed" : @10.,  @"n" : @10, @"hr" : @110., @"elapsed" : @1. },
                           @{@"speed" : @12.,  @"n" : @5 , @"hr" : @115., @"elapsed" : @1. },
                           @{@"speed" : @12.,  @"n" : @5 , @"hr" : @125., @"elapsed" : @1. },
                           @{@"speed" : @10.,  @"n" : @10, @"hr" : @122., @"elapsed" : @1. },
                           @{@"speed" : @11.5, @"n" : @10, @"hr" : @120., @"elapsed" : @1. },
                           @{@"speed" : @11.5, @"n" : @10, @"hr" : @140., @"elapsed" : @1. },
                           @{@"speed" : @10.,  @"n" : @10, @"hr" : @120., @"elapsed" : @1. },
                           ];
    
    GCActivity * act= [self buildActivityWithTrackpoints:samples activityType:GCActivityType.running];
    
    NSArray * laps = [act calculatedLapFor:40. match:[act matchTimeBlock] inLap:GC_ALL_LAPS];
    XCTAssertEqual([laps count], (NSUInteger)2, @"matching time");
    laps = [act calculatedLapFor:20. match:[act matchTimeBlock] inLap:GC_ALL_LAPS];
    XCTAssertEqual([laps count], (NSUInteger)3, @"matching time");
    laps = [act calculatedLapFor:100. match:[act matchTimeBlock] inLap:GC_ALL_LAPS];
    XCTAssertEqual([laps count], (NSUInteger)1, @"matching time");
    laps = [act accumulatedLaps];
    GCLap * second = laps[1];
    XCTAssertEqualWithAccuracy(second.distanceMeters, 162.0, 1.e-5, @"dist of second lap");
    XCTAssertEqualWithAccuracy(second.speed, 10.8, 1.e-5, @"speed of second lap");
    
}
    
-(void)testRollingLap{
    
    NSArray * samples = @[ @{@"speed" : @0.,   @"n" : @1,  @"hr" : @110., @"elapsed" : @1. },
                           @{@"speed" : @10.,  @"n" : @10, @"hr" : @110., @"elapsed" : @1. },
                           @{@"speed" : @12.,  @"n" : @5 , @"hr" : @115., @"elapsed" : @1. },
                           @{@"speed" : @12.,  @"n" : @5 , @"hr" : @125., @"elapsed" : @1. },
                           @{@"speed" : @10.,  @"n" : @10, @"hr" : @122., @"elapsed" : @1. },
                           @{@"speed" : @11.5, @"n" : @10, @"hr" : @120., @"elapsed" : @1. },
                           @{@"speed" : @11.5, @"n" : @10, @"hr" : @140., @"elapsed" : @1. },
                           @{@"speed" : @10.,  @"n" : @10, @"hr" : @120., @"elapsed" : @1. },
                           ];
    
    GCActivity * act= [self buildActivityWithTrackpoints:samples activityType:GCActivityType.running];
    
    GCActivityMatchLapBlock m = [act matchDistanceBlockEqual];
    GCActivityCompareLapBlock c = [act compareSpeedBlock];
    
    void (^test)(double dist)  = ^(double dist){
        NSArray * rv = [act calculatedRollingLapFor:dist match:m compare:c];
        GCLap * first = rv[1];
        GCLap * second = rv[2];
        GCTrackPoint * firstStartPoint = nil;
        GCTrackPoint * firstEndPoint = nil;
        NSUInteger i =0;
        for (i=0; i<[[act trackpoints] count]; i++) {
            GCTrackPoint * p = [[act trackpoints] objectAtIndex:i];
            if ([[p time] isEqualToDate:[first time]]) {
                firstStartPoint = p;
            }
            if ([[p time] isEqualToDate:[second time]]) {
                firstEndPoint = p;
            }
            
        }
        XCTAssertEqualWithAccuracy(dist, first.distanceMeters, first.speed, @"match dist %.f", dist);
        XCTAssertEqualWithAccuracy(firstEndPoint.distanceMeters-firstStartPoint.distanceMeters, first.distanceMeters, second.speed*1.1, @"match dist %.f", dist);
        
    };
    
    test(100.);
    test(200.);
    
}

-(void)disableTestCompoundBestOf{
    NSArray * samples = @[ @{@"speed" : @0.,  @"n" : @1,  @"hr" : @110., @"elapsed" : @2. },
                           @{@"speed" : @2.8, @"n" : @30, @"hr" : @110., @"elapsed" : @2. },
                           @{@"speed" : @2.8, @"n" : @20, @"hr" : @115., @"elapsed" : @2. },
                           @{@"speed" : @3.0, @"n" : @20, @"hr" : @125., @"elapsed" : @2. },
                           @{@"speed" : @3.5, @"n" : @40, @"hr" : @122., @"elapsed" : @2. },
                           @{@"speed" : @3.4, @"n" : @30, @"hr" : @120., @"elapsed" : @2. },
                           @{@"speed" : @3.5, @"n" : @20, @"hr" : @140., @"elapsed" : @2. },
                           @{@"speed" : @3.1, @"n" : @20, @"hr" : @120., @"elapsed" : @2. },
                           @{@"speed" : @2.9, @"n" : @10, @"hr" : @120., @"elapsed" : @2. },
                           @{@"speed" : @2.7, @"n" : @20, @"hr" : @140., @"elapsed" : @2. },
                           ];
    
    GCActivity * act= [self buildActivityWithTrackpoints:samples activityType:GCActivityType.running];

    GCField * field = [GCField fieldForFlag:gcFieldFlagWeightedMeanSpeed andActivityType:GC_TYPE_RUNNING];
    GCStatsDataSerieWithUnit * v_bestroll = [act calculatedSerieForField:field.correspondingBestRollingField thread:nil];
    NSArray * laps = [act compoundLapForIndexSerie:v_bestroll desc:@""];
    
    
    for (NSUInteger i=0; i<laps.count; i++) {
        NSLog(@"i=%lu dist=%f elapsed=%f", (unsigned long)i, [laps[i] distanceMeters], [laps[i] elapsed]);
    }
    
    GCActivityMatchLapBlock m = [act matchDistanceBlockEqual];
    GCActivityCompareLapBlock c = [act compareSpeedBlock];
    
    NSArray * km2   = [act calculatedRollingLapFor:1000. match:m compare:c];
    
    NSArray * per10m = [act resample:act.trackpoints forUnit:10. useTimeAxis:NO];
    
    NSLog(@"rol %lu, resample %lu", (unsigned long)km2.count, (unsigned long)per10m.count);
}

-(void)testPerformanceAnalysis{
    NSArray * samples = @[ // week 1 - hard
                           @{@"day": @1,    @"dist": @10.0,    @"hr": @160,    @"speed": @12.5 },
                           @{@"day": @2,    @"dist": @15.0,    @"hr": @150,    @"speed": @12   },
                           @{@"day": @4,    @"dist": @08.0,    @"hr": @140,    @"speed": @11   },
                           @{@"day": @6,    @"dist": @10.0,    @"hr": @170,    @"speed": @13   },
                           // week 2 - less hard
                           @{@"day": @8,    @"dist": @10.0,    @"hr": @170,    @"speed": @13   },
                           @{@"day": @9,    @"dist": @08.0,    @"hr": @150,    @"speed": @11   },
                           @{@"day": @10,   @"dist": @09.0,    @"hr": @150,    @"speed": @11.5 },
                           // week 3 - very hard
                           @{@"day": @15,   @"dist": @12.0,    @"hr": @170,    @"speed": @12.5 },
                           @{@"day": @17,   @"dist": @15.0,    @"hr": @165,    @"speed": @12 },
                           @{@"day": @18,   @"dist": @10.0,    @"hr": @170,    @"speed": @13 },
                           @{@"day": @19,   @"dist": @10.0,    @"hr": @150,    @"speed": @12 },
                           // week 4 - easy
                           @{@"day": @21,   @"dist": @10.0,    @"hr": @150,    @"speed": @11   },
                           @{@"day": @22,   @"dist": @08.0,    @"hr": @130,    @"speed": @10.5 },
                           // week 5 - moderate
                           @{@"day": @29,   @"dist": @10.0,    @"hr": @165,    @"speed": @13 },
                           @{@"day": @30,   @"dist": @10.0,    @"hr": @160,    @"speed": @12 }
                           ];
    NSDate * startDate = [NSDate dateForRFC3339DateTimeString:@"2014-03-04T18:00:00.000Z"];
    NSMutableArray * activities = [NSMutableArray arrayWithCapacity:samples.count];
    for (NSDictionary * sample in samples) {
        NSTimeInterval shift = ([sample[@"day"] doubleValue] * 60.*60.*24.);
        NSDate * date = [startDate dateByAddingTimeInterval:shift];
        
        double distance = [sample[@"dist"] doubleValue] * 1000.;
        double hr       = [sample[@"hr"] doubleValue];
        double speed    = [sample[@"speed"] doubleValue] * 1000./3600.; // km into mps
        double elapsed  = distance/speed;
        
        
        GCActivity * act = [[GCActivity alloc] init];
        act.activityId = [NSString stringWithFormat:@"act_%d dist=%.0fkm hr=%.0fbpm speed=%.1fkph", [sample[@"day"] intValue],
                          distance/1000., hr,speed/1000.*3600.];
        [act setDate:date];
        [act setSumDistanceCompat:distance];
        [act setSumDurationCompat:elapsed];
        [act setWeightedMeanHeartRateCompat:hr];
        [act setWeightedMeanSpeedCompat:speed];
        [act setFlags:gcFieldFlagSumDistance+gcFieldFlagSumDuration+gcFieldFlagWeightedMeanHeartRate+gcFieldFlagWeightedMeanSpeed];
        [act changeActivityType:[GCActivityType running]];
        
        [act setSummaryDataFromKeyDict: @{
            @"SumDuration" :           [self sumVal:[self fldFor:@"SumDuration" act:act]            val:act.sumDurationCompat             uom:@"second" ],
            @"SumDistance" :           [self sumVal:[self fldFor:@"SumDistance"  act:act]            val:act.sumDistanceCompat             uom:@"meter" ],
            @"WeightedMeanHeartRate":  [self sumVal:[self fldFor:@"WeightedMeanHeartRate"  act:act]  val:act.weightedMeanHeartRateCompat   uom:@"bpm"  ],
        }];
        
        [activities addObject:act];
        [act release];
    }
    
    GCActivitiesOrganizer * organizer = [[[GCActivitiesOrganizer alloc] init] autorelease];
    organizer.activities = activities;
    
    GCHistoryPerformanceAnalysis * perfAnalysis = [[[GCHistoryPerformanceAnalysis alloc] init] autorelease];
    [perfAnalysis useOrganizer:organizer];
    
    perfAnalysis.shortTermPeriod = [GCLagPeriod periodFor:gcLagPeriodWeek];
    perfAnalysis.longTermPeriod  = [GCLagPeriod periodFor:gcLagPeriodTwoWeeks];
    perfAnalysis.summableField = [GCField fieldForFlag:gcFieldFlagSumDistance andActivityType:GC_TYPE_RUNNING];
    perfAnalysis.scalingField = [GCField fieldForFlag:gcFieldFlagWeightedMeanHeartRate andActivityType:GC_TYPE_RUNNING];

    [perfAnalysis calculate];
    
    RZRegressionManager * manager = [RZRegressionManager managerForTestClass:[self class]];
    manager.recordMode = [GCTestCase recordModeGlobal];
    //manager.recordMode = true;
    NSSet<Class>*classes =[NSSet setWithObjects:[GCStatsDataSerieWithUnit class], nil];
    NSError * error = nil;
    
    GCStatsDataSerieWithUnit * exp_st = [manager retrieveReferenceObject:perfAnalysis.shortTermSerie
                                                              forClasses:classes
                                                                selector:_cmd
                                                              identifier:@"perf.shortTermSerie"
                                                                   error:&error];
    GCStatsDataSerieWithUnit * exp_lt = [manager retrieveReferenceObject:perfAnalysis.longTermSerie
                                                              forClasses:classes
                                                                selector:_cmd
                                                              identifier:@"perf.longTermSerie"
                                                                   error:&error];

    
    XCTAssertEqual(exp_st.count, perfAnalysis.shortTermSerie.serie.count, @"Short Term count as Expected");
    XCTAssertEqual(exp_lt.count, perfAnalysis.longTermSerie.serie.count, @"Long Term count as Expected");
    //manager.recordMode = true;

    // Divide by 1000 as display unit is kilometer now, but above is calculated with meters.
    // it doesn't matter for final display as it's rescaled against the maximium on the serie.
    for (NSUInteger i=0; i<MIN(exp_st.count, perfAnalysis.shortTermSerie.serie.count); i++) {
        XCTAssertEqualWithAccuracy(exp_st.serie[i].y_data, [perfAnalysis.shortTermSerie.serie dataPointAtIndex:i].y_data, 1.e-2, @"Short Term Value [%d]", (int)i );
    }
    
    for (NSUInteger i=0; i<MIN(exp_lt.count, perfAnalysis.longTermSerie.serie.count); i++) {
        XCTAssertEqualWithAccuracy(exp_lt.serie[i].y_data , [perfAnalysis.longTermSerie.serie dataPointAtIndex:i].y_data, 1.e-2, @"Long Term Value [%d]", (int)i );
    }
    
}

-(void)testAccumulateTrack{
    
    GCActivity * dummy = [[[GCActivity alloc] init] autorelease];
    [dummy changeActivityType:[GCActivityType running]];
    
    GCLap * lap = [[[GCLap alloc] init] autorelease];
    
    GCTrackPoint * from = [[[GCTrackPoint alloc] init] autorelease];
    GCTrackPoint * to   = [[[GCTrackPoint alloc] init] autorelease];
    
    NSDate * start = [NSDate date];
    
    GCField * hr = [GCField fieldForFlag:gcFieldFlagWeightedMeanHeartRate andActivityType:GC_TYPE_RUNNING];
    GCField * dist = [GCField fieldForFlag:gcFieldFlagSumDistance andActivityType:GC_TYPE_RUNNING];
    
    from.time = start;
    to.time = [start dateByAddingTimeInterval:1.];
    [from setNumberWithUnit:[GCNumberWithUnit numberWithUnit:GCUnit.bpm andValue:120.] forField:hr inActivity:dummy];
    [from setNumberWithUnit:[GCNumberWithUnit numberWithUnit:GCUnit.meter andValue:1.0] forField:dist inActivity:dummy];
    [to setNumberWithUnit:[GCNumberWithUnit numberWithUnit:GCUnit.meter andValue:11.0] forField:dist inActivity:dummy];
    // from 1m to 11m in 1sec = 10 m/s
    
    // 60 seconds of this
    for (NSUInteger i=0; i<60; i++) {
        [lap accumulateFrom:from to:to inActivity:dummy];
    }
    XCTAssertEqualWithAccuracy(lap.distanceMeters, 600., 1e-7, @"distance after 1min");
    XCTAssertEqualWithAccuracy(lap.speed, 10., 1e-7, @"speed after 1min");
    XCTAssertEqualWithAccuracy(lap.heartRateBpm, 120., 1e-7, @"hr after 1min");
    // Switch to 20 m/s @ 140bpm
    [to setNumberWithUnit:[GCNumberWithUnit numberWithUnit:GCUnit.meter andValue:21.0] forField:dist inActivity:dummy];
    [from setNumberWithUnit:[GCNumberWithUnit numberWithUnit:GCUnit.bpm andValue:140.0] forField:hr inActivity:dummy];
    
    for (NSUInteger i=0; i<60; i++) {
        [lap accumulateFrom:from to:to  inActivity:dummy];
        XCTAssertTrue(lap.speed-10.> 0.001, @"Speed > 10");
    }
    XCTAssertEqualWithAccuracy(lap.distanceMeters, 1800., 1e-7, @"distance after 1min");
    XCTAssertEqualWithAccuracy(lap.speed, 15., 1e-7, @"speed after 1min");
    XCTAssertEqualWithAccuracy(lap.heartRateBpm, 130., 1e-7, @"hr after 1min");
    
}



#pragma mark - GCActivitiesOrganizer

-(void)testOrganizer{
    GCActivitiesOrganizer * organizer = [[GCActivitiesOrganizer alloc] init];
    NSArray * initial = [NSArray arrayWithObjects:@"a", @"b", @"c", @"d",@"e", nil];
    NSMutableArray * a1 = [NSMutableArray arrayWithCapacity:[initial count]];
    for (NSString * aId in initial) {
        GCActivity * act = [[GCActivity alloc] init];
        [act setActivityId:aId];
        [a1 addObject:act];
        [act release];
    }
    [organizer setActivities:[NSArray arrayWithArray:a1]];
    NSArray * t1 = [NSArray arrayWithObjects:@"a", @"c", @"d", nil];
    NSArray * t2 = [NSArray arrayWithObjects:@"aa",@"cc", @"dd", nil];
    NSArray * t3 = [NSArray arrayWithObjects:@"d", @"e", nil];
    NSArray * t4 = [NSArray arrayWithObjects:@"d", @"e", @"f", nil];
    
    NSArray * ri = [organizer findActivitiesNotIn:initial isFirst:YES];
    NSArray * r1 = [organizer findActivitiesNotIn:t1 isFirst:YES];
    NSArray * r2 = [organizer findActivitiesNotIn:t2 isFirst:YES];
    NSArray * r3 = [organizer findActivitiesNotIn:t3 isFirst:YES];
    NSArray * r4 = [organizer findActivitiesNotIn:t4 isFirst:YES];
    
    NSUInteger ric = [ri count];;
    NSArray * e1 = [NSArray arrayWithObject:@"b"];
    NSArray * e3 = [NSArray arrayWithObjects:@"a",@"b",@"c", nil];
    XCTAssertEqualWithAccuracy(ric, 0, 0,  @"Nothing deleted from initial");
    XCTAssertTrue(r2 == nil, @"Nothing in common is error");
    XCTAssertEqualObjects(r1, e1, @"found the one to delete");
    XCTAssertEqualObjects(r3, e3, @"Found all to delete");
    XCTAssertTrue(r4==nil, @"Should never happen");//list in has last element not in organizer.
}


-(void)testOrganizerSearchAndFilter{
    GCActivitiesOrganizer * organizer = [[GCActivitiesOrganizer alloc] init];
    NSArray * samples  = @[ @[ GC_TYPE_CYCLING, @"2012-09-13T18:48:16.000Z", @1, @"meter",     @5.2,  @"minperkm", @"aa"],
                            @[ GC_TYPE_CYCLING, @"2012-09-14T18:48:16.000Z", @1, @"kilometer", @1,    @"kph", @"bb"],
                            @[ GC_TYPE_RUNNING, @"2012-09-15T18:48:16.000Z", @1, @"kilometer", @1,    @"kph",  @"aa"],
                            @[ GC_TYPE_DAY,     @"2012-09-16T18:48:16.000Z", @1, @"kilometer", @1,    @"kph", @"cc"],
                            ];
    NSMutableArray * activities = [NSMutableArray arrayWithCapacity:[samples count]];
    for (NSArray * sample in samples) {
        GCActivity * act = [[GCActivity alloc] init];
        [act changeActivityType:[GCActivityType activityTypeForKey:[sample objectAtIndex:0]]];
        [act setDate:[NSDate dateForRFC3339DateTimeString:[sample objectAtIndex:1]]];
        [act setSumDistanceCompat:[[sample objectAtIndex:2] doubleValue]];
        [act setFlags:gcFieldFlagSumDistance];
        [act setLocation:sample[6]];
        [act updateSummaryData:@{
            [self fldFor:@"WeightedMeanSpeed" act:act]:[self sumVal:[self fldFor:@"WeightedMeanSpeed" act:act] val:[[sample objectAtIndex:4] doubleValue] uom:[sample objectAtIndex:5]]}];
        [activities addObject:act];
    }
    [organizer setActivities:activities];
    XCTAssertEqual([organizer countOfFilteredActivities], samples.count);
    
    [organizer filterForQuickFilter];
    XCTAssertEqual([organizer countOfFilteredActivities], 3);
    for (NSUInteger i=0; i<[organizer countOfFilteredActivities]; i++) {
        GCActivity * act = [organizer filteredActivityForIndex:i];
        XCTAssertNotEqualObjects(act.activityType, GC_TYPE_DAY);
    }
    
    [organizer clearFilter];
    XCTAssertEqual([organizer countOfFilteredActivities], samples.count);
    
    [organizer filterForSearchString:GC_TYPE_RUNNING];
    XCTAssertEqual([organizer countOfFilteredActivities], 1);
    for (NSUInteger i=0; i<[organizer countOfFilteredActivities]; i++) {
        GCActivity * act = [organizer filteredActivityForIndex:i];
        XCTAssertEqualObjects(act.activityType, GC_TYPE_RUNNING);
    }
    
    [organizer clearFilter];
    XCTAssertEqual([organizer countOfFilteredActivities], samples.count);

    [organizer filterForSearchString:GC_TYPE_CYCLING];
    XCTAssertEqual([organizer countOfFilteredActivities], 2);
    for (NSUInteger i=0; i<[organizer countOfFilteredActivities]; i++) {
        GCActivity * act = [organizer filteredActivityForIndex:i];
        XCTAssertEqualObjects(act.activityType, GC_TYPE_CYCLING);
    }
    
    [organizer clearFilter];
    XCTAssertEqual([organizer countOfFilteredActivities], samples.count);

    [organizer filterForSearchString:@"aa"];
    XCTAssertEqual([organizer countOfFilteredActivities], 2);
    for (NSUInteger i=0; i<[organizer countOfFilteredActivities]; i++) {
        GCActivity * act = [organizer filteredActivityForIndex:i];
        XCTAssertEqualObjects(act.location,@"aa");
    }
    
}

-(void)testOrganizerTimeSeries{
    GCActivitiesOrganizer * organizer = [[GCActivitiesOrganizer alloc] init];
    NSArray * samples  = @[ @[ GC_TYPE_CYCLING, @"2012-09-13T18:48:16.000Z", @1, @"meter",     @5.2,  @"minperkm"],
                            @[ GC_TYPE_CYCLING, @"2012-09-14T18:48:16.000Z", @1, @"kilometer", @1,    @"kph"],
                            @[ GC_TYPE_RUNNING, @"2012-09-15T18:48:16.000Z", @1, @"kilometer", @1,    @"kph"]
                            ];
    NSMutableArray * activities = [NSMutableArray arrayWithCapacity:[samples count]];
    for (NSArray * sample in samples) {
        GCActivity * act = [[GCActivity alloc] init];
        [act changeActivityType:[GCActivityType activityTypeForKey:[sample objectAtIndex:0]]];
        [act setDate:[NSDate dateForRFC3339DateTimeString:[sample objectAtIndex:1]]];
        [act setSumDistanceCompat:[[sample objectAtIndex:2] doubleValue]];
        [act setFlags:gcFieldFlagSumDistance];
        [act updateSummaryData:@{
            [self fldFor:@"WeightedMeanSpeed" act:act]:[self sumVal:[self fldFor:@"WeightedMeanSpeed" act:act] val:[[sample objectAtIndex:4] doubleValue] uom:[sample objectAtIndex:5]]
            
        }];
        [activities addObject:act];
    }
    [organizer setActivities:activities];
    
    GCField * speedField = [GCField fieldForKey:@"WeightedMeanSpeed" andActivityType:GC_TYPE_ALL];
    GCField * distField  = [GCField fieldForFlag:gcFieldFlagSumDistance andActivityType:GC_TYPE_ALL];
    
    NSDictionary * rv = [organizer fieldsSeries:@[speedField,distField] matching:nil useFiltered:false ignoreMode:gcIgnoreModeActivityFocus];
    GCStatsDataSerieWithUnit * speed = [rv objectForKey:speedField];
    GCStatsDataSerieWithUnit * dist  = [rv objectForKey:distField];
    
    GCUnit * km = [GCUnit unitForKey:@"kilometer"];
    GCUnit * kph = [GCUnit unitForKey:@"kph"];
    
    XCTAssertTrue([[speed unit] isEqualToUnit:kph], @"Speed in kph");
    XCTAssertTrue([[dist unit] isEqualToUnit:km] , @"Dist in km");
    
    for (NSUInteger idx=0; idx<[[organizer activities] count]; idx++) {
        GCActivity * act = [organizer activityForIndex:idx];
        [act mergeSummaryData:@{
            [self fldFor:@"SumDuration" act:act] :               [self sumVal:[self fldFor:@"SumDuration" act:act]            val:(idx+1)       uom:@"second" ],
            [self fldFor:@"WeightedMeanPower" act:act] :         [self sumVal:[self fldFor:@"WeightedMeanPower" act:act]      val:(idx+1)*1000    uom:@"watt" ],
         }
         ];
        [GCFieldsCalculated addCalculatedFields:act];
    }
    
    
    GCField * energyField = [GCField fieldForKey:CALC_ENERGY andActivityType:GC_TYPE_ALL];
    rv = [organizer fieldsSeries:@[ energyField ] matching:nil useFiltered:false ignoreMode:gcIgnoreModeActivityFocus];
    GCStatsDataSerieWithUnit * engy = [rv objectForKey:energyField];
    
    XCTAssertTrue([[engy unit] isEqualToUnit:[GCUnit unitForKey:@"kilojoule"]], @"Calc Val worked");
    XCTAssertTrue([engy.serie count] == [[organizer activities] count], @"point for each");
    for (NSUInteger idx=0; idx<[engy.serie count]; idx++) {
        XCTAssertEqualWithAccuracy(1.*(idx+1)*(idx+1), [[engy.serie dataPointAtIndex:idx] y_data], 1e-8, @"should be square");
    }

    GCField * durfield = [GCField fieldForFlag:gcFieldFlagSumDuration andActivityType:GC_TYPE_ALL];
    
    GCHistoryFieldDataSerieConfig * config = [GCHistoryFieldDataSerieConfig configWithFilter:false field:durfield];
    GCHistoryFieldDataSerie * dataserie = [[GCHistoryFieldDataSerie alloc] initFromConfig:config];
    NSDate * limit = [NSDate dateForRFC3339DateTimeString:@"2012-09-14T00:10:16.000Z"];
    dataserie.organizer = organizer;
    void (^test)(NSString * type, NSDate * from, NSUInteger e_n) = ^(NSString * type, NSDate * from, NSUInteger e_n){
        dataserie.config.fromDate = from;
        dataserie.config.activityTypeSelection = RZReturnAutorelease([[GCActivityTypeSelection alloc] initWithActivityType:type]);
        
        [dataserie loadFromOrganizer];
        XCTAssertEqual([[dataserie history] count], e_n, @"%@/%@ expected = %d", type,from,(int)e_n);
    };
    test( GC_TYPE_ALL,nil,3);
    test( GC_TYPE_CYCLING,nil,2);
    test( GC_TYPE_RUNNING,nil,1);
    test( GC_TYPE_ALL,limit,2);
    test( GC_TYPE_RUNNING,limit,1);
    test( GC_TYPE_HIKING,nil,0);
    test( GC_TYPE_HIKING,limit,0);
    
    [organizer release];
}


-(void)testIconsExits{
    for (NSUInteger i=0; i<gcIconNavEnd; i++) {
        gcIconNav idx = (gcIconNav)i;
        UIImage * img =[GCViewIcons navigationIconFor:idx];
        XCTAssertNotNil(img, @"Image for i=%d exists", (int)i);
    }
    for (NSUInteger i=0; i<gcIconCellEnd; i++) {
        gcIconCell idx = (gcIconCell)i;
        UIImage * img =[GCViewIcons cellIconFor:idx];
        XCTAssertNotNil(img, @"Image for i=%d exists", (int)i);
    }
    for (NSUInteger i=0; i<gcIconTabEnd; i++) {
        gcIconTab idx = (gcIconTab)i;
        UIImage * img =[GCViewIcons tabBarIconFor:idx];
        XCTAssertNotNil(img, @"Image for i=%d exists", (int)i);
    }
    
}

-(void)testTimeAxisGeometry{
    GCHistoryFieldDataSerie * dataserie = [[[GCHistoryFieldDataSerie alloc] init] autorelease];
    GCStatsDataSerie * serie = [[[GCStatsDataSerie alloc] init] autorelease];
    NSDictionary * sample  = [GCTestsSamples aggregateSample];

    for (NSString * datestr in sample) {
        NSNumber * val = [sample objectForKey:datestr];
        [serie addDataPointWithDate:[NSDate dateForRFC3339DateTimeString:datestr] andValue:[val doubleValue]];
    }
    [serie sortByDate];

    dataserie.history = [GCStatsDataSerieWithUnit dataSerieWithUnit:[GCUnit unitForKey:@"dimensionless"] andSerie:serie];
    NSDate * first = [serie[0] date];
    
    GCSimpleGraphCachedDataSource * dataSource = [GCSimpleGraphCachedDataSource historyView:dataserie
                                                                               calendarConfig:[GCStatsCalendarAggregationConfig globalConfigFor:NSCalendarUnitMonth]
                                                                                graphChoice:gcGraphChoiceBarGraph
                                                  after:nil];
    
    GCSimpleGraphGeometry * geometry = [[[GCSimpleGraphGeometry alloc] init] autorelease];
    [geometry setDrawRect:CGRectMake(0., 0., 320., 405.)];
    [geometry setZoomPercentage:CGPointMake(0., 0.)];
    [geometry setOffsetPercentage:CGPointMake(0., 0.)];
    [geometry setDataSource:dataSource];
    [geometry setAxisIndex:0];
    [geometry setSerieIndex:0];
    [geometry calculate];
    [geometry calculateAxisKnobRect:gcGraphStep andAttribute:@{NSFontAttributeName:[GCViewConfig systemFontOfSize:12.]}];
    NSCalendar * cal = [GCAppGlobal calculationCalendar];
    NSDate * start = nil;

    NSTimeInterval extends;
    NSDateComponents * comp = [[[NSDateComponents alloc] init] autorelease];
    comp.month = 1;
    
    for (GCAxisKnob*point in geometry.xAxisKnobs) {
        // Check all days are first of month
        [cal rangeOfUnit:NSCalendarUnitMonth startDate:&start interval:&extends forDate:first];
        NSDate * knobDate = [NSDate dateWithTimeIntervalSinceReferenceDate:point.value];
        //XCTAssertEqualObjects(start, knobDate, @"Axis match");
        if (knobDate) {//FIXME: to avoid unused

        }
        first = [cal dateByAddingComponents:comp toDate:first options:0];
    }
     

}

-(void)testFieldValidChoices{
    NSString * defaultField = @"backhands"; // params as can change
    NSDictionary * m1 = @{
                         @"SumDuration":                    defaultField,
                         @"__healthweight":                 defaultField,
                         @"backhands"            : @"heatmap_backhands_center",
                         @"backhands_flat"       : @"heatmap_backhands_center" ,
                         @"backhands_lifted"     : @"heatmap_backhands_center" ,
                         @"backhands_sliced"     : @"heatmap_backhands_center" ,
                         @"first_serves"         : @"heatmap_serves_center",
                         @"first_serves_effect"  : @"heatmap_serves_center",
                         @"first_serves_flat"    : @"heatmap_serves_center",
                         @"forehands"            : @"heatmap_forehands_center",
                         @"forehands_flat"       : @"heatmap_forehands_center",
                         @"forehands_lifted"     : @"heatmap_forehands_center",
                         @"heatmap_all_center"   : @"forehands",
                         @"heatmap_backhands_center":@"backhands",
                         @"heatmap_forehands_center":@"forehands",
                         @"heatmap_serves_center"  :defaultField, // defaults because @"serves" not there..
                         
                         
                         @"UnkownField"           : defaultField
                         };
    
    NSDictionary * m2 =    @{
                             @"WeightedMeanRunCadence":         @"WeightedMeanPace",
                             @"SumDistance":                    @"WeightedMeanPace",
                             @"SumDuration":                    @"WeightedMeanPace",
                             @"WeightedMeanPace":               @"WeightedMeanHeartRate",
                             @"WeightedMeanHeartRate":          @"WeightedMeanPace",
                             @"WeightedMeanPower":              @"WeightedMeanPace",
                             @"WeightedMeanVerticalOscillation":@"WeightedMeanPace",
                             @"WeightedMeanGroundContactTime":  @"WeightedMeanPace",
                             @"__healthweight":                 @"WeightedMeanPace",
                             };
    for (NSDictionary * m in @[ m1, m2]) {
        NSArray * inputs =  [[m allKeys] arrayByMappingBlock:^(NSString * key){
            return [GCField fieldForKey:key andActivityType:GC_TYPE_ALL];
        }];
        NSArray * valid = [GCViewConfig validChoicesForGraphIn:inputs];
        for (GCField * field in inputs) {
            GCField * exp = [GCField fieldForKey:m[field.key] andActivityType:GC_TYPE_ALL];
            GCField * rv = [GCViewConfig nextFieldForGraph:nil fieldOrder:valid differentFrom:field];
            XCTAssertEqualObjects(rv, exp, @"next[%@] = %@ (expect: %@)", field, rv, exp);
        }
    }
}

@end
