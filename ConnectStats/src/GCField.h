//  MIT Licence
//
//  Created on 01/01/2016.
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

#import <Foundation/Foundation.h>
#import "GCFields.h"

@class GCFieldCache;

@interface GCField : NSObject<NSCopying,NSSecureCoding>

@property (nonatomic,readonly) NSString * key;
@property (nonatomic,readonly) NSString * activityType;
@property (nonatomic,readonly) gcFieldFlag fieldFlag;

+(GCFieldCache*)fieldCache;
+(void)setFieldCache:(GCFieldCache*)cache;

/**
 Fields from different type of inputs
 @param any can be NSString key, NSNumber gcFieldFlag or GCField
 @return NSArray<GCField*> if input is NSArray else GCField
 */
+(GCField*)fieldForKey:(NSString*)field andActivityType:(NSString*)activityType;
+(GCField*)fieldForFlag:(gcFieldFlag)fieldFlag andActivityType:(NSString *)activityType;

-(BOOL)isEqualToField:(GCField*)other;
-(NSComparisonResult)compare:(GCField*)other;
/// Similar to isEqualToField but also matches if one of the field is of type all and same key
/// @param other field to compare
-(BOOL)matchesField:(GCField*)other;

-(BOOL)isNoisy;
-(BOOL)canSum;
-(BOOL)validForGraph;
-(BOOL)isWeightedAverage;
-(BOOL)isMax;
-(BOOL)isMin;
-(BOOL)isSpeedOrPace;
-(BOOL)isZeroValid;
-(BOOL)isValidForActivityType:(NSString*)activityType;

/**
 Corresponding Speed or Pace field. If not speed or pace return nil

 @return complement field
 */
-(GCField*)correspondingPaceOrSpeedField;
-(GCField*)correspondingMaxField;
-(GCField*)correspondingWeightedMeanField;
-(GCField*)correspondingMinField;
-(GCField*)correspondingFieldTypeAll;
-(GCField*)correspondingFieldForActivityType:(NSString*)activityType;
-(GCField*)correspondingBestRollingField;
-(GCField*)correspondingUnderlyingField;

-(NSString*)displayName;
-(NSString*)displayNameAndUnits;
-(NSString*)displayNameWithUnits:(GCUnit*)unit;
-(NSString*)displayNameWithPrimary:(GCField*)primary;
-(GCUnit*)unit;

-(NSString*)category;
-(NSInteger)sortOrder;

-(NSArray<GCField*>*)relatedFields;

-(BOOL)isHealthField;
-(BOOL)isCalculatedField;
-(BOOL)isInternal;
-(BOOL)isBestRollingField;

-(BOOL)hasSuffix:(NSString*)suf;
-(BOOL)hasPrefix:(NSString*)pref;

+(NSString*)displayNameImpliedByFieldKey:(NSString *)fieldKey;

@end

NS_INLINE BOOL RZNilOrEqualToField(GCField* a, GCField* b) { return ( ( (a == nil) && (b == nil) ) || (b != nil && [a isEqualToField:b]) ); };
