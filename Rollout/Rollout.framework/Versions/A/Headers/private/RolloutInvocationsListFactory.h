//
//  RolloutInvocationsListFactory.h
//  Rollout
//
//  Created by Sergey Ilyevsky on 9/17/14.
//  Copyright (c) 2014 DeDoCo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RolloutInvocationsList.h"

@class RolloutActionProducer;
@class RolloutConfiguration;
@class RolloutErrors;
@class RolloutTypeWrapperFactory;
@class RolloutTypeWrapperGeneratorFactory;

@protocol RolloutInvocationsListFactory
- (RolloutInvocationsList *)invocationsListForInstanceMethod:(NSString *)method forClass:(NSString*) clazz;
- (RolloutInvocationsList *)invocationsListForClassMethod:(NSString *)method forClass:(NSString*) clazz;
- (RolloutInvocationsList *)invocationsListFromConfiguration:(NSArray*)configuration;

- (void) markInstanceSwizzle:(NSString*) method forClass:(NSString*) clazz;
- (void) markClassSwizzle:(NSString*) method forClass:(NSString*) clazz;

- (BOOL) shouldSetupInstanceSwizzle:(NSString*) method forClass:(NSString*) clazz;
- (BOOL) shouldSetupClassSwizzle:(NSString*) method forClass:(NSString*) clazz;
@end

@interface RolloutInvocationsListFactory : NSObject <RolloutInvocationsListFactory>

- (instancetype)initWithConfiguration:(RolloutConfiguration *)conf withProducer:(RolloutActionProducer *)producer rolloutErrors:(RolloutErrors *)rolloutErrors typeWrapperFactory:(RolloutTypeWrapperFactory *)typeWrapperFactory typeWrapperGeneratorFactory:(RolloutTypeWrapperGeneratorFactory *)typeWrapperGeneratorFactory;

@end
