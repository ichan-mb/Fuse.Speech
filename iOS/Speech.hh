#import <AVFoundation/AVFoundation.h>
#import <Speech/Speech.h>

@interface Speech : NSObject

- (void)stopRecording;
- (void)startRecording:(void (^)(NSString *))resultCb status:(void (^)(bool))statusCb;
- (void)requestPermission:(void (^)(bool))resultCb;
- (void)startSpeaking:(NSString *)sentence;
- (void)stopSpeaking;

@end