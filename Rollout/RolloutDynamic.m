//
//  RolloutDynamic.m
//  MoMe
//
//  Created by eyal keren on 3/9/14.
//  Copyright (c) 2014 eyal keren. All rights reserved.
//

#import <Rollout/private/RolloutDynamic.h>
#import <Rollout/private/RolloutInvocation.h>
#import <Rollout/private/RolloutTypeWrapper.h>
#import <Rollout/private/RolloutInvocationsListFactory.h>
#import <Rollout/private/RolloutErrors.h>
#import <Rollout/private/RolloutMethodId.h>
#import <Rollout/private/RolloutConfiguration.h>
#import <objc/objc.h>


@implementation RolloutDynamic {
    id<RolloutInvocationsListFactory> _invocationsListFactory;
    RolloutConfiguration *_configuration;
}

- (instancetype)initWithInvocationsListFactory:(id <RolloutInvocationsListFactory>)invocationsListFactory configuration:(RolloutConfiguration *)configuration
{
    if(self = [super init]) {
        _invocationsListFactory = invocationsListFactory;
        _configuration = configuration;
    }
    return self;
}

-(instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

@end

#include "RolloutSwizzlerDynamic.include"
