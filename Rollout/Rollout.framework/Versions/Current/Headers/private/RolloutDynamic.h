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
@class RolloutConfiguration;

@protocol RolloutDynamic
- (instancetype)initWithInvocationsListFactory:(id <RolloutInvocationsListFactory>)invocationsListFactory configuration:(RolloutConfiguration *)configuration;
@end

@interface RolloutDynamic : NSObject <RolloutDynamic>
@end
