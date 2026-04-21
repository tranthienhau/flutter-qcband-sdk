#import "QCBandCommandQueue.h"

@interface QCBandCommandQueue ()
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@end

@implementation QCBandCommandQueue

+ (instancetype)shared {
    static QCBandCommandQueue *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[QCBandCommandQueue alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _operationQueue = [[NSOperationQueue alloc] init];
        _operationQueue.maxConcurrentOperationCount = 1;
        _operationQueue.name = @"com.tranthienhau.qcband.commandQueue";
    }
    return self;
}

- (void)enqueue:(QCBandCommandBlock)command
     completion:(void (^)(id _Nullable, NSError *_Nullable))completion {

    NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        __block id resultValue = nil;
        __block NSError *resultError = nil;

        dispatch_async(dispatch_get_main_queue(), ^{
            command(^(id _Nullable result, NSError *_Nullable error) {
                resultValue = result;
                resultError = error;
                dispatch_semaphore_signal(semaphore);
            });
        });

        long timeout = dispatch_semaphore_wait(
            semaphore,
            dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)
        );

        if (timeout != 0) {
            resultError = [NSError errorWithDomain:@"QCBandCommandQueue"
                                              code:-999
                                          userInfo:@{NSLocalizedDescriptionKey: @"Command timed out after 10s"}];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(resultValue, resultError);
        });
    }];

    [self.operationQueue addOperation:op];
}

- (void)cancelAll {
    [self.operationQueue cancelAllOperations];
}

@end
