#import "QCBandPlugin.h"
#import "QCBandCommandQueue.h"

static NSString *const kMethodChannel = @"com.tranthienhau.qcband/methods";
static NSString *const kEventChannel  = @"com.tranthienhau.qcband/events";

@interface QCBandPlugin ()
@property (nonatomic, strong) FlutterEventSink eventSink;
@property (nonatomic, strong) CBPeripheral *connectedPeripheral;
@property (nonatomic, strong) NSArray<QCPeripheral *> *scannedPeripherals;
@property (nonatomic, strong) NSTimer *hrHoldTimer;
@end

@implementation QCBandPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    QCBandPlugin *instance = [[QCBandPlugin alloc] init];

    FlutterMethodChannel *methodChannel =
        [FlutterMethodChannel methodChannelWithName:kMethodChannel
                                    binaryMessenger:registrar.messenger];
    [registrar addMethodCallDelegate:instance channel:methodChannel];

    FlutterEventChannel *eventChannel =
        [FlutterEventChannel eventChannelWithName:kEventChannel
                                  binaryMessenger:registrar.messenger];
    [eventChannel setStreamHandler:instance];

    // Set up BLE delegate
    [QCBleCentralManager shareInstance].delegate = instance;

    // Set up SDK manager callbacks
    [instance setupSDKCallbacks];
}

#pragma mark - SDK Callbacks

- (void)setupSDKCallbacks {
    __weak typeof(self) weakSelf = self;

    [QCSDKManager shareInstance].realTimeHeartRate = ^(NSInteger hr) {
        [weakSelf sendEvent:@{
            @"event": @"realTimeHeartRate",
            @"bpm": @(hr),
        }];
    };

    [QCSDKManager shareInstance].currentBatteryInfo = ^(NSInteger battery, BOOL charging) {
        [weakSelf sendEvent:@{
            @"event": @"batteryUpdate",
            @"level": @(battery),
            @"charging": @(charging),
        }];
    };

    [QCSDKManager shareInstance].currentStepInfo = ^(NSInteger step, NSInteger calorie, NSInteger distance) {
        [weakSelf sendEvent:@{
            @"event": @"stepUpdate",
            @"steps": @(step),
            @"calories": @((double)calorie),
            @"distance": @(distance),
            @"activeMinutes": @(0),
        }];
    };
}

#pragma mark - FlutterStreamHandler

- (FlutterError *)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
    self.eventSink = events;
    return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments {
    self.eventSink = nil;
    return nil;
}

- (void)sendEvent:(NSDictionary *)event {
    if (self.eventSink) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.eventSink) {
                self.eventSink(event);
            }
        });
    }
}

#pragma mark - FlutterPlugin (MethodChannel)

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSString *method = call.method;
    NSDictionary *args = call.arguments;

    if ([method isEqualToString:@"startScan"]) {
        [self handleStartScan:args result:result];
    } else if ([method isEqualToString:@"stopScan"]) {
        [self handleStopScan:result];
    } else if ([method isEqualToString:@"connect"]) {
        [self handleConnect:args result:result];
    } else if ([method isEqualToString:@"disconnect"]) {
        [self handleDisconnect:result];
    } else if ([method isEqualToString:@"syncTime"]) {
        [self handleSyncTime:result];
    } else if ([method isEqualToString:@"readBattery"]) {
        [self handleReadBattery:result];
    } else if ([method isEqualToString:@"getDeviceVersion"]) {
        [self handleGetDeviceVersion:result];
    } else if ([method isEqualToString:@"getCurrentSport"]) {
        [self handleGetCurrentSport:result];
    } else if ([method isEqualToString:@"getSleepData"]) {
        [self handleGetSleepData:args result:result];
    } else if ([method isEqualToString:@"getBloodOxygen"]) {
        [self handleGetBloodOxygen:args result:result];
    } else if ([method isEqualToString:@"startRealTimeHR"]) {
        [self handleStartRealTimeHR:result];
    } else if ([method isEqualToString:@"stopRealTimeHR"]) {
        [self handleStopRealTimeHR:result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

#pragma mark - Scan

- (void)handleStartScan:(NSDictionary *)args result:(FlutterResult)result {
    self.scannedPeripherals = @[];
    [[QCBleCentralManager shareInstance] scanWithServices:@[QCBANDSDKSERVERUUID1, QCBANDSDKSERVERUUID2]];
    result(nil);
}

- (void)handleStopScan:(FlutterResult)result {
    [[QCBleCentralManager shareInstance] stopScan];
    result(nil);
}

#pragma mark - Connection

- (void)handleConnect:(NSDictionary *)args result:(FlutterResult)result {
    NSString *peripheralId = args[@"peripheralId"];

    CBPeripheral *target = nil;
    for (QCPeripheral *qcp in self.scannedPeripherals) {
        if ([qcp.peripheral.identifier.UUIDString isEqualToString:peripheralId]) {
            target = qcp.peripheral;
            break;
        }
    }

    if (!target) {
        result([FlutterError errorWithCode:@"NOT_FOUND"
                                   message:@"Peripheral not found in scan results"
                                   details:peripheralId]);
        return;
    }

    [self sendEvent:@{@"event": @"connectionState", @"state": @"connecting"}];

    // Add peripheral to SDK manager first, then connect
    [[QCSDKManager shareInstance] addPeripheral:target finished:^(BOOL success) {
        if (success) {
            [[QCBleCentralManager shareInstance] connect:target];
        } else {
            result([FlutterError errorWithCode:@"ADD_FAILED"
                                       message:@"Failed to add peripheral to SDK manager"
                                       details:nil]);
        }
    }];

    self.connectedPeripheral = target;
    result(nil);
}

- (void)handleDisconnect:(FlutterResult)result {
    if (self.connectedPeripheral) {
        [[QCBleCentralManager shareInstance] disconnect:self.connectedPeripheral];
        [[QCSDKManager shareInstance] removePeripheral:self.connectedPeripheral];
    }
    [self.hrHoldTimer invalidate];
    self.hrHoldTimer = nil;
    self.connectedPeripheral = nil;
    [[QCBandCommandQueue shared] cancelAll];
    result(nil);
}

#pragma mark - Time Sync

- (void)handleSyncTime:(FlutterResult)result {
    [[QCBandCommandQueue shared] enqueue:^(void (^completion)(id, NSError *)) {
        [QCSDKCmdCreator setTime:[NSDate date]
                         success:^(NSDictionary *featureList) {
            // Convert feature dictionary to Flutter-friendly format
            NSMutableDictionary *features = [NSMutableDictionary dictionary];

            if (featureList[@"QCBandFeatureBloodOxygen"]) {
                features[@"bloodOxygen"] = @([featureList[@"QCBandFeatureBloodOxygen"] boolValue]);
            }
            if (featureList[@"QCBandFeatureBloodPressure"]) {
                features[@"bloodPressure"] = @([featureList[@"QCBandFeatureBloodPressure"] boolValue]);
            }
            if (featureList[@"QCBandFeatureTemperature"]) {
                features[@"temperature"] = @([featureList[@"QCBandFeatureTemperature"] boolValue]);
            }
            if (featureList[@"QCBandFeatureNewSleepProtocol"]) {
                features[@"newSleepProtocol"] = @([featureList[@"QCBandFeatureNewSleepProtocol"] boolValue]);
            }
            if (featureList[@"QCBandFeatureManualHeartRate"]) {
                features[@"manualHeartRate"] = @([featureList[@"QCBandFeatureManualHeartRate"] boolValue]);
            }
            if (featureList[@"QCBandFeatureAppManual"]) {
                features[@"appManual"] = @([featureList[@"QCBandFeatureAppManual"] boolValue]);
            }

            completion(features, nil);
        }
                          failed:^{
            completion(nil, [NSError errorWithDomain:@"QCBand"
                                                code:-1
                                            userInfo:@{NSLocalizedDescriptionKey: @"syncTime failed"}]);
        }];
    } completion:^(id result_, NSError *error) {
        if (error) {
            result([FlutterError errorWithCode:@"SYNC_FAILED"
                                       message:error.localizedDescription
                                       details:nil]);
        } else {
            result(result_);
        }
    }];
}

#pragma mark - Battery

- (void)handleReadBattery:(FlutterResult)result {
    [[QCBandCommandQueue shared] enqueue:^(void (^completion)(id, NSError *)) {
        [QCSDKCmdCreator readBatterySuccess:^(int battery, BOOL charging) {
            completion(@{
                @"level": @(battery),
                @"charging": @(charging),
            }, nil);
        } failed:^{
            completion(nil, [NSError errorWithDomain:@"QCBand"
                                                code:-1
                                            userInfo:@{NSLocalizedDescriptionKey: @"readBattery failed"}]);
        }];
    } completion:^(id result_, NSError *error) {
        if (error) {
            result([FlutterError errorWithCode:@"BATTERY_FAILED"
                                       message:error.localizedDescription
                                       details:nil]);
        } else {
            result(result_);
        }
    }];
}

#pragma mark - Device Version

- (void)handleGetDeviceVersion:(FlutterResult)result {
    [[QCBandCommandQueue shared] enqueue:^(void (^completion)(id, NSError *)) {
        [QCSDKCmdCreator getDeviceSoftAndHardVersionSuccess:^(NSString *hardVersion, NSString *softVersion) {
            completion(@{
                @"hardware": hardVersion ?: @"",
                @"software": softVersion ?: @"",
            }, nil);
        } fail:^{
            completion(nil, [NSError errorWithDomain:@"QCBand"
                                                code:-1
                                            userInfo:@{NSLocalizedDescriptionKey: @"getDeviceVersion failed"}]);
        }];
    } completion:^(id result_, NSError *error) {
        if (error) {
            result([FlutterError errorWithCode:@"VERSION_FAILED"
                                       message:error.localizedDescription
                                       details:nil]);
        } else {
            result(result_);
        }
    }];
}

#pragma mark - Sport Data

- (void)handleGetCurrentSport:(FlutterResult)result {
    [[QCBandCommandQueue shared] enqueue:^(void (^completion)(id, NSError *)) {
        [QCSDKCmdCreator getCurrentSportSucess:^(QCSportModel *sport) {
            completion(@{
                @"steps": @(sport.totalStepCount),
                @"calories": @(sport.calories),
                @"distance": @(sport.distance),
                @"activeMinutes": @(sport.activeTime),
            }, nil);
        } failed:^{
            completion(nil, [NSError errorWithDomain:@"QCBand"
                                                code:-1
                                            userInfo:@{NSLocalizedDescriptionKey: @"getCurrentSport failed"}]);
        }];
    } completion:^(id result_, NSError *error) {
        if (error) {
            result([FlutterError errorWithCode:@"SPORT_FAILED"
                                       message:error.localizedDescription
                                       details:nil]);
        } else {
            result(result_);
        }
    }];
}

#pragma mark - Sleep Data

- (void)handleGetSleepData:(NSDictionary *)args result:(FlutterResult)result {
    NSInteger dayIndex = [args[@"dayIndex"] integerValue];

    [[QCBandCommandQueue shared] enqueue:^(void (^completion)(id, NSError *)) {
        [QCSDKCmdCreator getSleepDetailDataByDay:dayIndex
                                      sleepDatas:^(NSArray<QCSleepModel *> *sleeps) {
            NSMutableArray *segments = [NSMutableArray array];
            for (QCSleepModel *sleep in sleeps) {
                // Map SDK sleep type to our enum index
                // SDK: 0=none, 1=awake, 2=light, 3=deep, 4=rem, 5=unworn
                [segments addObject:@{
                    @"type": @(sleep.type),
                    @"durationMinutes": @(sleep.total),
                    @"startTime": sleep.happenDate ?: @"",
                    @"endTime": sleep.endTime ?: @"",
                }];
            }
            completion(segments, nil);
        } fail:^{
            completion(nil, [NSError errorWithDomain:@"QCBand"
                                                code:-1
                                            userInfo:@{NSLocalizedDescriptionKey: @"getSleepData failed"}]);
        }];
    } completion:^(id result_, NSError *error) {
        if (error) {
            result([FlutterError errorWithCode:@"SLEEP_FAILED"
                                       message:error.localizedDescription
                                       details:nil]);
        } else {
            result(result_);
        }
    }];
}

#pragma mark - Blood Oxygen

- (void)handleGetBloodOxygen:(NSDictionary *)args result:(FlutterResult)result {
    NSInteger dayIndex = [args[@"dayIndex"] integerValue];

    [[QCBandCommandQueue shared] enqueue:^(void (^completion)(id, NSError *)) {
        [QCSDKCmdCreator getBloodOxygenDataByDayIndex:dayIndex
                                             finished:^(NSArray *data, NSError *err) {
            if (err) {
                completion(nil, err);
                return;
            }
            NSMutableArray *readings = [NSMutableArray array];
            for (QCBloodOxygenModel *bo in data) {
                NSTimeInterval timestamp = [bo.date timeIntervalSince1970] * 1000;
                [readings addObject:@{
                    @"spo2": @(bo.soa2),
                    @"timestamp": @((long long)timestamp),
                }];
            }
            completion(readings, nil);
        }];
    } completion:^(id result_, NSError *error) {
        if (error) {
            result([FlutterError errorWithCode:@"SPO2_FAILED"
                                       message:error.localizedDescription
                                       details:nil]);
        } else {
            result(result_);
        }
    }];
}

#pragma mark - Real-Time Heart Rate

- (void)handleStartRealTimeHR:(FlutterResult)result {
    [[QCBandCommandQueue shared] enqueue:^(void (^completion)(id, NSError *)) {
        [QCSDKCmdCreator beginRealTimeHeartRateSuccess:^{
            completion(@YES, nil);
        } fail:^{
            completion(nil, [NSError errorWithDomain:@"QCBand"
                                                code:-1
                                            userInfo:@{NSLocalizedDescriptionKey: @"startRealTimeHR failed"}]);
        }];
    } completion:^(id result_, NSError *error) {
        if (error) {
            result([FlutterError errorWithCode:@"HR_START_FAILED"
                                       message:error.localizedDescription
                                       details:nil]);
            return;
        }

        // Start hold timer on native side (20s interval)
        // This prevents Flutter timer drift from killing the session
        [self.hrHoldTimer invalidate];
        self.hrHoldTimer = [NSTimer scheduledTimerWithTimeInterval:20.0
                                                           repeats:YES
                                                             block:^(NSTimer *timer) {
            [QCSDKCmdCreator continueRealTimeHeartRateSuccess:^{
                NSLog(@"QCBand: HR hold/continue sent");
            } fail:^{
                NSLog(@"QCBand: HR hold/continue failed");
            }];
        }];

        result(nil);
    }];
}

- (void)handleStopRealTimeHR:(FlutterResult)result {
    [self.hrHoldTimer invalidate];
    self.hrHoldTimer = nil;

    [[QCBandCommandQueue shared] enqueue:^(void (^completion)(id, NSError *)) {
        [QCSDKCmdCreator endRealTimeHeartRateSuccess:^{
            completion(@YES, nil);
        } fail:^{
            completion(nil, [NSError errorWithDomain:@"QCBand"
                                                code:-1
                                            userInfo:@{NSLocalizedDescriptionKey: @"stopRealTimeHR failed"}]);
        }];
    } completion:^(id result_, NSError *error) {
        if (error) {
            result([FlutterError errorWithCode:@"HR_STOP_FAILED"
                                       message:error.localizedDescription
                                       details:nil]);
        } else {
            result(nil);
        }
    }];
}

#pragma mark - OdmCentralManagerDelegate

- (void)didScanPeripherals:(NSArray *)peripheralArr {
    self.scannedPeripherals = peripheralArr;

    NSMutableArray *devices = [NSMutableArray array];
    for (QCPeripheral *qcp in peripheralArr) {
        CBPeripheral *p = qcp.peripheral;
        [devices addObject:@{
            @"id": p.identifier.UUIDString ?: @"",
            @"name": p.name ?: @"Unknown",
            @"rssi": @(-70), // RSSI not directly exposed by QCPeripheral
        }];
    }

    [self sendEvent:@{
        @"event": @"scanResult",
        @"devices": devices,
    }];
}

- (void)didConnected:(CBPeripheral *)peripheral {
    [self sendEvent:@{
        @"event": @"connectionState",
        @"state": @"connected",
    }];
}

- (void)didDisconnecte:(CBPeripheral *)peripheral {
    [self.hrHoldTimer invalidate];
    self.hrHoldTimer = nil;
    self.connectedPeripheral = nil;
    [[QCBandCommandQueue shared] cancelAll];

    [self sendEvent:@{
        @"event": @"connectionState",
        @"state": @"disconnected",
    }];
}

- (void)didFailConnected:(CBPeripheral *)peripheral {
    self.connectedPeripheral = nil;

    [self sendEvent:@{
        @"event": @"connectionState",
        @"state": @"failed",
    }];
}

- (void)centerManagerState:(CBManagerState)state {
    // Can broadcast BLE state if needed
    NSLog(@"QCBand: BLE central state: %ld", (long)state);
}

@end
