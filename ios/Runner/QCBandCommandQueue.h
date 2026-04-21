#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^QCBandCommandBlock)(void (^completion)(id _Nullable result, NSError *_Nullable error));

/// Serial command queue for QCBandSDK.
/// The SDK requires commands to be executed one at a time;
/// concurrent commands cause later ones to silently fail.
@interface QCBandCommandQueue : NSObject

+ (instancetype)shared;

/// Enqueue a command. The command block receives a completion handler
/// that MUST be called when the command finishes (success or failure).
/// Timeout: 10 seconds per command to prevent deadlocks.
- (void)enqueue:(QCBandCommandBlock)command
     completion:(void (^)(id _Nullable result, NSError *_Nullable error))completion;

/// Cancel all pending commands.
- (void)cancelAll;

@end

NS_ASSUME_NONNULL_END
