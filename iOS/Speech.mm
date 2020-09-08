#import "Speech.hh"

@implementation Speech

SFSpeechRecognizer *speechRecognizer;
SFSpeechAudioBufferRecognitionRequest *recognitionRequest;
SFSpeechRecognitionTask *recognitionTask;
AVAudioEngine *audioEngine;
AVAudioInputNode *inputNode;
NSTimer * timer;
bool isRecording = false;
AVSpeechSynthesizer * speechSynthesizer;

-(instancetype)init
{
    if ( self = [super init] ) {
        speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"id_ID"]];
        recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
        audioEngine = [[AVAudioEngine alloc] init];
        speechSynthesizer = [[AVSpeechSynthesizer alloc] init];

        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord
                               withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker
                                               error:nil];
        [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
        [audioSession setActive:true error:nil];
    }
    return self;
}

- (void)requestPermission:(void(^)(bool))resultCb
{
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus authStatus) {
        switch (authStatus) {
        case SFSpeechRecognizerAuthorizationStatusAuthorized:
            //User gave access to speech recognition
            resultCb(true);
            break;

        case SFSpeechRecognizerAuthorizationStatusDenied:
            //User denied access to speech recognition
            resultCb(false);
            break;

        case SFSpeechRecognizerAuthorizationStatusRestricted:
            //Speech recognition restricted on this device
            resultCb(false);
            break;

        case SFSpeechRecognizerAuthorizationStatusNotDetermined:
            //Speech recognition not yet authorized
            break;
        default:
            NSLog(@"Default");
            break;
    }
    }];
}

- (void)stopRecording
{
    if(recognitionTask != nil){
        [audioEngine stop];
        [inputNode removeTapOnBus:0];
        [recognitionRequest endAudio];
        [recognitionTask cancel];
        [timer invalidate];
        recognitionTask = nil;
    }
    isRecording = false;
}

- (void)startRecording:(void (^)(NSString *))resultCb status:(void (^)(bool))statusCb;
{
    if (isRecording)
        return;

    [self stopSpeaking];

    inputNode = audioEngine.inputNode;
    AVAudioFormat *recordingFormat = [inputNode outputFormatForBus:0];
    [inputNode installTapOnBus:0 bufferSize:1024 format:recordingFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        [recognitionRequest appendAudioPCMBuffer:buffer];
    }];

    [audioEngine prepare];
    [audioEngine startAndReturnError:nil];

    dispatch_async(dispatch_get_main_queue(), ^{
        timer = [NSTimer scheduledTimerWithTimeInterval:4 repeats:false block:^(NSTimer * _Nonnull timer) {
            [self stopRecording];
            if(statusCb!=nil) statusCb(false);
        }];
    });

    recognitionRequest.shouldReportPartialResults = true;
    recognitionTask = [speechRecognizer recognitionTaskWithRequest:recognitionRequest resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
        bool isFinal = false;
        if(result){
            if(resultCb!=nil) resultCb(result.bestTranscription.formattedString);
            isFinal = result.isFinal;
            dispatch_async(dispatch_get_main_queue(), ^{
                [timer invalidate];
                timer = [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:false block:^(NSTimer * _Nonnull timer) {
                    [self stopRecording];
                    if(statusCb!=nil) statusCb(false);
                }];
            });
        }
        if (isFinal) {
            [self stopRecording];
            if(statusCb!=nil) statusCb(false);
        }
        if(error) {
            if(statusCb!=nil) statusCb(false);
        }
    }];
    if(statusCb!=nil) statusCb(true);
    isRecording = true;
}

- (void)startSpeaking:(NSString *)sentence
{
    AVSpeechUtterance * utterance = [AVSpeechUtterance speechUtteranceWithString:sentence];
    utterance.voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"id_ID"];
    [speechSynthesizer speakUtterance:utterance];
}

-(void)stopSpeaking
{
    [speechSynthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
}
@end
