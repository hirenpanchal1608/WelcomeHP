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
#import <Rollout/private/RolloutErrors.h>
#import <Rollout/private/RolloutMethodId.h>
#import <objc/objc.h>


@implementation RolloutDynamic {
}

- (instancetype)initWithInvocation:(RolloutInvocation *)invocation
{
    if(self = [super init]) {
        _invocation = invocation;
    }
    return self;
}

-(instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

@end
