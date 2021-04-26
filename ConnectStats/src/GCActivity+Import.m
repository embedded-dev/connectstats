//  MIT Licence
//
//  Created on 12/02/2014.
//
//  Copyright (c) 2014 Brice Rosenzweig.
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

#import "GCActivity+Import.h"
#import "GCActivitySummaryValue.h"
#import "GCActivityMetaValue.h"
#import "GCFieldsCalculated.h"
#import "GCAppGlobal.h"
#import "GCActivity+Database.h"
#import "GCService.h"
#import "GCTrackPoint.h"
#import "GCHealthKitSamplesToPointsParser.h"
#import "GCActivityType.h"
#import "GCActivityTypes.h"
#import "GCField+Convert.h"

#ifdef GC_USE_HEALTHKIT
#import <HealthKit/HealthKit.h>
#endif

@implementation GCActivity (Internal)

-(GCActivity*)initWithId:(NSString *)aId andConnectStatsData:(NSDictionary*)aData{
    self = [self initWithId:aId];
    if (self) {
        self.activityId = aId;
        self.serviceStatus = 1;
        [self parseConnectStatsJson:aData];
        self.settings = [GCActivitySettings defaultsFor:self];
    }
    return self;
}

-(GCActivity*)initWithId:(NSString*)aId andGarminData:(NSDictionary*)aData{
    self = [self initWithId:aId];
    if (self) {
        [self parseModernGarminJson:aData];
        self.serviceStatus = 1 << 4;
        self.settings = [GCActivitySettings defaultsFor:self];
    }
    return self;
}


-(GCActivity*)initWithId:(NSString*)aId andStravaData:(NSDictionary*)aData{
    self = [self initWithId:aId];
    if (self) {
        self.activityId = aId;
        self.serviceStatus = 1 << 8;
        [self parseStravaJson:aData];
        self.settings = [GCActivitySettings defaultsFor:self];
    }
    return self;
}

-(GCActivity*)initWithId:(NSString *)aId andHealthKitWorkout:(HKWorkout*)workout withSamples:(NSArray*)samples{
    self = [self init];
    if (self) {
#ifdef GC_USE_HEALTHKIT
        self.activityId = aId;
        [self parseHealthKitWorkout:workout withSamples:samples];
        self.settings = [GCActivitySettings defaultsFor:self];
    }
#endif
    return self;
}

-(GCActivity*)initWithId:(NSString *)aId andHealthKitSummaryData:(NSDictionary*)dict{
    self = [self init];
    if (self) {
        self.activityId = aId;
        [self parseHealthKitSummaryData:dict];
    }
    return self;
}

#pragma mark - Generic Import Tools


-(void)mergeSummaryData:(NSDictionary<GCField*,GCActivitySummaryValue*>*)newDict{
    NSMutableDictionary<GCField*,GCActivitySummaryValue*> * merged = self.summaryData ? [NSMutableDictionary dictionaryWithDictionary:self.summaryData] : [NSMutableDictionary dictionaryWithCapacity:newDict.count];

    for (GCField * field in newDict) {
        GCActivitySummaryValue * new = newDict[field];
        if( new.value != 0. || field.isZeroValid ){
            merged[field] = new;
#if TARGET_IPHONE_SIMULATOR
        }else{
            static NSMutableDictionary * cache = nil;
            if( cache == nil){
                cache = RZReturnRetain([NSMutableDictionary dictionary]);
            }
            if( cache[field] == nil){
                cache[field] = @1;
            }
#endif
        }
    }
    [self updateSummaryData:merged];
}

-(void)parseData:(NSDictionary*)data into:(NSMutableDictionary<GCField*,GCActivitySummaryValue*>*)newSummaryData usingDefs:(NSDictionary*)defs{
    for (NSString * key in data) {
        id def = defs[key];
        NSString * fieldkey = nil;
        NSString * uom = nil;
        NSNumber * val = nil;
        gcFieldFlag flag = gcFieldFlagNone;
        if (def) {
            id valo = data[key];
            if ([valo isKindOfClass:[NSNumber class]]) {
                val = valo;
            }else if ([valo isKindOfClass:[NSString class]]){
                val = @([valo doubleValue]);
            }
            if ([def isKindOfClass:[NSDictionary class]]) {
                NSDictionary * subdefs = def;
                NSArray * thisdef = subdefs[self.activityType];
                if (thisdef) {
                    fieldkey = thisdef[0];
                    uom = thisdef[1];
                }
            }else if ([def isKindOfClass:[NSArray class]]){
                NSArray * subdefs = def;
                if (subdefs) {
                    fieldkey = subdefs[0];
                    uom = subdefs[2];
                    id flago = subdefs[1];
                    if ([flago isKindOfClass:[NSNumber class]]) {
                        flag = [flago intValue];
                    }
                }
            }
#if TARGET_IPHONE_SIMULATOR
            // If running in simulator display what fields are missing
        }else{
            static NSDictionary * knownMissing = nil;
            if( knownMissing == nil){
                knownMissing = @{
                    @"activityId" : @1, // sample: 2477200414
                    @"achievement_count" : @1, // sample: 0
                    @"activityTrainingLoad" : @1, // sample: 114.1391448974609
                    @"anaerobicTrainingEffect" : @1, // sample: 1.600000023841858
                    @"athlete_count" : @1, // sample: 4
                    @"atpActivity" : @1, // sample: 0
                    @"autoCalcCalories" : @1, // sample: 0
                    @"averagePaceInMinutesPerKilometer": @5.414771,
                    @"averageStrokeDistance" : @1, // sample: 2.589999914169312
                    @"avgGroundContactBalance" : @1, // sample: 49.84000015258789
                    @"avgGroundContactTime" : @1, // sample: 256.3999938964844
                    @"avgRespirationRate" : @1, // sample: 20.75
                    @"avgVerticalOscillation" : @1, // sample: 9.030000305175781
                    @"avgVerticalRatio" : @1, // sample: 7.46999979019165
                    @"beginTimestamp" : @1, // sample: 1576060479000
                    @"caloriesConsumed" : @1, // sample: 0
                    @"comment_count" : @1, // sample: 0
                    @"commute" : @1, // sample: 0
                    @"deviceId" : @1, // sample: 3305029741
                    @"device_watts" : @1, // sample: 1
                    @"display_hide_heartrate_option" : @1, // sample: 1
                    @"elev_high" : @1, // sample: -12.6
                    @"elev_low" : @1, // sample: -27.2
                    @"elevationCorrected" : @1, // sample: 0
                    @"endLatitude" : @1, // sample: 51.4716518484056
                    @"endLongitude" : @1, // sample: -0.1953904610127211
                    @"excludeFromPowerCurveReports" : @1, // sample: 0
                    @"favorite" : @1, // sample: 0
                    @"flagged" : @1, // sample: 0
                    @"from_accepted_tag" : @1, // sample: 0
                    @"hasPolyline":@1,
                    @"hasSplits" : @1, // sample: 0
                    @"hasVideo" : @1, // sample: 0
                    @"has_heartrate" : @1, // sample: 1
                    @"has_kudoed" : @1, // sample: 0
                    @"heartrate_opt_out" : @1, // sample: 0
                    @"id" : @1, // sample: 730019974
                    @"isMultiSportParent" : @1, // sample: 0
                    @"isParent":@0,
                    @"kudos_count" : @1, // sample: 0
                    @"lactateThresholdBpm" : @1, // sample: 173
                    @"lapCount" : @1, // sample: 5
                    @"lapIndex" : @1, // sample: 1
                    @"lapcount":@1,
                    @"lengthIndex" : @1, // sample: 1
                    @"manual" : @1, // sample: 0
                    @"manualActivity" : @1, // sample: 0
                    @"maxAvgPower_1" : @1, // sample: 529
                    @"maxAvgPower_10" : @1, // sample: 423
                    @"maxAvgPower_120" : @1, // sample: 245
                    @"maxAvgPower_1200" : @1, // sample: 119
                    @"maxAvgPower_1800" : @1, // sample: 106
                    @"maxAvgPower_2" : @1, // sample: 517
                    @"maxAvgPower_20" : @1, // sample: 391
                    @"maxAvgPower_30" : @1, // sample: 357
                    @"maxAvgPower_300" : @1, // sample: 168
                    @"maxAvgPower_3600" : @1, // sample: 136
                    @"maxAvgPower_5" : @1, // sample: 465
                    @"maxAvgPower_60" : @1, // sample: 283
                    @"maxAvgPower_600" : @1, // sample: 136
                    @"maxAvgPower_7200" : @1, // sample: 128
                    @"maxDoubleCadence" : @1, // sample: 174
                    @"maxFtp" : @1, // sample: 213
                    @"maxPaceInMinutesPerKilometer": @4.8676014,
                    @"maxRespirationRate" : @1, // sample: 20.75
                    @"maxVerticalSpeed" : @1, // sample: 0.6000003814697266
                    @"max_watts" : @1, // sample: 474
                    @"minActivityLapDuration" : @1, // sample: 355.85400390625
                    @"minRespirationRate" : @1, // sample: 20.75
                    @"numberOfActiveLengths" : @1, // sample: 120
                    @"ownerId" : @1, // sample: 3020883
                    @"parent" : @1, // sample: 0
                    @"photo_count" : @1, // sample: 0
                    @"poolLength" : @1, // sample: 33.33000183105469
                    @"pr" : @1, // sample: 0
                    @"pr_count" : @1, // sample: 0
                    @"private" : @1, // sample: 0
                    @"purposeful" : @1, // sample: 0
                    @"resource_state" : @1, // sample: 2
                    @"sportTypeId" : @1, // sample: 1
                    @"startLatitude" : @1, // sample: 51.47172099910676
                    @"startLongitude" : @1, // sample: -0.1958300918340683
                    @"startTimeInSeconds" : @1, // sample: 1576060479
                    @"startTimeOffsetInSeconds": @0,
                    @"start_latitude" : @1, // sample: 51.52
                    @"start_longitude" : @1, // sample: -0.1
                    @"startingLatitudeInDegree": @51.47216607816517,
                    @"startingLongitudeInDegree": @0.1960058603435755,
                    @"steps" : @1, // sample: 8342
                    @"strokes" : @1, // sample: 1546
                    @"suffer_score" : @1, // sample: 9
                    @"timeZoneId" : @1, // sample: 149
                    @"total_photo_count" : @1, // sample: 0
                    @"trainer" : @1, // sample: 0
                    @"upload_id" : @1, // sample: 804813097
                    @"userPro" : @1, // sample: 0
                    @"userProfileId" : @1, // sample: 3020883
                    @"utc_offset" : @1, // sample: 3600
                    @"waterConsumed" : @1, // sample: 0
                    @"waterEstimated" : @1, // sample: 435
                    @"weighted_average_watts" : @1, // sample: 129
                    @"workout_type" : @1, // sample: 0
                    
                };
                [knownMissing retain];
            }
            
            static NSMutableDictionary * recordMissing = nil;
            if( recordMissing == nil){
                recordMissing = [NSMutableDictionary dictionary];
                [recordMissing retain];
            }
            if( ! recordMissing[key] ){
                NSNumber * sample = nil;
                if( [data[key] isKindOfClass:[NSNumber class]]){
                    sample = data[key];
                    recordMissing[key] = @1;
                }
                if( sample != nil && knownMissing[key] == nil){
                    RZLog(RZLogInfo, @"Modern Unknown Key: @\"%@\" : @1, // sample: %@", key, sample);
                }
            }
#endif
        }
        if (fieldkey && uom && val) {
            GCField * field = [GCField fieldForKey:fieldkey andActivityType:self.activityType];
            GCActivitySummaryValue * sumVal = [self buildSummaryValue:fieldkey uom:uom fieldFlag:flag andValue:val.doubleValue];
            newSummaryData[field] = sumVal;
        }
    }
}


-(GCActivitySummaryValue*)buildSummaryValue:(NSString*)fieldkey uom:(NSString*)uom fieldFlag:(gcFieldFlag)flag andValue:(double)val{
    GCField * field = [GCField fieldForKey:fieldkey andActivityType:self.activityType];
    GCUnit * unit = [GCUnit unitForKey:uom];
    
    // Prefer predefined units
    NSString * display = field.displayName;
    NSString * displayuom = field.unit.key;

    if( !displayuom && unit){
        displayuom = unit.key;
    }
    if (!display) {
        display = [field correspondingFieldForActivityType:GC_TYPE_ALL].displayName;
    }
    
    GCNumberWithUnit * nu = [GCNumberWithUnit numberWithUnitName:uom andValue:val];
    if (displayuom && ![displayuom isEqualToString:uom]) {
        nu = [nu convertToUnitName:displayuom];
    }
    GCActivitySummaryValue * sumVal = [GCActivitySummaryValue activitySummaryValueForField:field value:nu];
    [GCFields registerMissingField:field displayName:display andUnitName:displayuom];
    return sumVal;
}

-(void)addPaceIfNecessaryWithSummary:(NSMutableDictionary<GCField*,GCActivitySummaryValue*>*)newSummaryData{
    GCActivitySummaryValue * speed = newSummaryData[ [GCField fieldForKey:@"WeightedMeanSpeed" andActivityType:self.activityType]];
    if (speed && [GCFields pacePreferredForActivityType:self.activityType]) {
        GCField * field = [GCField fieldForKey:@"WeightedMeanPace" andActivityType:self.activityType];
        GCNumberWithUnit * val = [[speed numberWithUnit] convertToUnit:field.unit];
        newSummaryData[field] = [GCActivitySummaryValue activitySummaryValueForField:field value:val];
    }
    GCActivitySummaryValue * movingSpeed = newSummaryData[ [GCField fieldForKey:@"WeightedMeanMovingSpeed" andActivityType:self.activityType] ];
    if(movingSpeed && [GCFields pacePreferredForActivityType:self.activityType]){
        GCField * field = [GCField fieldForKey:@"WeightedMeanMovingSpeed" andActivityType:self.activityType];

        GCNumberWithUnit * val = [[movingSpeed numberWithUnit] convertToUnit:field.unit];
        newSummaryData[field] = [GCActivitySummaryValue activitySummaryValueForField:field value:val];
    }
}

#pragma mark - ConnectStats Service


-(NSMutableDictionary*)buildSummaryDataFromGarminConnectStatsData:(NSDictionary*)data{
    
    NSArray * fields = @[
                         @"summaryId", //     string     Unique identifier for the summary.
                         @"activityType", //     string     Text description of the activity type. See Appendix A for a complete list.
                         @"deviceName", //     string     Only Fitness activities are associated with a specific Garmin device rather than the user’s overall account. If the user wears two devices at once at the same time and starts a Fitness Activity on each then both will generate separate Activities with two different deviceNames.
                         @"isParent", //     boolean     If present and set to true, this activity is the parent activity of one or more child activities that should also be made available, // in the data feed to the partner. An activity of type MULTI_SPORT is an example of a parent activity.
                         @"parentSummaryId", //     integer     If present, this is the summaryId of the related parent activity. An activity of type CYCLING with a parent activity of type MULTI_SPORT is an example of this type of relationship.
                         @"manual", //     boolean     Indicates that the activity was manually entered directly on the Connect site. This property will only exist for manual activities
                         
                         @"startTimeInSeconds", //     integer     Start time of the activity in seconds since January 1, 1970, 00:00:00 UTC (Unix timestamp).
                         @"startTimeOffsetInSeconds", //     integer     Offset in seconds to add to startTimeInSeconds to derive the "local" time of the device that captured the data.
                         //@"durationInSeconds", //     integer     Length of the monitoring period in seconds.
                         //@"averageBikeCadenceInRoundsPerMinute", //     floating point
                         //@"averageHeartRateInBeatsPerMinute", //     integer
                         //@"averageRunCadenceInStepsPerMinute", //     floating point
                         //@"averageSpeedInMetersPerSecond", //     floating point
                         @"averageSwimCadenceInStrokesPerMinute", //     floating point
                         @"averagePaceInMinutesPerKilometer", //     floating point
                         //@"activeKilocalories", //     integer
                         //@"distanceInMeters", //     floating point
                         @"maxBikeCadenceInRoundsPerMinute", //     floating point
                         //@"maxHeartRateInBeatsPerMinute", //     floating point
                         @"maxPaceInMinutesPerKilometer", //     floating point
                         @"maxRunCadenceInStepsPerMinute", //     floating point
                         //@"maxSpeedInMetersPerSecond", //     floating point
                         @"numberOfActiveLengths", //     integer
                         @"startingLatitudeInDegree", //     floating point
                         @"startingLongitudeInDegree", //     floating point
                         @"steps", //     integer
                         //@"totalElevationGainInMeters", //     floating point
                         //@"totalElevationLossInMeters", //     floating point
                         ];
    return [NSMutableDictionary dictionaryWithObjects:fields forKeys:fields];
}
-(void)parseConnectStatsJson:(NSDictionary*)data{
    NSDictionary * defs = @{
                            //@"moving_time":         @[ @"SumMovingDuration",    @"",                                    @"second"],
                            //@"average_watts":       @[ @"WeightedMeanPower",    @(gcFieldFlagPower),                    @"watt"],
                            //@"kilojoules":          @[ @"SumTotalWork",         @"",                                    @"kilojoule"],
                            //@"average_temp":        @[ @"WeightedMeanAirTemperature",@"",                               @"celcius"],
                            
                            //@"start_date":          @[ @"BeginTimeStamp",       @"",                                    @"time"],
                            //@"start_latlng":        @[ @[@"BeginLatitude",@"BeginLongitude"],@"vector", @"dd"],
                            //@"end_latlng":          @[ @[@"EndLatitude",  @"EndLongitude"],  @"vector", @"dd"],
                            
                            
                            @"durationInSeconds":        @[ @"SumDuration",          @(gcFieldFlagSumDuration),              @"second"],
                            @"averageHeartRateInBeatsPerMinute":   @[ @"WeightedMeanHeartRate",@(gcFieldFlagWeightedMeanHeartRate),    @"bpm"],
                            @"averageSpeedInMetersPerSecond":       @[ @"WeightedMeanSpeed",    @(gcFieldFlagWeightedMeanSpeed),        @"mps"],
                            @"activeKilocalories":            @[ @"SumEnergy",            @"",                                    @"kilocalorie"],
                            @"distanceInMeters":            @[ @"SumDistance",          @(gcFieldFlagSumDistance),              @"meter"],
                            @"maxHeartRateInBeatsPerMinute":       @[ @"MaxHeartRate",         @"",                                    @"bpm"],
                            @"maxSpeedInMetersPerSecond":           @[ @"MaxSpeed",             @"",                                    @"mps"],
                            @"totalElevationGainInMeters":@[ @"GainElevation",        @"",                                    @"meter"],
                            @"totalElevationLossInMeters":@[ @"LossElevation",        @"",                                    @"meter"],

                            @"averageBikeCadenceInRoundsPerMinute": @[  @"WeightedMeanBikeCadence", @(gcFieldFlagCadence), @"rpm" ],
                            @"averageRunCadenceInStepsPerMinute": @[ @"WeightedMeanRunCadence", @(gcFieldFlagCadence), @"doubleStepsPerMinute" ],

                            @"maxBikeCadenceInRoundsPerMinute": @[  @"MaxBikeCadence", @(gcFieldFlagCadence), @"rpm" ],
                            @"maxRunCadenceInStepsPerMinute": @[ @"MaxRunCadence", @(gcFieldFlagCadence), @"doubleStepsPerMinute" ],

                            
                            };
    
    GCService * service = [GCService service:gcServiceConnectStats];
    
    self.activityId = [service activityIdFromServiceId:data[@"cs_activity_id"]];
    
    self.externalServiceActivityId = [[GCService service:gcServiceGarmin] activityIdFromServiceId:data[@"summaryId"]];
    
    GCActivityType * atype = [GCActivityType activityTypeForConnectStatsType:data[@"activityType"]];
    [self changeActivityType:atype];
    self.activityName = @"";
    self.location = @"";
    self.downloadMethod = gcDownloadMethodConnectStats;
    
    NSMutableDictionary * meta = [NSMutableDictionary dictionary];
    if( data[@"deviceName"] ){
        meta[ GC_META_DEVICE ] = [GCActivityMetaValue activityMetaValueForDisplay:data[@"deviceName"] andField:GC_META_DEVICE];
    }
    if( atype ){
        meta[ GC_META_ACTIVITYTYPE ] = [GCActivityMetaValue activityMetaValueForDisplay:atype.displayName key:atype.key andField:GC_META_ACTIVITYTYPE];
    }
    [self addEntriesToMetaData:meta];
    
    if (self.activityId && self.activityType) {
        NSMutableDictionary * newSummaryData = [NSMutableDictionary dictionaryWithCapacity:data.count];
        [self parseData:data into:newSummaryData usingDefs:defs];
        
        // few extra derived
        [self addPaceIfNecessaryWithSummary:newSummaryData];
        [self mergeSummaryData:newSummaryData];
        
        NSString * lat = data[@"startingLatitudeInDegree"];
        NSString * lon = data[@"startingLongitudeInDegree"];
        
        if ([lat respondsToSelector:@selector(doubleValue)] && [lon respondsToSelector:@selector(doubleValue)]) {
            self.beginCoordinate = CLLocationCoordinate2DMake([lat doubleValue], [lon doubleValue]);
        }
        self.location = @"";
        NSString * startdate = data[@"startTimeInSeconds"];
        if([startdate respondsToSelector:@selector(doubleValue)]) {
            self.date = [NSDate dateWithTimeIntervalSince1970:[startdate doubleValue] ];
            if (!self.date) {
                RZLog(RZLogError, @"%@: Invalid date %@", self.activityId, startdate);
            }
        }else{
            RZLog(RZLogError, @"%@: Invalid date %@", self.activityId, startdate);
        }
        NSString * externalId = data[@"summaryId"];
        if([externalId isKindOfClass:[NSString class]]){
            self.externalServiceActivityId = [[GCService service:gcServiceGarmin] activityIdFromServiceId:externalId];
        }
        NSString * parentId = data[@"parentSummaryId"];
        if( parentId ){
            self.parentId = data[@"parentSummaryId"];
        }
    }
    
}


#pragma mark - Garmin Web Service

-(void)parseModernGarminJson:(NSDictionary*)data{
    GCService * service = [GCService service:gcServiceGarmin];

    NSString * foundActivityId = data[@"activityId"];
    if( [foundActivityId respondsToSelector:@selector(stringValue)]){
        self.activityId = [service activityIdFromServiceId:[data[@"activityId"] stringValue]];
    }
    NSNumber * parentId = data[@"parentId"];
    if ([parentId isKindOfClass:[NSNumber class]]) {
        self.parentId = [parentId stringValue];
    }

    NSDictionary * typeData = data[@"activityType"] ?: data[@"activityTypeDTO"];
    if([typeData isKindOfClass:[NSDictionary class]]){
        NSString * foundType = typeData[@"typeKey"] ?: typeData[@"key"]; // activityType->key, activityTypeDTO->typeKey
        if([foundType isKindOfClass:[NSString class]]){
            GCActivityType * fullType = [GCActivityType activityTypeForKey:foundType];
            if (fullType) {
                [self changeActivityType:fullType];
            }else{
                RZLog(RZLogWarning,@"Unable to find type for %@", foundType);
            }
        }
    }
    NSString * foundName = data[@"activityName"];
    if ([foundName isKindOfClass:[NSString class]]) {
        self.activityName = foundName;
    }else{
        self.activityName = @"";
    }

    self.location = @"";
    self.downloadMethod = gcDownloadMethodModern;

    [self parseGarminModernSummaryData:data dtoUnits:false];
    NSDictionary * foundSummaryDTO = data[@"summaryDTO"];
    if([foundSummaryDTO isKindOfClass:[NSDictionary class]]){
        [self parseGarminModernSummaryData:foundSummaryDTO dtoUnits:true];
    }
    [self updateMetadataFromModernGarminJson:data];
    NSDictionary * foundMetaDTO = data[@"metadataDTO"];
    if( [foundMetaDTO isKindOfClass:[NSDictionary class]]){
        [self updateMetadataFromModernGarminJson:foundMetaDTO];
    }
    
    if (self.metaData==nil) {
        [self updateMetaData:[NSMutableDictionary dictionary]];
    }
    NSArray * foundConnectIQ = data[@"connectIQMeasurements"];
    if( [foundConnectIQ isKindOfClass:[NSArray class]]){
        [self updateConnectIQData:foundConnectIQ];
    }
    
}

-(void)updateConnectIQData:(NSArray*)array{
    NSMutableDictionary<GCField*,GCActivitySummaryValue*> * data = [NSMutableDictionary dictionary];
    for (NSDictionary * one in array) {
        if( [one isKindOfClass:[NSDictionary class]]){
            NSString * appId = one[@"appID"];
            NSNumber * fieldNumber = one[@"developerFieldNumber"];
            if( appId && fieldNumber){
                NSString * fieldkey = [GCField fieldKeyForConnectIQAppID:appId andFieldNumber:fieldNumber];
                NSString * unitname  = [GCField unitNameForConnectIQAppID:appId andFieldNumber:fieldNumber];
                NSNumber * val = one[@"value"];
                if( fieldkey && unitname){
                    GCField * field = [GCField fieldForKey:fieldkey andActivityType:self.activityType];
                    GCActivitySummaryValue * value = [GCActivitySummaryValue activitySummaryValueForField:field value:[GCNumberWithUnit numberWithUnitName:unitname andValue:val.doubleValue]];
                    data[ field ] = value;
                }
            }
        }
    }
    if( data.count > 0){
        [self mergeSummaryData:data];
    }
}

-(void)updateMetadataFromModernGarminJson:(NSDictionary*)meta{
    NSArray * childIds = meta[@"childIds"];

    if( [childIds isKindOfClass:[NSArray class]] ){
        self.childIds = childIds;
    }

    NSMutableDictionary * extraMeta = self.metaData ? [NSMutableDictionary dictionaryWithDictionary:self.metaData] : [NSMutableDictionary dictionary];

    static NSDictionary * _metaKeys = nil;
    if( _metaKeys == nil){
        _metaKeys = @{
                      @"activityName" : @"activityName", // Sample: "City of Westminster Virtual Cycling",
                      @"description" : GC_META_DESCRIPTION, //Sample: "zzzNote this is a note",
                      //@"eventType" : @"eventType", //Sample: { "typeId" : 9, "typeKey" : "uncategorized", "sortOrder" : 10  },
                      @"comments" : @"comments", //Sample: null,
                      @"ownerDisplayName" : @"ownerDisplayName", //Sample: "BriceGarminFitTest",
                      @"ownerFullName" : @"ownerFullName", //Sample: "Brice Rosenzweig",
                      @"courseId" : @"courseId", //Sample: null,
                      @"hasVideo" : @"hasVideo", //Sample: false,
                      @"videoUrl" : @"videoUrl", //Sample: null,
                      @"timeZoneId" : @"timeZoneId", //Sample: 120,
                      @"workoutId" : @"workoutId", //Sample: null,
                      @"deviceId" : @"deviceId", //Sample: 3825981698,
                      @"locationName" : @"locationName", //Sample: "City of Westminster",
                      @"favorite" : @"favorite", //Sample: false,
                      @"pr" : @"pr", //Sample: false,
                      @"elevationCorrected" : @"elevationCorrected", //Sample: false,
                      @"purposeful" : @"purposeful", //Sample: false
                      
                      @"agentApplicationInstallationId" : @"agentApplicationInstallationId",
                      @"deviceApplicationInstallationId" : @"deviceApplicationInstallationId",
                      };
        [_metaKeys retain];
    }
    
    if( self.activityTypeDetail && extraMeta[GC_META_ACTIVITYTYPE] == nil){
        GCActivityMetaValue * typeMeta = [GCActivityMetaValue activityMetaValueForDisplay:self.activityTypeDetail.displayName andField:GC_META_ACTIVITYTYPE];
        typeMeta.key = self.activityTypeDetail.key;
        extraMeta[GC_META_ACTIVITYTYPE] = typeMeta;
    }
    for( NSString * key in _metaKeys.allKeys){
        NSString * mappedKey = _metaKeys[key];
        id keyValue = meta[key];
        if( [keyValue isKindOfClass:[NSNumber class]]){
            GCActivityMetaValue * metaVal = [GCActivityMetaValue activityMetaValueForDisplay:[keyValue stringValue] andField:mappedKey];
            extraMeta[ mappedKey ] = metaVal;
        }else if ([keyValue isKindOfClass:[NSString class]]){
            GCActivityMetaValue * metaVal = [GCActivityMetaValue activityMetaValueForDisplay:keyValue andField:mappedKey];
            extraMeta[ mappedKey ] = metaVal;
        }
    }
    [self updateMetaData:extraMeta];

}



/**
 Build summary data using new format from garmin. Note some format have inconsistent units
 the dictionary for search have a few units for elevation and elapsed duration that are smaller.

 @param data dictionary coming from garmin
 @param dtoUnits true if data cames from summaryDTO dictionary (as some units are different)
 @return dictionary field -> summary data
 */
-(NSMutableDictionary*)buildSummaryDataFromGarminModernData:(NSDictionary*)data dtoUnits:(BOOL)dtoUnitsFlag{
    static NSDictionary * defs = nil;
    static NSDictionary * defs_dto = nil;
    if( defs == nil){
        NSDictionary * nonDto = @{
                               @"maxElevation":        @[ @"MaxElevation",        @"",                                    @"centimeter"],
                               @"minElevation":        @[ @"MinElevation",        @"",                                    @"centimeter"],
                               @"elapsedDuration":     @[ @"SumElapsedDuration",   @"",                                    @"ms"],

                               };
        
        NSDictionary * dto = @{
                                  @"maxElevation":        @[ @"MaxElevation",        @"",                                    @"meter"],
                                  @"minElevation":        @[ @"MinElevation",        @"",                                    @"meter"],
                                  @"elapsedDuration":     @[ @"SumElapsedDuration",   @"",                                    @"second"],
                                  
                                  };

        
        NSDictionary * commondefs = @{
                 @"distance":            @[ @"SumDistance",          @(gcFieldFlagSumDistance),              @"meter"],
                 @"movingDuration":      @[ @"SumMovingDuration",    @"",                                    @"second"],
                 @"duration":            @[ @"SumDuration",          @(gcFieldFlagSumDuration),              @"second"],

                 @"elevationGain":       @[ @"GainElevation",        @(gcFieldFlagAltitudeMeters),           @"meter"],
                 @"elevationLoss":       @[ @"LossElevation",        @"",                                    @"meter"],
                 

                 @"averageSpeed":        @[ @"WeightedMeanSpeed",    @(gcFieldFlagWeightedMeanSpeed),        @"mps"],
                 @"averageMovingSpeed":  @[ @"WeightedMeanMovingSpeed",    @"",        @"mps"],
                 @"maxSpeed":            @[ @"MaxSpeed",             @"",                                    @"mps"],

                 @"calories":            @[ @"SumEnergy",            @"",                                    @"kilocalorie"],

                 @"averageHR":           @[ @"WeightedMeanHeartRate",@(gcFieldFlagWeightedMeanHeartRate),    @"bpm"],
                 @"maxHR":               @[ @"MaxHeartRate",         @"",                                    @"bpm"],

                 @"averageTemperature":        @[ @"WeightedMeanAirTemperature",@"",                               @"celsius"],
                 @"maxTemperature":        @[ @"MaxAirTemperature",@"",                               @"celsius"],
                 @"minTemperature":        @[ @"MinAirTemperature",@"",                               @"celsius"],

                 /* RUNNING */
                 @"groundContactTime":   @[ @"WeightedMeanGroundContactTime", @"", @"ms"],
                 @"groundContactBalanceLeft":   @[ @"WeightedMeanGroundContactBalanceLeft", @"", @"percent"],
                 @"verticalRatio":           @[ @"WeightedMeanVerticalRatio", @"", @"percent"],//CHECK
                 @"avgPower":               @[ @"WeightedMeanPower", @(gcFieldFlagPower), @"watt"],
                 @"strideLength":    @[ @"WeightedMeanStrideLength", @"", @"centimeter"],
                 @"avgStrideLength": @[ @"WeightedMeanStrideLength", @"", @"centimeter"],
                 @"averageStrideLength": @[ @"WeightedMeanStrideLength", @"", @"centimeter"],
                 @"verticalOscillation": @[@"WeightedMeanVerticalOscillation", @"", @"centimeter"],

                 @"averageRunningCadenceInStepsPerMinute": @[ @"WeightedMeanRunCadence", @(gcFieldFlagCadence), @"doubleStepsPerMinute"],
                 @"maxRunningCadenceInStepsPerMinute":   @[ @"MaxRunCadence", @"", @"doubleStepsPerMinute"],

                 @"averageRunCadence": @[ @"WeightedMeanRunCadence", @(gcFieldFlagCadence), @"doubleStepsPerMinute"],
                 @"maxRunCadence":   @[ @"MaxRunCadence", @"", @"doubleStepsPerMinute"],
                 
                 @"trainingEffect": @[ @"SumTrainingEffect", @"", @"te"],
                 @"aerobicTrainingEffect": @[ @"SumTrainingEffect", @"", @"te"],
                 @"lactateThresholdHeartRate": 	 @[ @"DirectLactateThresholdHeartRate", @"", @"bpm"],
                 @"lactateThresholdSpeed": 	@[ @"DirectLactateThresholdSpeed", @"", @"mps"],

                 /* CYCLE */
                 
                 @"averageBikingCadenceInRevPerMinute": @[ @"WeightedMeanBikeCadence", @(gcFieldFlagCadence), @"rpm"],
                 @"maxBikingCadenceInRevPerMinute":   @[ @"MaxBikeCadence", @"", @"rpm"],

                 @"averagePower":       @[ @"WeightedMeanPower",    @(gcFieldFlagPower),                    @"watt"],
                 @"maxPower":       @[ @"MaxPower",    @"",                    @"watt"],
                 @"minPower":       @[ @"MinPower",    @"",                    @"watt"],
                 @"maxPowerTwentyMinutes":       @[ @"MaxPowerTwentyMinutes",    @"",                    @"watt"],
                 @"max20MinPower":              @[ @"MaxPowerTwentyMinutes",     @"",                    @"watt"],
                 @"normalizedPower":       @[ @"WeightedMeanNormalizedPower",    @"",                    @"watt"],
                 @"normPower":              @[ @"WeightedMeanNormalizedPower",    @"",                    @"watt"],
                 @"functionalThresholdPower":    @[@"ThresholdPower", @"", @"watt"],

                 @"totalWork":          @[ @"SumTotalWork",         @"",                                    @"kilocalorie"],
                 @"trainingStressScore": @[ @"SumTrainingStressScore", @"", @"dimensionless"],
                 @"intensityFactor": @[ @"SumIntensityFactor", @"", @"if"],

                 @"leftTorqueEffectiveness": @[ @"WeightedMeanLeftTorqueEffectiveness", @"", @"percent"],
                 @"leftPedalSmoothness": @[ @"WeightedMeanLeftPedalSmoothness", @"", @"percent"],
                 @"totalNumberOfStrokes": @[ @"SumStrokes", @"", @"dimensionless"],

                 /* SWIMMING */
                 @"averageSwimCadenceInStrokesPerMinute": @[ @"WeightedMeanSwimCadence", @"", @"strokesPerMinute"],
                 @"maxSwimCadenceInStrokesPerMinute" : @[ @"MaxSwimCadence", @"", @"strokesPerMinute"],
                 @"averageStrokes": @[ @"WeightedMeanStrokes", @"", @"dimensionless"],
                 @"averageSWOLF" : @[ @"WeightedMeanSwolf", @"", @"dimensionless"],
                 //@"averageStrokeDistance" : @[ @""],

                 /* ALL */
                 @"vO2MaxValue" : @[ @"DirectVO2Max", @"", @"ml/kg/min"],
                 };
        
        NSMutableDictionary * buildDefs = [NSMutableDictionary dictionaryWithDictionary:commondefs];
        NSMutableDictionary * buildDefs_dto = [NSMutableDictionary dictionaryWithDictionary:commondefs];
        for (NSString * key in nonDto) {
            buildDefs[key] = nonDto[key];
        }
        for (NSString * key in dto) {
            buildDefs_dto[key] = dto[key];
        }
        
        defs = [NSDictionary dictionaryWithDictionary:buildDefs];
        defs_dto = [NSDictionary dictionaryWithDictionary:buildDefs_dto];
        
        RZRetain(defs);
        RZRetain(defs_dto);
    }
    NSMutableDictionary * newSummaryData = [NSMutableDictionary dictionaryWithCapacity:data.count];
    [self parseData:data into:newSummaryData usingDefs:dtoUnitsFlag?defs_dto:defs];
    // few extra derived
    [self addPaceIfNecessaryWithSummary:newSummaryData];

    return newSummaryData;
}

-(CLLocationCoordinate2D)buildCoordinateFromGarminModernData:(NSDictionary*)data{

    NSNumber * startLat = data[@"startLatitude"];
    NSNumber * startLon = data[@"startLongitude"];

    if (startLat && startLon && [startLat isKindOfClass:[NSNumber class]] && [startLon isKindOfClass:[NSNumber class]]) {
        return CLLocationCoordinate2DMake([startLat doubleValue], [startLon doubleValue]);
    }
    return CLLocationCoordinate2DMake(0, 0);
}

-(NSDate*)buildStartDateFromGarminModernData:(NSDictionary*)data{
    NSDate*rv=nil;
    NSString * startdate = data[@"startTimeGMT"];
    if([startdate isKindOfClass:[NSString class]]) {
        rv = [NSDate dateForGarminModernString:startdate];
        if (!rv) {
            RZLog(RZLogError, @"%@: Invalid date %@", self.activityId, startdate);
        }
    }
    return rv;
}

-(void)parseGarminModernSummaryData:(NSDictionary*)data dtoUnits:(BOOL)dtoFlag{

    if (self.activityType) {
        NSMutableDictionary * newSummaryData = [self buildSummaryDataFromGarminModernData:data dtoUnits:dtoFlag];

        [self mergeSummaryData:newSummaryData];

        self.beginCoordinate = [self buildCoordinateFromGarminModernData:data];
        self.date = [self buildStartDateFromGarminModernData:data];
        
        if( (data[@"numberOfActiveLengths"] != nil && [data[@"numberOfActiveLengths"] isKindOfClass:[NSNumber class]] ) ||
           (data[@"unitOfPoolLength"] != nil && [data[@"unitOfPoolLength"] isKindOfClass:[NSNumber class] ] ) ){
            
            self.garminSwimAlgorithm = true;
        }
    }
}

#pragma mark - Other Services

-(void)parseHealthKitWorkout:(HKWorkout*)workout withSamples:(NSArray*)samples{
#ifdef GC_USE_HEALTHKIT
    switch (workout.workoutActivityType) {
        case HKWorkoutActivityTypeRunning:
            [self changeActivityType:[GCActivityType running]];
            break;
        case HKWorkoutActivityTypeCycling:
            [self changeActivityType:[GCActivityType cycling]];
            break;
        case HKWorkoutActivityTypeSwimming:
            [self changeActivityType:[GCActivityType swimming]];
            break;
        case HKWorkoutActivityTypeHiking:
            [self changeActivityType:[GCActivityType hiking]];
            break;
        case HKWorkoutActivityTypeWalking:
            [self changeActivityType:[GCActivityType walking]];
            break;
        case HKWorkoutActivityTypeElliptical:
            [self changeActivityType:[GCActivityType elliptical]];
            break;
        case HKWorkoutActivityTypeTraditionalStrengthTraining:
        case HKWorkoutActivityTypeFunctionalStrengthTraining:
            [self changeActivityType:[GCActivityType strength_training]];
            break;
        default:
            [self changeActivityType:[GCActivityType other]];
            break;
    }
    
    self.date = workout.startDate;
    self.activityName = [NSString stringWithFormat:@"%@ Workout", self.activityType];
    self.location = @"";
    self.downloadMethod = gcDownloadMethodHealthKit;

    [self updateMetaData:[NSMutableDictionary dictionaryWithObject:[GCActivityMetaValue activityMetaValueForDisplay:workout.sourceRevision.source.name
                                                                                                      andField:GC_META_DEVICE]
                                                       forKey:GC_META_DEVICE]];

    NSMutableDictionary * summary = [NSMutableDictionary dictionary];

    GCActivitySummaryValue * sumVal = nil;
    double distanceMeter = [workout.totalDistance  doubleValueForUnit:[HKUnit meterUnit]];
    double durationSecond = workout.duration;
    [self setSummaryField:gcFieldFlagSumDistance with:[GCNumberWithUnit numberWithUnit:GCUnit.meter andValue:distanceMeter]];
    [self setSummaryField:gcFieldFlagSumDuration with:[GCNumberWithUnit numberWithUnit:GCUnit.second andValue:durationSecond]];
    [self setSummaryField:gcFieldFlagWeightedMeanSpeed with:[GCNumberWithUnit numberWithUnit:GCUnit.mps andValue:distanceMeter/durationSecond]];

    sumVal = [self buildSummaryValue:@"SumDistance" uom:@"meter" fieldFlag:gcFieldFlagSumDistance andValue:distanceMeter];
    summary[sumVal.field] = sumVal;
    sumVal = [self buildSummaryValue:@"SumDuration" uom:@"second" fieldFlag:gcFieldFlagSumDuration andValue:durationSecond];
    summary[sumVal.field] = sumVal;
    sumVal = [self buildSummaryValue:@"WeightedMeanSpeed" uom:@"mps" fieldFlag:gcFieldFlagWeightedMeanSpeed andValue:distanceMeter/durationSecond];
    summary[sumVal.field] = sumVal;
    double sumEnergy = [workout.totalEnergyBurned doubleValueForUnit:[HKUnit kilocalorieUnit]];
    if (sumEnergy != 0.) {
        sumVal = [self buildSummaryValue:@"SumEnergy" uom:@"kilocalorie" fieldFlag:gcFieldFlagNone andValue:sumEnergy];
        summary[sumVal.field] = sumVal;
    }
    [self addPaceIfNecessaryWithSummary:summary];
    [self updateSummaryData:summary];

    GCHealthKitSamplesToPointsParser * parser = [GCHealthKitSamplesToPointsParser parserForSamples:samples forActivityType:self.activityType andSource:workout.sourceRevision];
    self.trackFlags = parser.trackFlags;

    NSMutableArray * points = [NSMutableArray arrayWithArray:[parser.points sortedArrayUsingSelector:@selector(compareTime:)]];

    [self updateSummaryFromTrackpoints:points missingOnly:YES];
    [self saveTrackpoints:points andLaps:nil];

#endif
}

-(void)parseHealthKitSummaryData:(NSDictionary*)data{

    NSString * aType = data[@"activityType"];
    if (aType && [aType isKindOfClass:[NSString class]]) {
        // We need a type to process fields
        [self changeActivityType:[GCActivityType activityTypeForKey:aType]];
        self.downloadMethod = gcDownloadMethodHealthKit;
        self.activityName = @"";
        self.location = @"";

        NSMutableDictionary * sumData = [NSMutableDictionary dictionary];
        for (NSString * fieldkey in data) {
            id obj = data[fieldkey];
            NSString * str = nil;
            GCNumberWithUnit * nu = nil;
            NSDate * da = nil;

            if ([obj isKindOfClass:[NSString class]]) {
                str = obj;
            }else if([obj isKindOfClass:[GCNumberWithUnit class]]){
                nu = obj;
            }else if ([obj isKindOfClass:[NSDate class]]){
                da = obj;
            }

            if ([fieldkey isEqualToString:@"activityType"] && str) {
                [self changeActivityType:[GCActivityType activityTypeForKey:str]];
            }else if ([fieldkey isEqualToString:@"BeginTimestamp"] && da){
                self.date = da;
            }else if (nu) {
                GCField * field = [GCField fieldForKey:fieldkey andActivityType:self.activityType];
                gcFieldFlag flag = field.fieldFlag;
                if (flag != gcFieldFlagNone) {
                    [self setSummaryField:flag with:nu];
                }
                GCActivitySummaryValue * val = [self buildSummaryValue:fieldkey
                                                                   uom:nu.unit.key
                                                             fieldFlag:flag
                                                              andValue:nu.value];
                sumData[ field ] = val;
            }
        }
        [self updateSummaryData:sumData];
    }
}


-(void)parseStravaJson:(NSDictionary*)data{
    NSDictionary * defs = @{
                            @"distance":            @[ @"SumDistance",          @(gcFieldFlagSumDistance),              @"meter"],
                            @"moving_time":         @[ @"SumMovingDuration",    @"",                                    @"second"],
                            @"elapsed_time":        @[ @"SumDuration",          @(gcFieldFlagSumDuration),              @"second"],
                            @"total_elevation_gain":@[ @"GainElevation",        @"",                                    @"meter"],
                            @"average_speed":       @[ @"WeightedMeanSpeed",    @(gcFieldFlagWeightedMeanSpeed),        @"mps"],
                            @"max_speed":           @[ @"MaxSpeed",             @"",                                    @"mps"],
                            @"average_watts":       @[ @"WeightedMeanPower",    @(gcFieldFlagPower),                    @"watt"],
                            @"kilojoules":          @[ @"SumTotalWork",         @"",                                    @"kilojoule"],
                            @"average_heartrate":   @[ @"WeightedMeanHeartRate",@(gcFieldFlagWeightedMeanHeartRate),    @"bpm"],
                            @"max_heartrate":       @[ @"MaxHeartRate",         @"",                                    @"bpm"],
                            @"calories":            @[ @"SumEnergy",            @"",                                    @"kilocalorie"],
                            @"average_temp":        @[ @"WeightedMeanAirTemperature",@"",                               @"celsius"],

                            //@"start_date":          @[ @"BeginTimeStamp",       @"",                                    @"time"],
                            //@"start_latlng":        @[ @[@"BeginLatitude",@"BeginLongitude"],@"vector", @"dd"],
                            //@"end_latlng":          @[ @[@"EndLatitude",  @"EndLongitude"],  @"vector", @"dd"],

                            @"average_cadence":     @{ GC_TYPE_RUNNING: @[ @"WeightedMeanRunCadence", @"stepsPerMinute"],
                                                       GC_TYPE_CYCLING: @[ @"WeightedMeanBikeCadence", @"rpm"] }

                            };

    GCService * service = [GCService service:gcServiceStrava];

    self.activityId = [service activityIdFromServiceId:[data[@"id"] stringValue]];
    GCActivityType * atype = [GCActivityType activityTypeForStravaType:data[@"type"]];
    [self changeActivityType:atype];
    self.activityName = data[@"name"];
    self.location = @"";
    if (self.activityType == nil) {
        [self changeActivityType:[GCActivityType other]];
    }
    self.downloadMethod = gcDownloadMethodStrava;
    if (self.metaData==nil) {
        [self updateMetaData:[NSMutableDictionary dictionary]];
    }
    if (self.activityId && self.activityType) {
        NSMutableDictionary * newSummaryData = [NSMutableDictionary dictionaryWithCapacity:data.count];
        [self parseData:data into:newSummaryData usingDefs:defs];

        // few extra derived
        [self addPaceIfNecessaryWithSummary:newSummaryData];
        [self mergeSummaryData:newSummaryData];

        NSArray * latlong = data[@"start_latlng"];
        if ([latlong isKindOfClass:[NSArray class]] && latlong.count == 2) {
            self.beginCoordinate = CLLocationCoordinate2DMake([latlong[0] doubleValue], [latlong[1] doubleValue]);
        }
        NSString * startdate = data[@"start_date"];
        if(startdate) {
            self.date = [NSDate dateForStravaTimeString:startdate];
            if (!self.date) {
                RZLog(RZLogError, @"%@: Invalid date %@", self.activityId, startdate);
            }
        }else{
            RZLog(RZLogError, @"%@: Invalid date %@", self.activityId, startdate);
        }
        NSString * externalId = data[@"external_id"];
        if([externalId isKindOfClass:[NSString class]] && [externalId hasPrefix:@"garmin_push_"]){
            NSString * garminId = [externalId substringFromIndex:[@"garmin_push_" length]];
            self.externalServiceActivityId = [[GCService service:gcServiceGarmin] activityIdFromServiceId:garminId];
        }
    }
}

#pragma mark - Update from other activity or part of activity

-(BOOL)updateTrackpointsFromActivity:(GCActivity*)other newOnly:(BOOL)newOnly verbose:(BOOL)verbose{
    BOOL rv = false;
        
    if( ! self.trackpointsReadyNoLoad && other.trackpointsReadyNoLoad){
        // Special case: other has trackpoint self doesnt, just use
        [self updateWithTrackpoints:other.trackpoints andLaps:other.laps];
        
        rv = true;
    }else if( self.trackpointsReadyNoLoad && other.trackpointsReadyNoLoad ){
        // Only bother if both have trackpoint
        NSArray<GCTrackPoint*> * trackpoints = self.trackpoints;
        NSArray<GCTrackPoint*> * otherTrackpoints = other.trackpoints;
        
        if( trackpoints.count > 0 &&
           otherTrackpoints.count > 0 &&
           [trackpoints[0] isMemberOfClass:[GCTrackPoint class]] &&
           [otherTrackpoints[0] isMemberOfClass:[GCTrackPoint class]]){
            // Don't handle swim points
            
            NSMutableArray<GCField*>*fields = [NSMutableArray array];
            NSArray<GCField*>*otherFields = other.availableTrackFields;
            
            // only update if new fields
            for (GCField * otherField in otherFields) {
                if( ! [self hasTrackForField:otherField]){
                    [fields addObject:otherField];
                    rv = true;
                }
            }
            if( rv ){
                NSUInteger otherIndex = 0;
                
                GCTrackPoint * last = otherTrackpoints[otherIndex];
                
                for (GCTrackPoint * one in trackpoints) {
                    while( last && [last timeIntervalSince:one] < 0.0){
                        otherIndex++;
                        if (otherIndex < otherTrackpoints.count) {
                            last = otherTrackpoints[otherIndex];
                        }else{
                            last = nil;
                        }
                    }
                    if( last ){
                        [one updateInActivity:self fromTrackpoint:last fromActivity:other forFields:fields];
                        self.trackFlags |= one.trackFlags;
                    }
                }
            }
            if( ! self.laps && other.laps){
                [self updateWithTrackpoints:self.trackpoints andLaps:other.laps];
            }
        }
    }
    return rv;
}

-(BOOL)updateSummaryDataFromActivity:(GCActivity*)other newOnly:(BOOL)newOnly verbose:(BOOL)verbose{
    BOOL rv = false;
    
    // no metaData in current activity, just take the other one as is
    if( self.metaData == nil && other.metaData != nil){
        [self updateMetaData:[NSDictionary dictionaryWithDictionary:other.metaData]];
        
        FMDatabase * db = self.db;
        [db beginTransaction];
        for (NSString * field in self.metaData) {
            GCActivityMetaValue * data = self.metaData[field];
            if( db ){
                [data saveToDb:db forActivityId:self.activityId];
            }
        }
        [db commit];
        rv = true;

    }else{
        if (self.metaData) {
            NSMutableDictionary * newMetaData = nil;
            if( ! newOnly ){
                for (NSString * field in self.metaData) {
                    GCActivityMetaValue * thisVal  = (self.metaData)[field];
                    GCActivityMetaValue * otherVal = (other.metaData)[field];
                    if (otherVal && ! [otherVal isEqualToValue:thisVal]) {
                        if (!newMetaData) {
                            newMetaData = [NSMutableDictionary dictionaryWithDictionary:self.metaData];
                        }
                        [self.settings.updateRecord recordFor:self changedMeta:thisVal to:otherVal];
                        [newMetaData setValue:otherVal forKey:field];
                        FMDatabase * db = self.db;
                        if( db ){
                            [db beginTransaction];
                            [otherVal updateDb:db forActivityId:self.activityId];
                            [db commit];
                        }
                        rv = true;
                    }
                }
            }
            if( other.metaData){
                for( NSString * field in other.metaData){
                    // new field
                    if( self.metaData[field] == nil){
                        GCActivityMetaValue * otherVal = (other.metaData)[field];
                        if( !newMetaData){
                            newMetaData = [NSMutableDictionary dictionaryWithDictionary:self.metaData];
                        }
                        [self.settings.updateRecord recordFor:self newMeta:otherVal];

                        [newMetaData setValue:otherVal forKey:field];
                        FMDatabase * db = self.db;
                        if( db ){
                            [db beginTransaction];
                            [otherVal updateDb:db forActivityId:self.activityId];
                            [db commit];
                        }
                        rv = true;
                    }
                }
            }
            if (newMetaData) {
                [self updateMetaData:newMetaData];
            }
        }
    }
    if (self.summaryData) {
        NSMutableDictionary<GCField*,GCActivitySummaryValue*> * newSummaryData = nil;
        if( ! newOnly ){
            for (GCField * field in self.summaryData) {
                GCActivitySummaryValue * thisVal = self.summaryData[field];
                GCActivitySummaryValue * otherVal = other.summaryData[field];

                // Only change if formatted value changes, to avoid issue with just low precision diffs
                if (otherVal && (! [otherVal isEqualToValue:thisVal]) && (![otherVal.formattedValue isEqualToString:thisVal.formattedValue])) {
                    if( !field.isZeroValid && otherVal.value == 0.0){
                        // Don't put back to 0.0 value that were picked up
                        continue;
                    }
                    if (!newSummaryData) {
                        newSummaryData = [NSMutableDictionary dictionaryWithDictionary:self.summaryData];
                    }
                    [self.settings.updateRecord recordFor:self changedValue:thisVal to:otherVal];
                    newSummaryData[field] = otherVal;
                    
                    FMDatabase * db = self.db;
                    if( db ){
                        [db beginTransaction];
                        [otherVal updateDb:db forActivityId:self.activityId];
                        [db commit];
                    }
                    rv = true;
                }
            }
        }
        for (GCField * field in other.summaryData) {
            GCActivitySummaryValue * thisVal = self.summaryData[field];
            GCActivitySummaryValue * otherVal = other.summaryData[field];
            // Update if missing or if old value is 0.0
            if ((thisVal==nil && otherVal.value != 0.0 ) || ( thisVal.value == 0.0 && otherVal.value != 0.0) ) {
                if (!newSummaryData) {
                    newSummaryData = [NSMutableDictionary dictionaryWithDictionary:self.summaryData];
                }
                [self.settings.updateRecord recordFor:self newValue:otherVal];
                newSummaryData[field] = otherVal;
                
                FMDatabase * db = self.db;
                if( db ){
                    [db beginTransaction];
                    [otherVal updateDb:db forActivityId:self.activityId];
                    [db commit];
                }
                rv = true;
            }
        }
        if (newSummaryData) {
            [self updateSummaryData:newSummaryData];
        }
    }
    
    if( self.garminSwimAlgorithm != other.garminSwimAlgorithm ){
        if( verbose){
            RZLog(RZLogInfo, @"%@ Change swimAlgoritm=%@", self, other.garminSwimAlgorithm ? @"on" : @"off");
        }

        self.garminSwimAlgorithm = other.garminSwimAlgorithm;
        NSString * query = [NSString stringWithFormat:@"UPDATE gc_activities SET %@=? WHERE activityId=?", @"garminSwimAlgorithm"];
        RZEXECUTEUPDATE(self.db, query, @(self.garminSwimAlgorithm), self.activityId);
    }
    
    if( ! newOnly ){
        for (GCField * field in @[ [GCField fieldForFlag:gcFieldFlagSumDistance andActivityType:self.activityType],
                                   [GCField fieldForFlag:gcFieldFlagSumDuration andActivityType:self.activityType],
                                   [GCField fieldForFlag:gcFieldFlagWeightedMeanSpeed andActivityType:self.activityType],
                                   [GCField fieldForFlag:gcFieldFlagWeightedMeanHeartRate andActivityType:self.activityType],
        ]) {
            GCNumberWithUnit * otherNu = [other numberWithUnitForField:field];
            // Ignore zero values
            if( otherNu.value != 0.0 && [self setNumberWithUnit:otherNu forField:field] ){
                rv = true;
                GCNumberWithUnit * save = [[self numberWithUnitForField:field] convertToUnit:[self storeUnitForField:field]];
                FMDatabase * db = self.db;
                if( db ){
                    NSString * fieldKey = field.key;
                    if( field.fieldFlag == gcFieldFlagWeightedMeanSpeed){
                        fieldKey = @"WeightedMeanSpeed";// avoid pace
                    }
                    NSString * query = [NSString stringWithFormat:@"UPDATE gc_activities SET %@=? WHERE activityId=?", fieldKey];
                    RZEXECUTEUPDATE(db, query, @(save.value), self.activityId);
                }
            }
        }
    }
    
    return rv;
}

-(BOOL)updateWithActivity:(GCActivity*)other newOnly:(BOOL)newOnly verbose:(BOOL)verbose{

    BOOL rv = false;

    // Special Case were some field should always be imported (like name event etc)
    BOOL connectstatsFromGarmin = self.service.service == gcServiceConnectStats && other.service.service == gcServiceGarmin;
    
    if( [self markCompleted:gcServicePhaseSummary for:other.service.service] ){
        RZLog(RZLogInfo, @"%@: Already completed %@/summary", self, other.service);
    }

    if( ! newOnly){
        GCActivityType * aType = other.activityTypeDetail;
        if (![aType isEqualToActivityType:self.activityTypeDetail]) {
            [self.settings.updateRecord recordFor:self changedAttribute:@"activityType" from:self.activityTypeDetail.description to:aType.description];
            rv = true;
            [self changeActivityType:aType];
            FMDatabase * db = self.db;
            [db beginTransaction];
            [db executeUpdate:@"UPDATE gc_activities SET activityType=? WHERE activityId = ?", self.activityType, self.activityId];
            [db commit];
        }
    }

    NSString * aName = other.activityName;
    if( ! newOnly || connectstatsFromGarmin){
        if (aName.length > 0 && ![aName isEqualToString:self.activityName]) {
            [self.settings.updateRecord recordFor:self changedAttribute:@"activityName" from:self.activityName to:aName];
            rv = true;
            self.activityName = aName;
            FMDatabase * db = self.db;
            [db beginTransaction];
            [db executeUpdate:@"UPDATE gc_activities SET activityName=? WHERE activityId = ?", self.activityName, self.activityId];
            [db commit];
        }
    }
    
    if( [self updateSummaryDataFromActivity:other newOnly:newOnly verbose:verbose] ){
        rv = true;
    }
    
    if( [self updateTrackpointsFromActivity:other newOnly:newOnly verbose:verbose] ){
        rv = true;
    }
    return rv;
}

-(BOOL)updateMissingFromActivity:(GCActivity*)other{
    return [self updateWithActivity:other newOnly:true verbose:false];
}
-(BOOL)updateWithActivity:(GCActivity*)other{
    return [self updateWithActivity:other newOnly:false verbose:true];
}
-(BOOL)updateSummaryDataFromActivity:(GCActivity*)other{
    return [self updateSummaryDataFromActivity:other newOnly:false verbose:true];
    
}
-(BOOL)updateTrackpointsFromActivity:(GCActivity*)other{
    return [self updateTrackpointsFromActivity:other newOnly:false verbose:true];
    
}

-(void)updateActivityFieldsFromSummary{
    for (GCField * field in @[ [GCField fieldForFlag:gcFieldFlagSumDistance andActivityType:self.activityType],
                               [GCField fieldForFlag:gcFieldFlagSumDuration andActivityType:self.activityType],
                               [GCField fieldForFlag:gcFieldFlagWeightedMeanSpeed andActivityType:self.activityType],
                               [GCField fieldForFlag:gcFieldFlagWeightedMeanHeartRate andActivityType:self.activityType],
    ]) {
        if( self.summaryData[field] ){
            [self setSummaryField:field.fieldFlag with:self.summaryData[field].numberWithUnit];
        }
    }
}

-(BOOL)updateSummaryFromTrackpoints:(NSArray<GCTrackPoint*>*)trackpoints missingOnly:(BOOL)missingOnly{
    BOOL rv = false;
    NSDictionary<GCField*,GCActivitySummaryValue*> * fromPoints = [self buildSummaryFromTrackpoints:trackpoints];
    
    NSMutableDictionary<GCField*,GCActivitySummaryValue*>* newSum = [NSMutableDictionary dictionaryWithDictionary:self.summaryData];
    
    for (GCField * field in fromPoints) {
        if( newSum[field] == nil){
            newSum[field] = fromPoints[field];
            rv = true;
        }
        else if( !missingOnly ){
            GCActivitySummaryValue * newVal = fromPoints[field];
            GCActivitySummaryValue * oldVal = newSum[field];
            if( ![oldVal isEqualToValue:newVal]){
                newSum[field] = newVal;
                rv = true;
            }
        }
    }
    
    [self updateSummaryData:newSum];
    
    if( self.date == nil && trackpoints.count > 0){
        self.date = trackpoints.firstObject.time;
    }
    [self updateActivityFieldsFromSummary];
    return rv;
}

-(NSDictionary<GCField*,GCActivitySummaryValue*>*)buildSummaryFromTrackpoints:(NSArray<GCTrackPoint*>*)trackpoints{

    NSMutableDictionary<GCField*,GCNumberWithUnit*> * results = [NSMutableDictionary dictionary];
    
    NSArray<GCField*>*fields = self.availableTrackFields;
    
    double totalElapsed = 0.0;
    double totalDistance = 0.0;
    
    GCTrackPoint * point = nil;
    for (GCTrackPoint * next in trackpoints) {
        @autoreleasepool {
            if (point) {
                NSTimeInterval elapsed = [next timeIntervalSince:point];
                totalElapsed += elapsed;
                totalDistance += [next distanceMetersFrom:point];
                for (GCField * field in fields) {
                    
                    GCNumberWithUnit * num = [point numberWithUnitForField:field inActivity:self];
                    if( num ){
                        GCNumberWithUnit * current = results[field];
                        
                        if (!current) {
                            current = num;
                        }else{
                            current.value *= (totalElapsed-elapsed)/totalElapsed;
                            current = [current addNumberWithUnit:num weight:elapsed/totalElapsed];
                        }
                        if( current ){
                            results[field] = current;
                            if( field.isWeightedAverage){
                                for (GCField * secondary in @[ field.correspondingMaxField, field.correspondingMinField ]) {
                                    GCNumberWithUnit * secondaryCurrent = results[secondary];
                                    if( ! secondaryCurrent ){
                                        secondaryCurrent = num;
                                    }else{
                                        if( secondary.isMax ){
                                            secondaryCurrent = [secondaryCurrent maxNumberWithUnit:num];
                                        }else if ( secondary.isMin ){
                                            secondaryCurrent = [secondaryCurrent nonZeroMinNumberWithUnit:num];
                                        }
                                    }
                                    if (secondaryCurrent) {
                                        results[secondary] = secondaryCurrent;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        point = next;
    }
    NSMutableDictionary<GCField*,GCActivitySummaryValue*> * newSum = [NSMutableDictionary dictionaryWithDictionary:self.summaryData];
    
    GCField * sumDuration = [GCField fieldForFlag:gcFieldFlagSumDuration andActivityType:self.activityType];
    GCField * sumDistance = [GCField fieldForFlag:gcFieldFlagSumDistance andActivityType:self.activityType];
    
    results[sumDuration] = [[GCNumberWithUnit numberWithUnit:GCUnit.second andValue:totalElapsed] convertToUnit:[self displayUnitForField:sumDuration]];
    results[sumDistance] = [[GCNumberWithUnit numberWithUnit:GCUnit.meter andValue:totalDistance] convertToUnit:[self displayUnitForField:sumDistance]];
    
    for (GCField *field in results) {
        GCNumberWithUnit * num = results[field];
        if( num.value == 0.0 && !field.isZeroValid){
            continue;
        }
        GCActivitySummaryValue * val = [self buildSummaryValue:field.key uom:num.unit.key fieldFlag:field.fieldFlag andValue:num.value];
        newSum[field] = val;
    }
    [self addPaceIfNecessaryWithSummary:newSum];
    
    return newSum;
}

#pragma mark -

+(NSString*)duplicateDescription:(gcDuplicate)dup{
    switch (dup) {
        case gcDuplicateTimeOverlapping:
            return @"Time Overlapping";
        case gcDuplicateSynchronizedService:
            return @"Synchronized Service";
        case gcDuplicateNotMatching:
            return @"Not a Duplicate";
    }
    return @"Not a Duplicate";
}

-(gcDuplicate)testForDuplicate:(GCActivity*)other{
    gcDuplicate activitiesAreDuplicate = gcDuplicateNotMatching;
    
    // Never match health kit activities
    if( self.service.service == gcServiceHealthKit || other.service.service == gcServiceHealthKit ){
        return gcDuplicateNotMatching;
    }
    
    // if child activity from multi sport overlap test would succeed but not a duplicate
    if( self.childIds && [self.childIds isKindOfClass:[NSArray class]]){
        if( [self.childIds containsObject:other.activityId] ){
            return gcDuplicateNotMatching;
        }
    }
    
    if( other.childIds && [other.childIds isKindOfClass:[NSArray class]]){
        if( [other.childIds containsObject:self.activityId] ){
            return gcDuplicateNotMatching;
        }
    }
    
    if( self.parentId ){
        if( [self.parentId isEqualToString:other.activityId] ){
            return gcDuplicateNotMatching;
        }
    }
    
    if( other.parentId ){
        if( [self.activityId isEqualToString:other.parentId] ){
            return gcDuplicateNotMatching;
        }
    }
    
    // check if from same system (strava/garmin)
    if( (self.externalServiceActivityId && ([self.externalServiceActivityId isEqualToString:other.activityId]))||
       (other.externalServiceActivityId && ([other.externalServiceActivityId isEqualToString:self.activityId]))){
        activitiesAreDuplicate = gcDuplicateSynchronizedService;
    }
    
    // if not match, check for time overlap
    if( activitiesAreDuplicate == gcDuplicateNotMatching ){
        //Last:   date                date+sumDuration
        //        |--------------------|
        //          |--------------------|
        //One:      date                 Date+sumDuration
        if(  [other.endTime timeIntervalSinceDate:other.startTime] > 60.0){
            NSTimeInterval overlap =
            MIN(other.endTime.timeIntervalSinceReferenceDate, self.endTime.timeIntervalSinceReferenceDate)-
            MAX(other.startTime.timeIntervalSinceReferenceDate, self.startTime.timeIntervalSinceReferenceDate);
            
            //Last:   date           date+sumDuration
            //        |--------------|
            //          |--------------------|
            //One:      date                 Date+sumDuration
            // Use min duration otherwise ratio maybe too small even if full overlap
            // but second activity is much longer
            
            double ratio = (double)overlap / MIN([self.endTime timeIntervalSinceDate:self.startTime],[other.endTime timeIntervalSinceDate:other.startTime]);
            
            if( overlap > 0.0 &&  ratio > 0.90 ){
                activitiesAreDuplicate = gcDuplicateTimeOverlapping;
            }
        }
    }
    return activitiesAreDuplicate;
}



@end
