//  MIT Licence
//
//  Created on 17/11/2012.
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

#import "GCViewConfig.h"
#import "GCDerivedDataSerie.h"

@class GCHistoryPerformanceAnalysis;
@class GCTrackStats;
@class GCHistoryFieldDataSerie;
@class GCStatsDerivedHistory;
@class GCStatsCalendarAggregationConfig;
@class GCHistoryAggregatedStats;
@class GCStatsMultiFieldConfig;

@interface GCSimpleGraphCachedDataSource (Templates)
+(GCSimpleGraphCachedDataSource*)dataSourceWithStandardColors;
+(GCSimpleGraphCachedDataSource*)scatterPlotCacheFrom:(GCHistoryFieldDataSerie *) scatterStats;
+(GCSimpleGraphCachedDataSource*)fieldHistoryCacheFrom:(GCHistoryFieldDataSerie*)history andMovingAverage:(NSUInteger)samples;
+(GCSimpleGraphCachedDataSource*)historyView:(GCHistoryFieldDataSerie*)fieldserie calendarConfig:(GCStatsCalendarAggregationConfig*)aUnit graphChoice:(gcGraphChoice)graphChoice after:(NSDate*)date;
+(GCSimpleGraphCachedDataSource*)fieldHistoryHistogramFrom:(GCHistoryFieldDataSerie*)history width:(CGFloat)width;
+(GCSimpleGraphCachedDataSource*)aggregatedView:(GCHistoryAggregatedStats*)aggregatedStats
                                          field:(GCField*)field
                               multiFieldConfig:(GCStatsMultiFieldConfig*)multiFieldConfig
                                          after:(NSDate*)date;
+(GCSimpleGraphCachedDataSource*)performanceAnalysis:(GCHistoryPerformanceAnalysis*)perfAnalysis width:(CGFloat)width;
+(GCSimpleGraphCachedDataSource*)derivedData:(GCField*)field forDate:(NSDate*)date width:(CGFloat)width;

+(GCSimpleGraphCachedDataSource*)trackFieldFrom:(GCTrackStats*)trackStats;
+(GCSimpleGraphCachedDataSource*)derivedHist:(GCStatsDerivedHistory*)diffMode field:(GCField*)field series:(GCStatsSerieOfSerieWithUnits*)serieOfSeries width:(CGFloat)width;
+(GCSimpleGraphCachedDataSource*)derivedDataSingleHighlighted:(GCField*)fieldInput period:(gcDerivedPeriod)period forDate:(NSDate*)date addLegendTo:(NSMutableArray*)legend width:(CGFloat)width;

@end
