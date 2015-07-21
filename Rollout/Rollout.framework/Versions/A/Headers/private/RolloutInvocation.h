//
// Created by Sergey Ilyevsky on 6/25/15.
// Copyright (c) 2015 DeDoCo. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RolloutTypeWrapper;
@class RolloutMethodId;
@class RolloutConfiguration;
@class RolloutInvocationsListFactory;


@interface RolloutInvocation : NSObject
- (instancetype)initWithConfiguration:(RolloutConfiguration *)configuration listsFactory:(RolloutInvocationsListFactory *)listsFactory;


- (RolloutTypeWrapper *)invokeWithMethodId:(RolloutMethodId *)methodId originalArguments:(NSArray*)originalArguments originalMethodWrapper:(RolloutTypeWrapper * (^)(NSArray *))originalMethodWrapper;

@property (nonatomic) BOOL rolloutDisabled;

@end
