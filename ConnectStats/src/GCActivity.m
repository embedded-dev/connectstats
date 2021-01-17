//  MIT Licence
//
//  Created on 09/09/2012.
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

#import "GCActivity.h"
#import "GCAppGlobal.h"
#import "GCTrackPoint.h"
#import "GCFields.h"
#import "GCLap.h"
#import "GCTrackPoint+Swim.h"
#import "GCActivitySummaryValue.h"
#import "GCActivityMetaValue.h"
#import "GCActivityCalculatedValue.h"
#import "GCFieldsCalculated.h"
#import "GCWeather.h"
#import "GCLapCompound.h"
#import "GCActivity+Import.h"
#import "GCActivity+Database.h"
#import "GCWebConnect+Requests.h"
#import "GCService.h"
#import "GCActivity+CachedTracks.h"
#import "GCTrackPointExtraIndex.h"
#import "GCActivity+Fields.h"
#import "GCActivitiesOrganizer.h"
#import "GCDerivedOrganizer.h"

NSString * GC_PARENT_ID = @"__ParentId__";
NSString * GC_CHILD_IDS = @"__ChildIds__";
NSString * GC_EXTERNAL_ID  = @"__ExternalId__";
NSString * GC_IGNORE_SKIP_ALWAYS =  @"__IGNORE_SKIP_ALWAYS__";

NSString * GC_TRACKPOINTS_RECORDED = @"__TrackPointsRecorded__";
NSString * GC_TRACKPOINTS_RESAMPLED = @"__TrackPointsResampled__";
NSString * GC_TRACKPOINTS_MATCHED = @"__TrackPointsMatched__";

NSString * kGCActivityNotifyDownloadDone = @"kGCActivityNotifyDownloadDone";
NSString * kGCActivityNotifyTrackpointReady = @"kGCActivityNotifyTrackpointReady";

@interface GCActivity ()

@property (nonatomic,retain) NSString * activityType;// DEPRECATED_MSG_ATTRIBUTE("use GCActivityType.");
@property (nonatomic,retain) GCActivityType * activityTypeDetail;// DEPRECATED_MSG_ATTRIBUTE("use detail of GCActivityType.");

@property (nonatomic,retain) FMDatabase * useDb;
@property (nonatomic,retain) FMDatabase * useTrackDb;

@property (nonatomic,retain) NSArray * trackpointsCache;
@property (nonatomic,retain) NSArray * lapsCache;

@property (nonatomic,retain) NSMutableDictionary<NSString*,NSArray<GCTrackPoint*>*>* calculatedTrackPoints;
@property (nonatomic,retain) NSMutableDictionary<NSString*,NSArray*> * calculatedLaps;

@property (nonatomic,retain) NSDictionary<NSString*,GCActivityMetaValue*> * metaData;
@property (nonatomic,retain) NSDictionary<GCField*,GCActivitySummaryValue*> * summaryData;
@property (nonatomic,retain) NSDictionary<GCField*,GCActivityCalculatedValue*> * calculatedFields;
@property (nonatomic,retain) NSDictionary<GCField*,GCTrackPointExtraIndex*> * cachedExtraTracksIndexes;


@property (nonatomic,assign) double sumDistance;
@property (nonatomic,assign) double sumDuration;
@property (nonatomic,assign) double weightedMeanHeartRate;
@property (nonatomic,assign) double weightedMeanSpeed;


@end

@implementation GCActivity

-(instancetype)init{
    return [super init];
}

-(GCActivity*)initWithId:(NSString *)aId{
    self = [super init];
    if (self) {
        self.activityId = aId;
    }
    return self;
}

-(GCActivity*)initWithResultSet:(FMResultSet*)res{
    self = [super init];
    if (self) {
        self.activityId = [res stringForColumn:@"activityId"];
        [self loadFromResultSet:res];
        self.settings = [GCActivitySettings defaultsFor:self];
    }
    return self;
}


-(void)dealloc{

    [[GCAppGlobal web] detach:self];
    [_useDb release];
    [_useTrackDb release];
    [_activityId release];
    [_summaryData release];
    [_trackpointsCache release];
    [_calculatedTrackPoints release];
    [_lapsCache release];
    [_metaData release];

    [_date release];

    [_activityType release];
    [_activityName release];

    [_location release];

    [_activityTypeDetail release];
    [_calculatedFields release];
    [_calculatedLaps release];
    [_calculatedLapName release];

    [_weather release];

    [_cachedCalculatedTracks release];
    [_cachedExtraTracksIndexes release];

    [_settings release];

    [super dealloc];
}

-(NSString*)externalActivityId{
    return [self.service serviceIdFromActivityId:self.activityId];
}

-(GCService*)service{
    return [GCService serviceForActivityId:self.activityId];
}

-(NSString*)description{
    return [NSString stringWithFormat:@"<%@ %@:%@>", NSStringFromClass([self class]),_activityType,  _activityId];
}

-(NSString*)debugDescription{
    NSMutableArray * summary = [NSMutableArray arrayWithArray:@[  self.activityId, [self.date YYYYdashMMdashDD]]];
    
    for (NSNumber * flag in @[ @(gcFieldFlagSumDuration), @(gcFieldFlagSumDistance)]) {
        GCField * field = [GCField fieldForFlag:flag.integerValue andActivityType:self.activityType];
        if( [self hasField:field] ){
            [summary addObject:[[self numberWithUnitForField:field] description]];
        }
    }
    
    return [NSString stringWithFormat:@"<%@ %@:%@>", NSStringFromClass([self class]),self.activityType,[summary componentsJoinedByString:@" "]];
}

-(void)notifyCallBack:(id)theParent info:(RZDependencyInfo *)theInfo{
    if ([theInfo.stringInfo isEqualToString:NOTIFY_END] || [theInfo.stringInfo isEqualToString:NOTIFY_ERROR]) {
        _downloadRequested=false;
    }
}

-(void)addEntriesToMetaData:(NSDictionary<NSString*,GCActivityMetaValue*> *)dict{
    if (!self.metaData) {
        self.metaData = dict;
    }else{
        self.metaData = [self.metaData dictionaryByAddingEntriesFromDictionary:dict];
    }
}
-(void)addEntriesToCalculatedFields:(NSDictionary<GCField*,GCActivityCalculatedValue*> *)dict{
    if (!self.calculatedFields) {
        self.calculatedFields = dict;
    }else{
        self.calculatedFields = [self.calculatedFields dictionaryByAddingEntriesFromDictionary:dict];
    }
}

-(BOOL)isEqualToActivity:(GCActivity*)other{

    NSString * aType = other.activityType;
    if (![aType isEqualToString:self.activityType]) {
        return false;
    }
    if (![other.activityName isEqualToString:self.activityName]) {
        return false;
    }
    if (fabs([other.date timeIntervalSinceDate:self.date])>=1.e-5) {
        return false;
    }
    NSArray * fields = self.availableTrackFields;
    NSArray * otherFields = other.availableTrackFields;

    if (fields.count != otherFields.count) {
        return false;
    }
    for (GCField * one in fields) {
        GCNumberWithUnit * nu1 = [self numberWithUnitForField:one];
        GCNumberWithUnit * nu2 = [self numberWithUnitForField:one];
        if (nu1 == nil || nu2 == nil) {
            return false;
        }
        if ([nu1 compare:nu2 withTolerance:1.e-8]!=NSOrderedSame ){
            return false;
        }
    }
    if (fabs(self.sumDuration - other.sumDuration) > 1.e-8 || fabs(self.sumDistance-other.sumDistance)> 1.e-8) {
        return false;
    }
    if (self.metaData) {
        for (NSString * field in self.metaData) {
            GCActivityMetaValue * thisVal  = (self.metaData)[field];
            GCActivityMetaValue * otherVal = (other.metaData)[field];
            if (otherVal && ! [otherVal isEqualToValue:thisVal]) {
                return false;
            }
        }
    }else if(other.metaData){
        return false;
    }
    if (self.summaryData) {
        for (GCField * field in self.summaryData) {
            GCActivitySummaryValue * thisVal = self.summaryData[field];
            GCActivitySummaryValue * otherVal = other.summaryData[field];
            if (otherVal && ! [otherVal isEqualToValue:thisVal]) {
                return false;
            }
        }
    }else if (other.summaryData){
        return false;
    }

    return true;

}

#pragma mark - Primary Field Access

/**
 Return summary value for field. Mostly for internal use
 @return summary value or nil
 */
/*
-(GCActivitySummaryValue*)summaryValueForField:(GCField*)field{
    [self loadSummaryData];
    GCActivitySummaryValue * val = summaryData[field.key];
    if (!val) {
        val = self.calculatedFields[field.key];
    }
    return val;
}
 */


-(GCUnit*)speedDisplayUnit{
    return self.activityTypeDetail.preferredSpeedDisplayUnit ?: [[GCUnit kph] unitForGlobalSystem];
}

-(GCUnit*)distanceDisplayUnit{
    return [[GCUnit kilometer] unitForGlobalSystem];
}

-(BOOL)changeActivityType:(GCActivityType*)newActivityType{
    BOOL changed = false;
    if( newActivityType && ( !self.activityType || ![newActivityType isEqualToActivityType:self.activityTypeDetail] ) ){
        NSString * newSubRoot = newActivityType.primaryActivityType.key;
        changed = true;
        if( self.activityType && ![newSubRoot isEqualToString:self.activityType] ){
            self.activityType = newSubRoot;
            NSMutableDictionary * newSummary = [NSMutableDictionary dictionary];
            for (GCField * field in self.summaryData) {
                GCActivitySummaryValue * sumValue = self.summaryData[field];
                GCField * newField = [field correspondingFieldForActivityType:newSubRoot];
                newSummary[newField] = sumValue;
            }
            // We are not changing any values, so should not need to change the directly stored data like speed, etc
            self.summaryData = [NSDictionary dictionaryWithDictionary:newSummary];
        }else{
            self.activityType = newSubRoot;
        }
        self.activityTypeDetail = newActivityType;
    }
    return changed;
}

/**
 This method should be the primary access method to get value for any field
 Note that the activityType in field will be ignored, if it does not match
 activityType of the activity but the field exist it will return the value
 @param GCField*field the field
 @return GCNumberWithUnit for the field or nil if not available.
 */
-(GCNumberWithUnit*)numberWithUnitForField:(GCField*)field{
    GCNumberWithUnit * rv = nil;
    gcFieldFlag flag = field.fieldFlag;
    switch (flag) {
        case gcFieldFlagSumDuration:
            rv = [GCNumberWithUnit numberWithUnitName:STOREUNIT_ELAPSED andValue:self.sumDuration];
            break;
        case gcFieldFlagSumDistance:
            if( RZTestOption(self.flags, flag) ){
                rv = [[GCNumberWithUnit numberWithUnitName:STOREUNIT_DISTANCE andValue:self.sumDistance] convertToUnit:self.distanceDisplayUnit];
            }else{
                rv = nil;
            }
            break;
        case gcFieldFlagWeightedMeanSpeed:
            if( RZTestOption(self.flags, flag) ){
                rv = [[GCNumberWithUnit numberWithUnitName:STOREUNIT_SPEED andValue:self.weightedMeanSpeed] convertToUnit:self.speedDisplayUnit];
                // Guard against inf speed or pace
                if( isinf(rv.value)){
                    rv = nil;
                }
            }else{
                rv = nil;
            }
            break;
        case gcFieldFlagWeightedMeanHeartRate:
            if( RZTestOption(self.flags, flag) ){
                if( self.weightedMeanHeartRate == 0){
                    rv = nil;
                }else{
                    rv = [GCNumberWithUnit numberWithUnitName:STOREUNIT_HEARTRATE andValue:self.weightedMeanHeartRate];
                }
            }else{
                rv = nil;
            }
            break;

        default:
        {
            [self loadSummaryData];
            GCActivitySummaryValue * val = self.summaryData[field];
            if (!val) {
                val = self.calculatedFields[field];
            }
            if( val == nil && [field.activityType isEqualToString:GC_TYPE_ALL]){
                GCField * typedField = [field correspondingFieldForActivityType:self.activityType];
                val = self.summaryData[ typedField ];
            }
            rv = val.numberWithUnit;
        }
    }
    return rv;
}

-(BOOL)setNumberWithUnit:(GCNumberWithUnit*)nu forField:(GCField*)field{
    BOOL rv = false;
    const double eps = 1.0e-8;
    gcFieldFlag which = field.fieldFlag;
    
    switch (which) {
        case gcFieldFlagWeightedMeanSpeed:
        case gcFieldFlagWeightedMeanHeartRate:
        case gcFieldFlagSumDuration:
        case gcFieldFlagSumDistance:
            rv = [self setSummaryField:field.fieldFlag with:nu];
        default:
            break;
    }
    if( [field isCalculatedField] ){
        GCActivitySummaryValue * sumVal = self.calculatedFields[field];
        GCActivitySummaryValue * newVal = nil;
        if( !sumVal || [nu compare:sumVal.numberWithUnit withTolerance:eps] != NSOrderedSame){
            newVal = [GCActivitySummaryValue activitySummaryValueForField:field.key value:nu];
            NSMutableDictionary * newDict = [NSMutableDictionary dictionaryWithDictionary:self.summaryData];
            newDict[field] = newVal;
            self.calculatedFields = newDict;
            rv = true;
        }
    }else{
        GCActivitySummaryValue * sumVal = self.summaryData[field];
        GCActivitySummaryValue * newVal = nil;
        if( !sumVal || [nu compare:sumVal.numberWithUnit withTolerance:eps] != NSOrderedSame){
            newVal = [GCActivitySummaryValue activitySummaryValueForField:field.key value:nu];
            NSMutableDictionary * newDict = [NSMutableDictionary dictionaryWithDictionary:self.summaryData];
            newDict[field] = newVal;
            self.summaryData = newDict;
            rv = true;
        }
    }
    return rv;
}
-(BOOL)setSummaryField:(gcFieldFlag)which with:(GCNumberWithUnit*)nu{
    BOOL rv = false;
    const double eps = 1.0e-8;

    switch (which) {
        case gcFieldFlagSumDistance:
        {
            double val = [nu convertToUnitName:STOREUNIT_DISTANCE].value;
            rv = fabs(self.sumDistance - val) > eps;
            self.sumDistance = val;
            self.flags |= gcFieldFlagSumDistance;
            break;
        }
        case gcFieldFlagSumDuration:
        {
            double val = [nu convertToUnitName:STOREUNIT_ELAPSED].value;
            rv = fabs( self.sumDuration - val) > eps;
            self.sumDuration = val;
            self.flags |= gcFieldFlagSumDuration;
            break;
        }
        case gcFieldFlagWeightedMeanHeartRate:
        {
            rv = fabs( self.weightedMeanHeartRate - nu.value) > eps;
            self.weightedMeanHeartRate = nu.value;
            self.flags |= gcFieldFlagWeightedMeanHeartRate;
            break;
        }
        case gcFieldFlagWeightedMeanSpeed:
        {
            double val = [nu convertToUnitName:STOREUNIT_SPEED].value;
            rv = fabs( self.weightedMeanSpeed - val) > eps;
            self.weightedMeanSpeed = val;
            self.flags |= gcFieldFlagWeightedMeanSpeed;
            break;
        }
        default:
            break;
    }
    return rv;
}

-(GCNumberWithUnit*)numberWithForFieldInStoreUnit:(GCField *)field{
    switch (field.fieldFlag) {
        case gcFieldFlagWeightedMeanSpeed:
            return [[self numberWithUnitForField:field] convertToUnit:[GCUnit unitForKey:STOREUNIT_SPEED]];
        case gcFieldFlagSumDistance:
            return [[self numberWithUnitForField:field] convertToUnit:[GCUnit unitForKey:STOREUNIT_DISTANCE]];
        case gcFieldFlagSumDuration:
            return [[self numberWithUnitForField:field] convertToUnit:[GCUnit unitForKey:STOREUNIT_ELAPSED]];
        default:
            return [self numberWithUnitForField:field];
    }
}

-(double)summaryFieldValueInStoreUnit:(gcFieldFlag)fieldFlag{
    switch (fieldFlag) {
        case gcFieldFlagWeightedMeanHeartRate:
            return self.weightedMeanHeartRate;
        case gcFieldFlagWeightedMeanSpeed:
            return self.weightedMeanSpeed;
        case gcFieldFlagSumDuration:
            return self.sumDuration;
        case gcFieldFlagSumDistance:
            return self.sumDistance;
            
        default:
            return 0.0;
    }
}
-(void)setSummaryField:(gcFieldFlag)fieldFlag inStoreUnitValue:(double)value{
    switch (fieldFlag) {
        case gcFieldFlagWeightedMeanHeartRate:
            self.weightedMeanHeartRate = value;
            self.flags |= fieldFlag;
            break;
        case gcFieldFlagWeightedMeanSpeed:
            self.weightedMeanSpeed = value;
            self.flags |= fieldFlag;
            break;
        case gcFieldFlagSumDuration:
            self.sumDuration = value;
            self.flags |= fieldFlag;
            break;
        case gcFieldFlagSumDistance:
            self.sumDistance = value;
            self.flags |= fieldFlag;
            break;
        default:
            break;
    }

}

#pragma mark - Test on Fields

-(NSArray<GCField*>*)allFields{
    [self loadSummaryData];

    NSMutableArray<GCField*> * rv = [NSMutableArray array];
    for (GCField * field in _summaryData.allKeys) {
        [rv addObject:field];
    }
    if (self.calculatedFields) {
        for (GCField * field in self.calculatedFields.allKeys) {
            [rv addObject:field];
        }
    }
    return [NSArray arrayWithArray:rv];
}

-(NSArray<GCField*>*)validStoredSummaryFields{
    return @[
        [GCField fieldForFlag:gcFieldFlagSumDistance andActivityType:self.activityType],
        [GCField fieldForFlag:gcFieldFlagSumDuration andActivityType:self.activityType],
        [GCField fieldForFlag:gcFieldFlagWeightedMeanSpeed andActivityType:self.activityType],
        [GCField fieldForFlag:gcFieldFlagWeightedMeanHeartRate andActivityType:self.activityType],
    ];
}
-(NSArray<NSString*>*)allFieldsKeys{
    NSArray<GCField*> * rv = [self allFields];
    
    NSMutableArray<NSString*>*final = [NSMutableArray arrayWithCapacity:rv.count];
    
    for (GCField * f in rv) {
        [final addObject:f.key];
    }
    return final;
}

-(NSString*)displayName{
    if (([_activityName isEqualToString:@"Untitled"] || [_activityName isEqualToString:@""]) && ![_location isEqualToString:@""]){
        return _location;
    }
    return _activityName ?:@"";
}

#pragma mark - GCField Access methods


/**
 Test is a field is available
 */
-(BOOL)hasField:(GCField*)field{
    BOOL rv = false;
    switch (field.fieldFlag) {
        case gcFieldFlagSumDuration:
            rv = RZTestOption(self.flags, gcFieldFlagSumDuration);
            break;            
        case gcFieldFlagSumDistance:
            rv = RZTestOption(self.flags, gcFieldFlagSumDistance);
            break;
        case gcFieldFlagWeightedMeanSpeed:
            rv = RZTestOption(self.flags, gcFieldFlagWeightedMeanSpeed);
            break;
        case gcFieldFlagWeightedMeanHeartRate:
            rv = RZTestOption(self.flags, gcFieldFlagWeightedMeanHeartRate);
            break;
        default:
        {
            [self loadSummaryData];
            rv = _summaryData[field] != nil || self.calculatedFields[field] != nil;
        }
    }
    return rv;
}


/**
 Return the display unit for field as stored for that specific activity
 */
-(GCUnit*)displayUnitForField:(GCField*)field{
    GCUnit * rv = nil;
    switch (field.fieldFlag) {
        case gcFieldFlagSumDistance:
            rv = self.distanceDisplayUnit;
            break;
        case gcFieldFlagWeightedMeanSpeed:
            rv = self.speedDisplayUnit;
            break;
        default:
        {
            rv = field.unit;
            if( ! rv ){
                rv = [self numberWithUnitForFieldKey:field.key].unit;
                if (!rv) {
                    GCTrackPointExtraIndex * extra = self.cachedExtraTracksIndexes[field];
                    if (extra) {
                        rv = extra.unit;
                    }
                }
                if (!rv) {
                    rv = [field unit];
                }
            }
        }
    }
    return [rv unitForGlobalSystem];
}

-(GCUnit*)storeUnitForField:(GCField*)field{
    GCUnit * rv = nil;
    gcFieldFlag which = field.fieldFlag;

    switch (which) {
        case gcFieldFlagWeightedMeanSpeed:
            rv = [GCUnit unitForKey:STOREUNIT_SPEED];
            break;
        case gcFieldFlagAltitudeMeters:
            rv = [GCUnit unitForKey:STOREUNIT_ALTITUDE];
            break;
        case gcFieldFlagSumDistance:
            rv = [GCUnit unitForKey:STOREUNIT_DISTANCE];
            break;
        case gcFieldFlagSumDuration:
            rv = [GCUnit unitForKey:STOREUNIT_ELAPSED];
            break;
        default:
        {
            rv = [self numberWithUnitForField:field].unit;
            if( ! rv ){
                rv = [field unit];
            }
        }
    }
    return  rv;
}

-(NSString*)formatValue:(double)val forField:(GCField*)field{
    GCUnit * unit = [self displayUnitForField:field];
    return [unit formatDouble:val];
}

-(NSString*)formatValueNoUnits:(double)val forField:(GCField*)field{
    GCUnit * unit = [self displayUnitForField:field];
    return [unit formatDoubleNoUnits:val];
}

-(NSString*)formattedValue:(GCField*)field{
    return [[self numberWithUnitForField:field] formatDouble] ?: @"";
}

-(NSString*)formatNumberWithUnit:(GCNumberWithUnit*)nu forField:(GCField*)which{
    GCUnit * unit = [self displayUnitForField:which];
    return [[nu convertToUnit:unit] formatDouble];
}

-(NSDate*)startTime{
    return self.date;
}

-(NSDate*)endTime{
    return [self.date dateByAddingTimeInterval:self.sumDuration];
}

#pragma mark -

// tracks
// select strftime( '%c', Time/60/60/24+2440587.5 ) as Timestamp, distanceMeter,Speed from gc_track limit 10

//NEWTRACKFIELD avoid gcFieldFlag if possible
-(void)createTrackDb:(FMDatabase*)trackdb{
    [trackdb executeUpdate:@"DROP TABLE IF EXISTS gc_version_track"];
    [trackdb executeUpdate:@"DROP TABLE IF EXISTS gc_track"];
    [trackdb executeUpdate:@"DROP TABLE IF EXISTS gc_laps"];
    [trackdb executeUpdate:@"DROP TABLE IF EXISTS gc_laps_info"];
    
    // In case older database, specific pool data not used anymore
    [trackdb executeUpdate:@"DROP TABLE IF EXISTS gc_length"];
    [trackdb executeUpdate:@"DROP TABLE IF EXISTS gc_length_info"];
    [trackdb executeUpdate:@"DROP TABLE IF EXISTS gc_pool_lap"];
    [trackdb executeUpdate:@"DROP TABLE IF EXISTS gc_pool_lap_info"];

    [trackdb executeUpdate:@"DROP TABLE IF EXISTS gc_track_extra_idx"];
    [trackdb executeUpdate:@"DROP TABLE IF EXISTS gc_track_extra"];

    // Run/cycle gps activities

    [trackdb executeUpdate:@"CREATE TABLE gc_track (Time REAL,LatitudeDegrees REAL,LongitudeDegrees REAL,DistanceMeters REAL,HeartRateBpm REAL,Speed REAL,Cadence REAL,Altitude REAL,Power REAL,VerticalOscillation REAL,GroundContactTime REAL,lap INTEGER,elapsed REAL, trackflags INTEGER)"];
    [trackdb executeUpdate:@"CREATE TABLE gc_laps (lap INTEGER, Time REAL,LatitudeDegrees REAL,LongitudeDegrees REAL,DistanceMeters REAL,HeartRateBpm REAL,Speed REAL,Altitude REAL,Cadence REAL,Power REAL,VerticalOscillation REAL,GroundContactTime REAL,elapsed REAL, trackflags INTEGER)"];
    [trackdb executeUpdate:@"CREATE TABLE gc_laps_info (lap INTEGER,field TEXT,value REAL,uom TEXT)"];


    [trackdb executeUpdate:@"CREATE TABLE gc_track_extra_idx (field TEXT, idx INTEGER PRIMARY KEY, uom TEXT)"];

    [trackdb executeUpdate:@"CREATE TABLE gc_version_track (version INTEGER)"];
    // Version 1
    // Version 2: Add track_extra
    // Version 3: Pool Information merge with laps/track
    [trackdb executeUpdate:@"INSERT INTO gc_version_track (version) VALUES (2)"];
    [trackdb executeUpdate:@"INSERT INTO gc_version_track (version) VALUES (3)"];
}

-(FMDatabase*)db{
    if (self.useDb != nil) {
        return self.useDb;
    }
    return [GCAppGlobal db];
}
-(void)setDb:(FMDatabase*)adb{
    self.useDb = adb;
}

-(FMDatabase*)trackdb{
    if (self.useTrackDb == nil) {
        self.useTrackDb = [FMDatabase databaseWithPath:[self trackDbFileName]];
        [self.useTrackDb open];
    }
    return self.useTrackDb;
}

-(void)setTrackdb:(FMDatabase*)db{
    self.useTrackDb = db;
}

-(NSString*)trackDbFileName{
    if (self.useTrackDb) {
        return self.useTrackDb.databasePath;
    }else{
        return [RZFileOrganizer writeableFilePath:[NSString stringWithFormat:@"track_%@.db", _activityId]];
    }
}

-(BOOL)hasTrackDb{
    return self.useTrackDb || [[NSFileManager defaultManager] fileExistsAtPath:[self trackDbFileName]];
}

#pragma mark - Load, Save and Update Trackpoint GPS

-(void)saveTrackpointsExtraToDb:(FMDatabase*)db{
    if (self.cachedExtraTracksIndexes.count > 0) {
        NSArray * extra = [[self.cachedExtraTracksIndexes allValues] sortedArrayUsingComparator:^(GCTrackPointExtraIndex*i1,GCTrackPointExtraIndex*i2){
            NSComparisonResult rv = (i1.idx < i2.idx) ? NSOrderedAscending : (i1.idx == i2.idx ? NSOrderedSame : NSOrderedDescending);
            return rv;
        }];
        NSMutableArray * createFields = [NSMutableArray arrayWithObject:@"Time Real"];
        // list of field names
        NSMutableArray * insertFields = [NSMutableArray arrayWithObject:@"Time"];
        // list Keys for named parameters use ":FieldKey" (which FieldKey being the datacolumnname)
        NSMutableArray * insertValues = [NSMutableArray arrayWithObject:@":Time"];

        for (GCTrackPointExtraIndex * one in extra  ) {
            [createFields addObject:[NSString stringWithFormat:@"%@ Real", one.dataColumnName]];
            [insertFields addObject:one.dataColumnName];
            [insertValues addObject:[NSString stringWithFormat:@":%@", one.dataColumnName]];
            if( ![db executeUpdate:@"INSERT INTO gc_track_extra_idx (field,idx,uom) VALUES (?,?,?)", one.dataColumnName, @(one.idx), one.unit.key]){
                RZLog(RZLogError, @"db error %@", db.lastErrorMessage);
            }
        }

        [db executeUpdate:@"DROP TABLE IF EXISTS gc_track_extra"];
        NSString * createQuery = [NSString stringWithFormat:@"CREATE TABLE gc_track_extra (%@)", [createFields componentsJoinedByString:@","]];
        [db executeUpdate:createQuery];

        NSString * insertQuery = [NSString stringWithFormat:@"INSERT INTO gc_track_extra (%@) VALUES (%@)", [insertFields componentsJoinedByString:@","], [ insertValues componentsJoinedByString:@","]];

        NSMutableDictionary * data = [NSMutableDictionary dictionary];
        for (GCTrackPoint * one in self.trackpointsCache) {
            [data removeAllObjects];
            data[@"Time"] = one.time;
            if (one.extra) {
                for (GCTrackPointExtraIndex * e in extra) {
                    NSNumber * val = [[one numberWithUnitForField:e.field inActivity:self] convertToUnit:e.unit].number;
                    if( val ){
                        data[e.dataColumnName] = val;
                    }else{
                        data[e.dataColumnName] = [NSNull null];
                    }
                }
                if( ![db executeUpdate:insertQuery withParameterDictionary:data]){
                    RZLog(RZLogError, @"db error %@", db.lastErrorMessage);
                }
            }
        }
    }
}

-(void)saveTrackpointsAndLapsToDb:(FMDatabase*)aDb{

    [self createTrackDb:aDb];


    [aDb beginTransaction];
    [aDb setShouldCacheStatements:YES];

    if (self.trackpointsCache) {
        for (GCTrackPoint * point in self.trackpointsCache) {
            [point saveToDb:aDb];
            _trackFlags |= point.trackFlags;
        }
        [self saveTrackpointsExtraToDb:aDb];
    }
    if (self.lapsCache) {
        for (GCLap * lap in self.lapsCache) {
            [lap saveToDb:aDb];
        }
    }
    if(![aDb commit]){
        RZLog(RZLogError, @"trackdb commit %@",[aDb lastErrorMessage]);
    }
    //[aDb setShouldCacheStatements:NO];
    [self notifyForString:kGCActivityNotifyTrackpointReady];

}

/// Update trackpoints and laps in memory.
/// Will update and link the laps indexes to the trackpoints,
/// @param aTrack An array of GCTrackPoints
/// @param laps an array of GCLaps
-(BOOL)updateWithTrackpoints:(NSArray<GCTrackPoint*>*)aTrack andLaps:(NSArray<GCLap*> *)laps{
    BOOL rv = true;
    
    NSMutableArray * trackData = [NSMutableArray arrayWithCapacity:aTrack.count];
    
    NSUInteger lapIdx = 0;
    NSUInteger nLaps = laps.count;
    
    NSMutableArray * newlapsCache = [NSMutableArray arrayWithCapacity:nLaps];
    NSUInteger startTrackpointFlag = self.trackFlags;
    
    for (id lone in laps) {
        GCLap * nlap = nil;//for release
        GCLap * alap = nil;
        if ([lone isKindOfClass:[GCLap class]] ) {
            alap = lone;
        }else if([lone isKindOfClass:[NSDictionary class]]){
            nlap = [[GCLap alloc] initWithDictionary:lone forActivity:self];
            alap = nlap;
        }
        alap.lapIndex = lapIdx++;
        if (alap) {
            [newlapsCache addObject:alap];
        }
        [nlap release];
    }
    self.lapsCache = newlapsCache;
    nLaps = self.lapsCache.count;
    
    lapIdx = 0;
    GCLap * nextLap = lapIdx + 1 < nLaps ? _lapsCache[lapIdx+1] : nil;
    BOOL first = true;
    _trackFlags = gcFieldFlagNone;
    
    NSUInteger countBadLaps = 0;
    GCTrackPoint * lastTrack = nil;
    BOOL firstDone = false;
    
    for (id data in aTrack) {
        GCTrackPoint * npoint = nil;
        GCTrackPoint * point = nil;
        if(!firstDone){
            self.cachedExtraTracksIndexes = nil;
        }
        
        if ([data isKindOfClass:[GCTrackPoint class]]) {
            point = data;
            if (point.time==nil) {
                point.time = [self.date dateByAddingTimeInterval:point.elapsed];
                if (point.time==nil) {
                    countBadLaps++;
                    continue;
                }
            }
            [point recordExtraIn:self];
        }else if ([data isKindOfClass:[NSDictionary class]]){
            // If parsing from dict, reset extra indexes to rebuild
            // with fields we get in dict
            npoint = [[GCTrackPoint alloc] initWithDictionary:data forActivity:self];
            point = npoint;
        }
        if (lastTrack) {
            //[lastTrack updateWithNextPoint:point];
        }
        lastTrack = point;
        [point updateElapsedIfNecessaryIn:self];
        if (first && nLaps > 0) {
            GCLap * this = _lapsCache[0];
            this.longitudeDegrees = point.longitudeDegrees;
            this.latitudeDegrees = point.latitudeDegrees;
        }
        if (nextLap && [point.time compare:nextLap.time] == NSOrderedDescending) {
            nextLap.longitudeDegrees = point.longitudeDegrees;
            nextLap.latitudeDegrees = point.latitudeDegrees;
            
            lapIdx++;
            nextLap = lapIdx + 1 < nLaps ? _lapsCache[lapIdx+1] : nil;
        }
        point.lapIndex = lapIdx;
        if (point) {
            [trackData addObject:point];
            self.trackFlags |= point.trackFlags;
        }
        [npoint release];
        firstDone = true;
    }
    
    if( self.trackFlags != startTrackpointFlag){
        rv = true;
    }
    
    self.trackpointsCache = trackData;
    [self registerLaps:self.lapsCache forName:GC_LAPS_RECORDED];
    
    if (![self validCoordinate] && trackData.count>0) {
        self.beginCoordinate = [trackData[0] coordinate2D];
        rv = true;
    }
    
    [GCFieldsCalculated addCalculatedFieldsToLaps:self.lapsCache forActivity:self];
    
    if([self updateSummaryFromTrackpoints:self.trackpointsCache missingOnly:TRUE]){
        rv = true;
    }
    
    [self notifyForString:kGCActivityNotifyTrackpointReady];
    
    return rv;
}


-(BOOL)saveTrackpoints:(NSArray*)aTrack andLaps:(NSArray *)laps{
    
    BOOL rv = [self updateWithTrackpoints:aTrack andLaps:laps];
    FMDatabase * db = self.db;
    FMDatabase * trackdb = self.trackdb;
    
    if ([trackdb tableExists:@"gc_track"] && [trackdb intForQuery:@"SELECT COUNT(*) FROM gc_track"] == self.trackpoints.count) {
        rv = false;
    }
    
    [self saveTrackpointsAndLapsToDb:trackdb];
    
    // save main activities if needed
    if( rv ){
        
        if (![db executeUpdate:@"UPDATE gc_activities SET trackFlags = ? WHERE activityId=?",@(_trackFlags), _activityId]){
            RZLog(RZLogError, @"db update %@",[db lastErrorMessage]);
        }
        if ([trackdb tableExists:@"gc_activities"]) {
            if (![trackdb executeUpdate:@"UPDATE gc_activities SET trackFlags = ? WHERE activityId=?",@(_trackFlags), _activityId]){
                RZLog(RZLogError, @"db update %@",[db lastErrorMessage]);
            }
        }
        if (![db executeUpdate:@"UPDATE gc_activities SET BeginLatitude = ?, BeginLongitude = ? WHERE activityId=?",
              @(self.beginCoordinate.latitude), @(self.beginCoordinate.longitude), _activityId]){
            RZLog(RZLogError, @"db update %@",[db lastErrorMessage]);
        }

        [self saveToDb:self.db];
    
        if ([[GCAppGlobal profile] configGetBool:CONFIG_ENABLE_DERIVED defaultValue:[GCAppGlobal connectStatsVersion]]) {
            dispatch_async([GCAppGlobal worker],^(){
                [[GCAppGlobal derived] processActivities:@[self]];
            });
        }
    }
    return rv;
}

-(void)loadTrackPointsGPS:(FMDatabase*)trackdb{

    if (![trackdb columnExists:@"elapsed" inTableWithName:@"gc_track"]) {
        [trackdb executeUpdate:@"ALTER TABLE gc_track ADD COLUMN elapsed REAL DEFAULT 0."];
    }
    if (![trackdb columnExists:@"trackflags" inTableWithName:@"gc_track"]) {
        RZEXECUTEUPDATE(trackdb, [ NSString stringWithFormat:@"ALTER TABLE gc_track ADD COLUMN trackflags INTEGER DEFAULT %lu", (unsigned long)self.trackFlags]);
    }

    FMResultSet * res = [trackdb executeQuery:@"SELECT * FROM gc_track ORDER BY Time"];

    // Add to tmp array, in case there is a request from another thread, don't
    // want to have it muted while in use.
    self.trackpointsCache = [NSMutableArray array];
    self.lapsCache = [NSMutableArray array];

    NSMutableArray * tmptracks = [NSMutableArray array];

    gcFieldFlag loadedTrackFlags = gcFieldFlagNone;

    while ([res next]) {
        GCTrackPoint * point =[[[GCTrackPoint alloc] initWithResultSet:res] autorelease];
        [point updateElapsedIfNecessaryIn:self];
        loadedTrackFlags |= point.trackFlags;
        [tmptracks addObject:point];
    }
    if (loadedTrackFlags != self.trackFlags) {
        self.trackFlags = loadedTrackFlags;
    }
    [res close];

    self.trackpointsCache = tmptracks;

    [self loadTrackPointsExtraFromDb:trackdb];

    if(![trackdb columnExists:@"uom" inTableWithName:@"gc_laps_info"]) {
        [trackdb executeUpdate:@"ALTER TABLE gc_laps_info ADD COLUMN uom TEXT DEFAULT NULL"];
    }
    if (![trackdb columnExists:@"elapsed" inTableWithName:@"gc_laps"]) {
        [trackdb executeUpdate:@"ALTER TABLE gc_laps ADD COLUMN elapsed REAL DEFAULT 0."];
    }
    if (![trackdb columnExists:@"trackflags" inTableWithName:@"gc_laps"]) {
        RZEXECUTEUPDATE(trackdb, [ NSString stringWithFormat:@"ALTER TABLE gc_laps ADD COLUMN trackflags INTEGER DEFAULT %lu", (unsigned long)self.trackFlags]);
    }

    NSMutableArray * tmplaps = [NSMutableArray array];

    res = [trackdb executeQuery:@"SELECT * FROM gc_laps ORDER BY lap"];
    if (!res) {
        RZLog(RZLogError, @"track db %@", [trackdb lastErrorMessage]);
    }
    while ([res next]) {
        [tmplaps addObject:[[[GCLap alloc] initWithResultSet:res] autorelease]];
    }

    [res close];
    res = [trackdb executeQuery:@"SELECT * FROM gc_laps_info ORDER BY lap"];
    if (!res) {
        RZLog(RZLogError, @"track db %@", [trackdb lastErrorMessage]);
    }
    if (tmplaps.count> 0) {
        NSUInteger lap_idx = 0;
        GCLap * lap = tmplaps[lap_idx];
        while ([res next]) {
            NSUInteger this_idx = [res intForColumn:@"lap"];
            if (this_idx != lap_idx) {
                lap_idx = this_idx;
                lap = tmplaps[lap_idx];
            }
            [lap addExtraFromResultSet:res inActivity:self];
        }
    }
    self.lapsCache = tmplaps;
    [self registerLaps:self.lapsCache forName:GC_LAPS_RECORDED];
    
    [self addCalculatedTrackPoints];
    
}

-(void)loadTrackPointsExtraFromDb:(FMDatabase*)db{
    if ([db tableExists:@"gc_track_extra_idx"] && [db tableExists:@"gc_track_extra"]) {
        NSMutableDictionary<GCField*,GCTrackPointExtraIndex*> * extra = [NSMutableDictionary dictionary];
        FMResultSet * res = [db executeQuery:@"SELECT * FROM gc_track_extra_idx" ];
        while( [res next]){
            GCField * field = [GCField fieldForKey:[res stringForColumn:@"field"] andActivityType:self.activityType];
            if( field.isInternal ){
                field = [field correspondingFieldForActivityType:GC_TYPE_ALL];
            }
            size_t idx =  [res intForColumn:@"idx"];
            GCUnit * unit = [GCUnit unitForKey:[res stringForColumn:@"uom"]];
            extra[field] = [GCTrackPointExtraIndex extraIndex:idx field:field andUnit:unit];
            if( field.isInternal ){
            }
        };
        self.cachedExtraTracksIndexes = extra;
        if (extra.count && self.trackpointsCache.count > 0) {
            NSUInteger i=0;
            GCTrackPoint * point = self.trackpointsCache[i];
            NSUInteger count = self.trackpointsCache.count;
            res = [db executeQuery:@"SELECT * FROM gc_track_extra"];

            while ([res next]) {
                NSDate * time = [res dateForColumn:@"Time"];
                while (point != nil && [point.time compare:time] == NSOrderedAscending) {
                    i++;
                    point = i<count ? self.trackpointsCache[i] : nil;
                };
                if ([point.time isEqualToDate:time]) {
                    for (GCTrackPointExtraIndex * e in extra.allValues) {
                        if( ! [res columnIsNull:e.dataColumnName]){
                            GCNumberWithUnit * nu = [GCNumberWithUnit numberWithUnit:e.unit andValue:[res doubleForColumn:e.dataColumnName]];
                            [point setNumberWithUnit:nu forField:e.field inActivity:self];
                        }
                    }
                }
            }
        }
    }
}

-(void)addCalculatedTrackPoints{
    if( self.trackpointsCache){
#if DISABLE_NEW_FEATURE
        NSArray<GCTrackPoint*>*resampled = [self resample:self.trackpointsCache forUnit:5.0 useTimeAxis:YES];
        NSArray<GCTrackPoint*>*distanceMatched = [self matchDistance:self.sumDistance withPoints:self.trackpointsCache];
        
        self.calculatedTrackPoints = [NSMutableDictionary dictionaryWithDictionary:@{
            GC_TRACKPOINTS_RECORDED: self.trackpointsCache,
            GC_TRACKPOINTS_MATCHED: distanceMatched,
            GC_TRACKPOINTS_RESAMPLED: resampled
        }];
#else
        self.calculatedTrackPoints = [NSMutableDictionary dictionaryWithDictionary:@{
            GC_TRACKPOINTS_RECORDED: self.trackpointsCache,
        }];
#endif
    }
}

#pragma mark - Load Trackpoints

-(void)clearTrackdb{
    [self.useTrackDb close];
    self.useTrackDb = nil;
    [self setTrackpointsCache:nil];
    [self setLapsCache:nil];
    [self setCalculatedLaps:nil];
    [self setCachedCalculatedTracks:nil];
    [RZFileOrganizer removeEditableFile:[NSString stringWithFormat:@"track_%@.db",_activityId]];

    _downloadRequested = false;
}

-(void)loadTrackPointsFromDb:(FMDatabase*)trackdb{
    [self loadTrackPointsGPS:trackdb];
    
    [GCFieldsCalculated addCalculatedFieldsToLaps:self.lapsCache forActivity:self];
}

-(void)forceReloadTrackPoints{
    [self clearTrackdb];
    self.weather = nil;
    switch (_downloadMethod) {
        case gcDownloadMethod13:
        case gcDownloadMethodModern:
            [[GCAppGlobal derived] forceReprocessActivity:_activityId];
            [[GCAppGlobal web] garminDownloadActivitySummary:_activityId];
            break;
        case gcDownloadMethodStrava:
        case gcDownloadMethodConnectStats:
            [[GCAppGlobal derived] forceReprocessActivity:_activityId];
            /*if( self.externalServiceActivityId ){
                [[GCAppGlobal web] garminDownloadActivitySummary:self.externalServiceActivityId];
            }*/
            break;
        case gcDownloadMethodSportTracks:
            break;
        default:
            break;
    }
}

-(BOOL)trackdbIsObsolete:(FMDatabase*)trackdb{
    BOOL rv = false;
    
    // Rename gc_version to gc_version_track so we can merge track /activity db
    if ([trackdb tableExists:@"gc_version"] && ![trackdb tableExists:@"gc_version_track"]) {
        int version = [trackdb intForQuery:@"SELECT MAX(version) from gc_version"];
        RZEXECUTEUPDATE(trackdb, @"CREATE TABLE gc_version_track (version INTEGER)");

        if (version >= 4) {
            RZEXECUTEUPDATE(trackdb, @"INSERT INTO gc_version_track (version) VALUES (1)");
        }else{
            rv = true;
        }

        RZEXECUTEUPDATE(trackdb, @"DROP TABLE gc_version");
    }

    if( ![trackdb tableExists:@"gc_version_track"]){
        RZEXECUTEUPDATE(trackdb, @"CREATE TABLE gc_version_track (version INTEGER)");
        RZEXECUTEUPDATE(trackdb, @"INSERT INTO gc_version_track (version) VALUES (1)");
        rv = true;
    }
    
    int version = [trackdb intForQuery:@"SELECT MAX(version) from gc_version_track"];
    
    if(version < 1){
        rv = true;
    }
    
    if( version < 3 ){
        if( self.garminSwimAlgorithm ){
            // If swim algo, need to re-build
            rv = true;
        }else{
            // If not swim algo, just mark it as valid, as nothing needs changing
            RZEXECUTEUPDATE(trackdb, @"INSERT INTO gc_version_track (version) VALUES (3)");
        }
    }
    return rv;

}

-(BOOL)trackPointsRequireDownload{
    BOOL rv = true;
    if (self.trackpointsCache) {
        rv = false;
    }else{
        if (self.hasTrackDb) {
            rv = false;
        }else{
            switch (self.downloadMethod) {
                case gcDownloadMethodTennis:
                case gcDownloadMethodFitFile:
                case gcDownloadMethodHealthKit:
                case gcDownloadMethodWithings:
                    rv = false;
                    break;

                default:
                    break;
            }
        }
    }
    return  rv;
}

-(BOOL)pendingUpdate{
    return _downloadRequested;
}

-(BOOL)loadTrackPoints{
    BOOL rv = false;
    if (self.hasTrackDb) {
        RZPerformance * perf = [RZPerformance start];
        
        FMDatabase * trackdb = self.trackdb;

        if (![self trackdbIsObsolete:trackdb]) {
            [self loadTrackPointsFromDb:trackdb];
            RZLog(RZLogInfo, @"%@ Loaded trackpoints count = %lu %@", self, (unsigned long)self.trackpointsCache.count, perf);
            [self notifyForString:kGCActivityNotifyTrackpointReady];
            rv = true;
        }
    }

    if (!rv) {
        // don't do it repeatedly
        if (!_downloadRequested) {
            _downloadRequested = true;
            [[GCAppGlobal web] attach:self];
            switch (_downloadMethod) {
                case gcDownloadMethodDetails:
                    // disabled/obsolete
                case gcDownloadMethodSwim:
                case gcDownloadMethodModern:
                    [[GCAppGlobal web] garminDownloadActivitySummary:_activityId];
                case gcDownloadMethod13:
                    [[GCAppGlobal web] garminDownloadActivityTrackPoints13:self];
                    break;
                case gcDownloadMethodDefault:
                    [[GCAppGlobal web] garminDownloadActivityTrackPoints13:self];
                    break;
                case gcDownloadMethodStrava:
                    [[GCAppGlobal web] stravaDownloadActivityTrackPoints:self];
                    break;
                case gcDownloadMethodSportTracks:
                    break;
                case gcDownloadMethodHealthKit:
                {
#if !TARGET_OS_SIMULATOR
                    if ([self.activityType isEqualToString:GC_TYPE_DAY]) {
                        [[GCAppGlobal web] healthStoreDayDetails:self.date];
                    }
#endif
                    break;
                }
                case gcDownloadMethodConnectStats:
                    [[GCAppGlobal web] connectStatsDownloadActivityTrackpoints:self];
                    break;
                case gcDownloadMethodTennis:
                case gcDownloadMethodFitFile:
                case gcDownloadMethodWithings:
                
                    break;

            }
            // attempt to download weather at same time
            if (_downloadMethod == gcDownloadMethod13|| _downloadMethod == gcDownloadMethodModern) {
                // DISABLE STRAVA UPLOAD
                if ([[GCAppGlobal profile] configGetBool:CONFIG_SHARING_STRAVA_AUTO defaultValue:false]) {
                    [[GCAppGlobal profile] configSet:CONFIG_SHARING_STRAVA_AUTO boolVal:false];
                    [GCAppGlobal saveSettings];
                }
            }
            if(_downloadMethod == gcDownloadMethodConnectStats){
                if (![self hasWeather]) {
                    [[GCAppGlobal web] connectStatsDownloadWeather:self];
                }
            }
        }
    }
    return rv;
}

#pragma mark - Trackpoints

-(BOOL)hasTrackField:(gcFieldFlag)which{
    return (which & _trackFlags) == which;
}

-(void)addTrackPoint:(GCTrackPoint *)point{
    if (!self.trackpointsCache) {
        self.trackpointsCache = @[ point ];
    }else{
        self.trackpointsCache = [self.trackpointsCache arrayByAddingObject:point];
    }
}

-(GCField*)nextAvailableTrackField:(GCField*)which{
    GCField * rv = nil;
    NSArray * available = [self availableTrackFields];
    if (available.count > 0) {
        if (which == nil) {
            rv = available[0];
        }else{
            NSUInteger idx = 0;
            for (idx=0; idx<available.count; idx++) {
                GCField * field = available[idx];
                if ([field isEqualToField:which]) {
                    break;
                }
            }
            if (idx + 1 < available.count) {
                rv = available[idx+1];
            }else{
                rv = available[0];
            }
        }
    }
    return rv;
}

/**
 @brief available fields in activitiy
 */
-(NSArray<GCField*>*)availableFields{
    NSMutableDictionary * unique = [NSMutableDictionary dictionary];
    NSArray * track = [GCFields availableFieldsIn:self.flags forActivityType:self.activityType];
    for (GCField * one in track) {
        unique[one] = @1;
    }
    for (GCField * one in self.summaryData) {
        // if speed or pace, don't add twice, was already added above
        if( one.isSpeedOrPace && (_trackFlags & gcFieldFlagWeightedMeanSpeed ) == gcFieldFlagWeightedMeanSpeed){
            continue;
        }
        if( one.validForGraph ){
            unique[one] = @1;
        }
    }
    return [unique.allKeys sortedArrayUsingSelector:@selector(compare:)];

}
/**
 Return list of available fields with Track Points. Will include calculated tracks
 @return NSArray<GCField*>
 */
-(NSArray*)availableTrackFields{
    NSMutableDictionary * unique = [NSMutableDictionary dictionary];
    NSArray * track = [GCFields availableFieldsIn:_trackFlags forActivityType:self.activityType];
    for (GCField * one in track) {
        unique[one] = @1;
    }
    for (GCField * field in self.cachedExtraTracksIndexes) {
        GCField * one = field;
        // if speed or pace, don't add twice, was already added above
        if( one.isSpeedOrPace && (_trackFlags & gcFieldFlagWeightedMeanSpeed ) == gcFieldFlagWeightedMeanSpeed){
            continue;
        }
        if( one.validForGraph ){
            unique[one] = @1;
        }
    }
    for( GCField * field in self.cachedCalculatedTracks){
        unique[field] = @1;
    }
    return [unique.allKeys sortedArrayUsingSelector:@selector(compare:)];
}

-(BOOL)trackpointsReadyOrLoad{
    if (_trackpointsCache) {
        return true;
    }

    return [self loadTrackPoints];
}
-(BOOL)trackpointsReadyNoLoad{
    return _trackpointsCache != nil;
}
-(NSArray*)trackpoints{
    if (!_trackpointsCache) {
        [self loadTrackPoints];
    }
    NSString * useKey = GC_TRACKPOINTS_RECORDED;
    NSArray*rv = self.calculatedTrackPoints[useKey];
    if( rv == nil){
        rv = self.trackpointsCache;
    }
    return rv;
}
-(void)setTrackpoints:(NSArray<GCTrackPoint *> *)trackpoints{
    self.trackpointsCache = trackpoints;
}


#pragma mark - Laps

-(NSArray*)laps{
    if (!_lapsCache) {
        [self loadTrackPoints];
    }
    return self.lapsCache;

}

-(void)registerLaps:(NSArray*)laps forName:(NSString*)name{
    if (self.calculatedLaps == nil) {
        self.calculatedLaps = [NSMutableDictionary dictionary];
    }
    
    [self.calculatedLaps setValue:laps forKey:name];
}
-(void)clearCalculatedLaps{
    NSArray * recorded = self.calculatedLaps[GC_LAPS_RECORDED];
    self.calculatedLaps = nil;
    [self registerLaps:recorded forName:GC_LAPS_RECORDED];
}

-(void)focusOnLapIndex:(NSUInteger)lapIndex{
    // cheat for compound path that have multi point in the same lap
    NSUInteger nLaps = (self.lapsCache).count;
    if (lapIndex < nLaps) {
        if ([self.lapsCache[lapIndex] isKindOfClass:[GCLapCompound class]]) {
            GCLapCompound * lap = self.lapsCache[lapIndex];
            for (GCTrackPoint * point in self.trackpointsCache) {
                if ([lap pointInLap:point]) {
                    point.lapIndex = lapIndex;
                }
            }
        }
    }
}

-(void)remapLapIndex:(NSArray*)laps{
    NSUInteger lapIdx = 0;
    NSUInteger nLaps = laps.count;
    if (nLaps>0) {
        for (NSUInteger idx=0; idx<nLaps; idx++) {
            GCLap * lap = laps[idx];
            lap.lapIndex = idx;
        }
        if ([laps[0] isKindOfClass:[GCLapCompound class]]) {
            for (GCTrackPoint * point in self.trackpointsCache) {
                point.lapIndex = -1;
                for (NSUInteger idx = 0; idx<laps.count; idx++) {
                    GCLapCompound * lap = laps[idx];
                    if ([lap pointInLap:point]) {
                        point.lapIndex = idx;
                        break;
                    }
                }
            }
        }else{
            GCLap * nextLap = lapIdx + 1 < nLaps ? laps[lapIdx+1] : nil;
            for (GCTrackPoint * point in self.trackpointsCache) {
                if (nextLap && [point.time compare:nextLap.time] == NSOrderedDescending) {
                    lapIdx++;
                    nextLap = lapIdx + 1 < nLaps ? _lapsCache[lapIdx+1] : nil;
                }
                point.lapIndex = lapIdx;
            }
        }
    }
}

-(BOOL)useLaps:(NSString*)name{
    NSArray * laps = self.calculatedLaps[name];
    if (laps) {
        self.lapsCache = laps;
        [self remapLapIndex:laps];
        [GCFieldsCalculated addCalculatedFieldsToLaps:self.lapsCache forActivity:self];
        self.calculatedLapName = name;
        return true;
    }
    return false;
}

-(NSUInteger)lapCount{
    if (!_lapsCache) {
        [self loadTrackPoints];
    }
    return _lapsCache.count;
}
-(GCLap*)lapNumber:(NSUInteger)idx{
    if (!_lapsCache) {
        [self loadTrackPoints];
    }
    return idx < _lapsCache.count ? _lapsCache[idx] : nil;
}


#pragma mark - Track Point Series


/**
 Check if activities has trackfield available. Note it may not be available
 immediately and require a load from the database or web
 */
-(BOOL)hasTrackForField:(GCField*)field{
    BOOL rv = false;
    if (field.fieldFlag != gcFieldFlagNone) {
        rv = RZTestOption(self.trackFlags, field.fieldFlag);
    }else{
        if ([self hasCalculatedSerieForField:field]) {
            rv = true;
        }else{
            rv = (self.cachedExtraTracksIndexes[field] != nil);
        }
    }
    return rv;
}
#pragma mark - weather


-(void)recordWeather:(GCWeather*)we{
    self.weather = we;
    [self.weather saveToDb:self.db forActivityId:self.activityId];

}

-(BOOL)hasWeather{
    return [self.weather valid];
}



#pragma mark -


-(BOOL)validCoordinate{
    bool rv = _beginCoordinate.latitude != 0 && _beginCoordinate.longitude != 0;
    if( !rv){
        if (self.trackpointsCache && self.trackpointsCache.count) {
            for (GCTrackPoint * p in self.trackpointsCache) {
                if( p.validCoordinate){
                    rv = true;
                    break;
                }
            }
        }
    }
    return rv;
}

-(void)saveLocation:(NSString*)aLoc{
    self.location = aLoc;
    [self.db executeUpdate:@"UPDATE gc_activities SET location=? WHERE activityId=?", _location, self.activityId];
}

-(void)purgeCache{
    [self setTrackpointsCache:nil];
    [self setLapsCache:nil];
    [self setCachedCalculatedTracks:nil];
    [self setUseTrackDb:nil];
}

#pragma mark - external activityId

-(BOOL)isSameAsActivityId:(NSString*)activityId{
    return activityId && ([self.activityId isEqualToString:activityId] || [self.externalActivityId isEqualToString:activityId]);
}

-(NSString*)externalServiceActivityId{
    GCActivityMetaValue * val = self.metaData[GC_EXTERNAL_ID];
    if (val) {
        return val.display;
    }
    return nil;
}

-(void)setExternalServiceActivityId:(NSString*)externalId{
    if (externalId) {
        GCActivityMetaValue * val = [GCActivityMetaValue activityMetaValueForDisplay:externalId andField:GC_EXTERNAL_ID];

        [self addEntriesToMetaData:@{ GC_EXTERNAL_ID : val }];

    }else{
        if (self.metaData[GC_EXTERNAL_ID]) {
            self.metaData = [self.metaData dictionaryByRemovingObjectsForKeys:@[ GC_EXTERNAL_ID] ];
        }
    }
}

#pragma mark - Parent/Child Ids

-(NSString*)parentId{
    GCActivityMetaValue * val = self.metaData[GC_PARENT_ID];
    if (val) {
        return val.display;
    }
    return nil;
}
-(void)setParentId:(NSString*)parentId{
    if (parentId) {
        GCActivityMetaValue * val = [GCActivityMetaValue activityMetaValueForDisplay:parentId andField:GC_PARENT_ID];

        [self addEntriesToMetaData:@{ GC_PARENT_ID : val }];

    }else{
        if (self.metaData[GC_PARENT_ID]) {
            self.metaData = [self.metaData dictionaryByRemovingObjectsForKeys:@[ GC_PARENT_ID] ];
        }
    }
}

-(NSArray*)childIds{
    GCActivityMetaValue * val = self.metaData[GC_CHILD_IDS];
    if (val) {
        return [val.display componentsSeparatedByString:@","];
    }
    return nil;
}
-(void)setChildIds:(NSArray*)childIds{
    if (childIds && childIds.count>0) {
        GCActivityMetaValue * val = [GCActivityMetaValue activityMetaValueForDisplay:[childIds componentsJoinedByString:@","] andField:GC_CHILD_IDS];
        [self addEntriesToMetaData:@{ GC_CHILD_IDS: val }];

    }else{
        if (self.metaData[GC_CHILD_IDS]) {
            self.metaData = [self.metaData dictionaryByRemovingObjectsForKeys:@[ GC_CHILD_IDS] ];

        }
    }
}

-(GCActivityMetaValue*)metaValueForField:(NSString*)field{
    GCActivityMetaValue * rv = _metaData[field];
    if( rv == nil){
        if( [field isEqualToString:GC_META_ACTIVITYTYPE] ){
            rv = [GCActivityMetaValue activityMetaValueForDisplay:self.activityTypeDetail.displayName andField:GC_META_ACTIVITYTYPE];
        }else if ([field isEqualToString:GC_META_SERVICE]){
            rv = [GCActivityMetaValue activityMetaValueForDisplay:self.service.displayName andField:GC_META_ACTIVITYTYPE];
        }
    }
    return rv;
}

-(void)updateSummaryFieldFromSummaryData{
    for (GCField * field in self.summaryData) {
        GCActivitySummaryValue * value = self.summaryData[field];
        if (field.fieldFlag!= gcFieldFlagNone) {
            GCNumberWithUnit * nu = value.numberWithUnit;
            [self setSummaryField:field.fieldFlag with:nu];
            self.flags |= field.fieldFlag;
        }
    }
}

-(void)updateSummaryData:(NSDictionary<GCField *,GCActivitySummaryValue *> *)summary{
    if( self.summaryData == nil){
        self.summaryData = summary;
    }else{
        self.summaryData = summary;
    }
    [self updateSummaryFieldFromSummaryData];
}

-(void)updateMetaData:(NSDictionary<NSString *,GCActivityMetaValue *> *)meta{
    if( self.metaData == nil){
        self.metaData = meta;
    }else{
        self.metaData = meta;
    }
    [self skipAlways];
}

-(void)updateActivityTypeFromMetaData{
    GCActivityMetaValue * activityTypeMeta = self.metaData[GC_META_ACTIVITYTYPE];
    if( activityTypeMeta ){
        GCActivityType * activityType = [GCActivityType activityTypeForKey:activityTypeMeta.key];
        if( activityType ) {
            self.activityTypeDetail = activityType;
        }   
    }
}

-(BOOL)skipAlways{
    GCActivityMetaValue * val = self.metaData[GC_IGNORE_SKIP_ALWAYS];
    _skipAlwaysFlag = false;
    if (val) {
        _skipAlwaysFlag = true;
        return [val.display isEqualToString:@"true"];
    }
    return FALSE;
}

-(void)setSkipAlways:(BOOL)skipAlways{
    if( skipAlways ){
        _skipAlwaysFlag = true;
        GCActivityMetaValue * val = [GCActivityMetaValue activityMetaValueForDisplay:@"true" andField:GC_IGNORE_SKIP_ALWAYS];
        [self addEntriesToMetaData:@{ GC_IGNORE_SKIP_ALWAYS : val}];
    }else{
        _skipAlwaysFlag = false;
        if( self.metaData[GC_IGNORE_SKIP_ALWAYS]){
            self.metaData = [self.metaData dictionaryByRemovingObjectsForKeys:@[ GC_IGNORE_SKIP_ALWAYS ] ];
        }
        
    }
}

-(BOOL)ignoreForStats:(gcIgnoreMode)mode{
    if( _skipAlwaysFlag ){
        return true;
    }
    switch (mode) {
        case gcIgnoreModeActivityFocus:
            return [self.activityType isEqualToString:GC_TYPE_MULTISPORT] || [self.activityType isEqualToString:GC_TYPE_DAY];
        case gcIgnoreModeDayFocus:
            return ![self.activityType isEqualToString:GC_TYPE_DAY];
    }
    return false;
}

-(BOOL)isSkiActivity{
    return self.activityTypeDetail.isSki;
}
@end
