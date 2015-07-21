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
@class RolloutInvocation;

@protocol RolloutDynamic
- (instancetype)initWithInvocation:(RolloutInvocation *)invocation;
@end

@interface RolloutDynamic : NSObject <RolloutDynamic> {
    RolloutInvocation *_invocation;
}
@end

