//
//  Rollout SDK version 0.10.2, Build 129
//
//  Copyright (c) 2014 Rollout.io. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RolloutOptions.h"

@interface Rollout : NSObject

+(void) setupWithDebug: (BOOL) debug options:(RolloutOptions*)options;
+(void) setupWithDebug: (BOOL) debug;
+(void) setup: (NSString*) projectId debug: (BOOL) debug __attribute__ ((deprecated));
+(BOOL) rolloutDisabled;
+ (void)setRolloutDisabled:(BOOL)value;

@end

