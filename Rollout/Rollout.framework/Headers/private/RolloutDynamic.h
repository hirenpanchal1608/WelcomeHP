//
//  RolloutDynamic.h
//  MoMe
//
//  Created by eyal keren on 3/9/14.
//  Copyright (c) 2014 eyal keren. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol RolloutInvocationsListFactory;
@class RolloutErrors;

@protocol RolloutDynamic
- (instancetype)initWithInvocationsListFactory:(id<RolloutInvocationsListFactory>)invocationsListFactory rolloutErrors:(RolloutErrors *)rolloutErrors;
- (void) setup;
- (void) onApplicationStarts;
@end

@interface RolloutDynamic : NSObject <RolloutDynamic>
@end
