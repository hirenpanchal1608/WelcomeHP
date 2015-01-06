//
// Created by Sergey Ilyevsky on 10/6/14.
// Copyright (c) 2014 DeDoCo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RolloutInvocation.h"

@class RolloutActionProducer;
@protocol RolloutErrors;
@class RolloutTypeWrapperFactory;
@class RolloutTypeWrapperGeneratorFactory;


@interface RolloutInvocationsList : NSObject

- (id)initWithConfiguration:(NSArray *)configuration actionsProducer:(RolloutActionProducer *)actionProducer rolloutErrors:(id <RolloutErrors>)rolloutErrors typeWrapperFactory:(RolloutTypeWrapperFactory *)typeWrapperFactory typeWrapperGeneratorFactory:(RolloutTypeWrapperGeneratorFactory *)typeWrapperGeneratorFactory;
-(RolloutInvocation *)invocationForArguments:(NSArray *)arguments;

@end