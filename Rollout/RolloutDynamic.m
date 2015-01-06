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

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

static id<RolloutInvocationsListFactory> _invocationsListFactory;

#define ROLLOUT_SWIZZLE_DEFINITION_AREA
   #include "RolloutSwizzlerDynamic.include"

#undef ROLLOUT_SWIZZLE_DEFINITION_AREA

#pragma clang diagnostic pop

@implementation RolloutDynamic {
    RolloutErrors *_rolloutErrors;
}

- (instancetype)initWithInvocationsListFactory:(id <RolloutInvocationsListFactory>)invocationsListFactory rolloutErrors:(RolloutErrors *)rolloutErrors
{
    static BOOL initialized;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [rolloutErrors assert:!initialized error:RolloutErrors_RolloutDynamic_alreadyInitialized details:nil];
        initialized = YES;
    });

    if(self = [super init]) {
        _invocationsListFactory = invocationsListFactory;
        _rolloutErrors = rolloutErrors;
    }
    return self;
}

-(instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (void) onApplicationStarts{
}

#ifndef ROLLOUT_TRANSPARENT
-(void)setup {
    [_rolloutErrors assert:_invocationsListFactory != nil error:RolloutErrors_RolloutDynamic_invocationsListFactoryNotInitialized details:nil];

    #pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        
#define ROLLOUT_SWIZZLE_ACT_AREA 1
   #include "RolloutSwizzlerDynamic.include"
#undef ROLLOUT_SWIZZLE_ACT_AREA
        
#pragma clang diagnostic pop
}
#endif
@end


