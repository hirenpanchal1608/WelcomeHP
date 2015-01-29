//
//  RolloutInvocation.h
//  MoMe
//
//  Created by eyal keren on 5/21/14.
//  Copyright (c) 2014 eyal keren. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RolloutTypeWrapper.h"

@class RolloutActions;
@class RolloutActionProducer;
@class RolloutErrors;
@class RolloutTypeWrapperFactory;
@class RolloutTypeWrapperGeneratorFactory;

@protocol RolloutErrors;
#define ROLLOUT_TYPE_WITH_SIZE(s) __rollout_type_ ## s
#define CREATE_ROLLOUT_TYPE_WITH_SIZE(s) typedef struct { unsigned char buff[s];} ROLLOUT_TYPE_WITH_SIZE(s);

typedef enum{
    RolloutInvocationTypeNormal = 0,
    RolloutInvocationTypeTryCatch,
    RolloutInvocationTypeDisable,
    RolloutInvocationTypesCount
} RolloutInvocationType;

typedef enum {
    RolloutInvocation_ForceMainThreadType_off,
    RolloutInvocation_ForceMainThreadType_sync,
    RolloutInvocation_ForceMainThreadType_async,
    RolloutInvocation_ForceMainThreadTypesCount
} RolloutInvocation_ForceMainThreadType;

@interface RolloutInvocation : NSObject

- (id)initWithConfiguration:(NSDictionary *)configuration actionProducer:(RolloutActionProducer *)actionProducer rolloutErrors:(id<RolloutErrors>)rolloutErrors typeWrapperFactory:(RolloutTypeWrapperFactory *)typeWrapperFactory typeWrapperGeneratorFactory:(RolloutTypeWrapperGeneratorFactory *)typeWrapperGeneratorFactory;

@property (nonatomic, readonly) NSDictionary *configuration;
@property (nonatomic, readonly) RolloutActions *actions;
@property (nonatomic, readonly) RolloutInvocationType type;
@property (nonatomic, readonly) RolloutInvocation_ForceMainThreadType forceMainThreadType;

-(BOOL)satisfiesDynamicData:(RolloutInvocationDynamicData*)dynamicData;

- (void) runBefore;
- (void) runAfterExceptionCaught;

@property (nonatomic) NSArray *originalArguments;
@property (nonatomic) RolloutTypeWrapper* originalReturnValue;


-(NSArray*)tweakedArguments;
-(RolloutTypeWrapper*)conditionalReturnValue;
-(RolloutTypeWrapper *)defaultReturnValue;

@end

