//  MIT Licence
//
//  Created on 26/03/2016.
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

//NEWTRACKFIELD  avoid gcFieldFlag if possible
typedef NS_ENUM(NSUInteger, gcFieldFlag) {
    gcFieldFlagNone                     = 0,
    gcFieldFlagSumDistance              = 1,
    gcFieldFlagSumDuration              = 1 << 1,
    gcFieldFlagWeightedMeanHeartRate    = 1 << 2,
    gcFieldFlagWeightedMeanSpeed        = 1 << 3,
    gcFieldFlagCadence                  = 1 << 4,
    gcFieldFlagAltitudeMeters           = 1 << 5,
    gcFieldFlagPower                    = 1 << 6,
    gcFieldFlagSumStrokes               = 1 << 7,
    gcFieldFlagSumSwolf                 = 1 << 8,
    gcFieldFlagSumEfficiency            = 1 << 9,
    gcFieldFlagVerticalOscillation      = 1 << 10,
    gcFieldFlagGroundContactTime        = 1 << 11,
    gcFieldFlagTennisShots              = 1 << 12,
    gcFieldFlagTennisRegularity         = 1 << 13,
    gcFieldFlagTennisEnergy             = 1 << 14,
    gcFieldFlagTennisPower              = 1 << 15,
    gcFieldFlagSumStep                  = 1 << 16
};

// Calculated Fields.
typedef NS_OPTIONS(NSUInteger, gcCalcField) {
    gcCalcFieldSimple,
    gcCalcFieldBestRolling,
};

typedef NS_OPTIONS(NSUInteger, gcTrackEventType) {
    gcTrackEventTypeNone = 0,
    gcTrackEventTypeStart = 1,
    gcTrackEventTypeStop = 2,
    gcTrackEventTypeMarker = 3,
    gcTrackEventTypeStopAll = 4
};

/*
fit_example.h:#define FIT_EVENT_TYPE_INVALID                                                   FIT_ENUM_INVALID
fit_example.h:#define FIT_EVENT_TYPE_START                                                     ((FIT_EVENT_TYPE)0)
fit_example.h:#define FIT_EVENT_TYPE_STOP                                                      ((FIT_EVENT_TYPE)1)
fit_example.h:#define FIT_EVENT_TYPE_CONSECUTIVE_DEPRECIATED                                   ((FIT_EVENT_TYPE)2)
fit_example.h:#define FIT_EVENT_TYPE_MARKER                                                    ((FIT_EVENT_TYPE)3)
fit_example.h:#define FIT_EVENT_TYPE_STOP_ALL                                                  ((FIT_EVENT_TYPE)4)
fit_example.h:#define FIT_EVENT_TYPE_BEGIN_DEPRECIATED                                         ((FIT_EVENT_TYPE)5)
fit_example.h:#define FIT_EVENT_TYPE_END_DEPRECIATED                                           ((FIT_EVENT_TYPE)6)
fit_example.h:#define FIT_EVENT_TYPE_END_ALL_DEPRECIATED                                       ((FIT_EVENT_TYPE)7)
fit_example.h:#define FIT_EVENT_TYPE_STOP_DISABLE                                              ((FIT_EVENT_TYPE)8)
fit_example.h:#define FIT_EVENT_TYPE_STOP_DISABLE_ALL                                          ((FIT_EVENT_TYPE)9)
fit_example.h:#define FIT_EVENT_TYPE_COUNT                                                     10
*/

// HealthKit Field Map
//    gcFieldFlagDistance                 "SumDistance"         HKQuantityTypeIdentifierDistanceWalkingRunning
//    gcFieldFlagCadence                  "SumStep"             HKQuantityTypeIdentifierStepCount
//    gcFieldFlagAltitudeMeters           "SumFloorClimbed",    HKQuantityTypeIdentifierFlightsClimbed
//    gcFieldFlagPower                    "SumDistanceCycling"  HKQuantityTypeIdentifierDistanceCycling
//    gcFieldFlagWeightedMeanSpeed        "WeightedMeanSpeed"   Calculated

typedef NS_ENUM(NSUInteger, gcSwimStrokeType) {
    gcSwimStrokeFree        = 0,
    gcSwimStrokeBack        = 1,
    gcSwimStrokeBreast      = 2,
    gcSwimStrokeButterfly   = 3,
    gcSwimStrokeOther       = 4,
    gcSwimStrokeMixed       = 5,
    gcSwimStrokeEnd         = 6
};

typedef NS_ENUM(NSUInteger, gcIntensityLevel) {
    gcIntensityInactive,
    gcIntensityLightlyActive,
    gcIntensityModeratelyActive,
    gcIntensityVeryActive
};

extern NSString * GC_TYPE_RUNNING;
extern NSString * GC_TYPE_CYCLING;
extern NSString * GC_TYPE_SWIMMING;
extern NSString * GC_TYPE_HIKING;
extern NSString * GC_TYPE_FITNESS;
extern NSString * GC_TYPE_WALKING;
extern NSString * GC_TYPE_OTHER;
extern NSString * GC_TYPE_ALL;

extern NSString * GC_TYPE_DAY;
extern NSString * GC_TYPE_TENNIS;

extern NSString * GC_TYPE_MULTISPORT;
extern NSString * GC_TYPE_TRANSITION;

extern NSString * GC_TYPE_WINTER_SPORTS;
extern NSString * GC_TYPE_SKI_XC;
extern NSString * GC_TYPE_SKI_DOWN;
extern NSString * GC_TYPE_SKI_BACK;
extern NSString * GC_TYPE_INDOOR_ROWING;
extern NSString * GC_TYPE_ROWING;

extern NSString * GC_TYPE_UNCATEGORIZED;

extern NSString * GC_META_DEVICE;
extern NSString * GC_META_EVENTTYPE;
extern NSString * GC_META_DESCRIPTION;
extern NSString * GC_META_ACTIVITYTYPE;
extern NSString * GC_META_SERVICE;

extern NSString * STOREUNIT_SPEED;
extern NSString * STOREUNIT_DISTANCE;
extern NSString * STOREUNIT_ALTITUDE;
extern NSString * STOREUNIT_ELAPSED;
extern NSString * STOREUNIT_TEMPERATURE;
extern NSString * STOREUNIT_HEARTRATE;

extern NSString * INTERNAL_PREFIX;
extern NSString * INTERNAL_DIRECT_STROKE_TYPE;
extern NSString * INTERNAL_TRACK_EVENT_TYPE;


extern NSString * CALC_PREFIX;
extern NSString * CALC_BESTROLLING_PREFIX;

extern NSString * CALC_ALTITUDE_GAIN         ;
extern NSString * CALC_ALTITUDE_LOSS         ;
extern NSString * CALC_NORMALIZED_POWER      ;
extern NSString * CALC_NONZERO_POWER         ;
extern NSString * CALC_METABOLIC_EFFICIENCY  ;
extern NSString * CALC_EFFICIENCY_FACTOR     ;
extern NSString * CALC_ENERGY                ;
extern NSString * CALC_STRIDE_LENGTH         ;
extern NSString * CALC_DEVELOPMENT           ;
extern NSString * CALC_ELEVATION_GRADIENT    ;
extern NSString * CALC_VERTICAL_SPEED          ;
extern NSString * CALC_ASCENT_SPEED            ;
extern NSString * CALC_DESCENT_SPEED           ;
extern NSString * CALC_MAX_ASCENT_SPEED        ;
extern NSString * CALC_MAX_DESCENT_SPEED       ;
extern NSString * CALC_10SEC_SPEED             ;
extern NSString * CALC_LAP_SCALED_SPEED        ;
extern NSString * CALC_ACCUMULATED_SPEED       ;
