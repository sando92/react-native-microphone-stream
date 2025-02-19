#import "MicrophoneStream.h"

#define BIAS (0x84)
#define CLIP 8159
#define NUM_BUFFERS 3  // Number of audio buffers to use

@implementation MicrophoneStream {
    AudioQueueRef _queue;
    AudioQueueBufferRef _buffers[NUM_BUFFERS];  // Array of buffers
    AVAudioSessionCategory _category;
    AVAudioSessionMode _mode;
    BOOL _isInitialized;
}

void inputCallback(
        void *inUserData,
        AudioQueueRef inAQ,
        AudioQueueBufferRef inBuffer,
        const AudioTimeStamp *inStartTime,
        UInt32 inNumberPacketDescriptions,
        const AudioStreamPacketDescription *inPacketDescs) {
    NSLog(@"[MicrophoneStream] Input callback received - Buffer size: %d, Packets: %d", 
          (int)inBuffer->mAudioDataByteSize, 
          (int)inNumberPacketDescriptions);
    [(__bridge MicrophoneStream *) inUserData processInputBuffer:inBuffer queue:inAQ];
}

int seg_uend[8] = { 0x3F, 0x7F, 0xFF, 0x1FF, 0x3FF, 0x7FF, 0xFFF, 0x1FFF };

static int search(int val, int *table, int size) {
    int i;
    for (i = 0; i < size; i++) {
        if (val <= *table++)
            return (i);
    }
    return (size);
}

int linear2ulaw(int pcm_val) {
    int mask;
    int seg;
    int uval;

    pcm_val = pcm_val >> 2;
    if (pcm_val < 0) {
        pcm_val = -pcm_val;
        mask = 0x7F;
    } else {
        mask = 0xFF;
    }
    if (pcm_val > CLIP)
        pcm_val = CLIP;
    pcm_val += (BIAS >> 2);

    seg = search(pcm_val, seg_uend, 8);

    if (seg >= 8)
        return (0x7F ^ mask);
    else {
        uval = (seg << 4) | ((pcm_val >> (seg + 1)) & 0xF);
        return (uval ^ mask);
    }
}

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(init:(NSDictionary *) options) {
    NSLog(@"[MicrophoneStream] Initializing with options: %@", options);
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    _category = [session category];
    _mode = [session mode];

    NSError *error = nil;
    [session setCategory:AVAudioSessionCategoryPlayAndRecord
             withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker
                   error:&error];
    if (error) {
        NSLog(@"[MicrophoneStream] Error setting audio session category: %@", error);
        return;
    }
    
    [session setActive:YES error:&error];
    if (error) {
        NSLog(@"[MicrophoneStream] Error activating audio session: %@", error);
        return;
    }

    UInt32 bufferSize = options[@"bufferSize"] == nil ? 8192 : [options[@"bufferSize"] unsignedIntegerValue];
    NSLog(@"[MicrophoneStream] Using buffer size: %d", (int)bufferSize);

    AudioStreamBasicDescription description;
    description.mReserved = 0;
    description.mSampleRate = options[@"sampleRate"] == nil ? 44100 : [options[@"sampleRate"] doubleValue];
    description.mBitsPerChannel = options[@"bitsPerChannel"] == nil ? 16 : [options[@"bitsPerChannel"] unsignedIntegerValue];
    description.mChannelsPerFrame = options[@"channelsPerFrame"] == nil ? 1 : [options[@"channelsPerFrame"] unsignedIntegerValue];
    description.mFramesPerPacket = 1;  // For PCM, one frame per packet
    description.mBytesPerFrame = (description.mBitsPerChannel / 8) * description.mChannelsPerFrame;
    description.mBytesPerPacket = description.mBytesPerFrame;
    description.mFormatID = kAudioFormatLinearPCM;
    description.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;

    NSLog(@"[MicrophoneStream] Audio format: %@", @{
        @"sampleRate": @(description.mSampleRate),
        @"bitsPerChannel": @(description.mBitsPerChannel),
        @"channelsPerFrame": @(description.mChannelsPerFrame),
        @"bytesPerFrame": @(description.mBytesPerFrame),
        @"bytesPerPacket": @(description.mBytesPerPacket)
    });

    OSStatus status = AudioQueueNewInput(&description, inputCallback, (__bridge void *) self, NULL, NULL, 0, &_queue);
    if (status != noErr) {
        NSLog(@"[MicrophoneStream] Error creating audio queue: %d", (int)status);
        return;
    }
    
    // Allocate and enqueue multiple buffers
    for (int i = 0; i < NUM_BUFFERS; i++) {
        status = AudioQueueAllocateBuffer(_queue, bufferSize, &_buffers[i]);
        if (status != noErr) {
            NSLog(@"[MicrophoneStream] Error allocating buffer %d: %d", i, (int)status);
            return;
        }
        
        status = AudioQueueEnqueueBuffer(_queue, _buffers[i], 0, NULL);
        if (status != noErr) {
            NSLog(@"[MicrophoneStream] Error enqueueing buffer %d: %d", i, (int)status);
            return;
        }
    }
    
    _isInitialized = YES;
    NSLog(@"[MicrophoneStream] Initialization completed successfully");
}

RCT_EXPORT_METHOD(start) {
    if (!_isInitialized) {
        NSLog(@"[MicrophoneStream] Cannot start - not initialized");
        return;
    }

    NSLog(@"[MicrophoneStream] Starting audio queue");
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;
    
    [session setActive:YES error:&error];
    if (error) {
        NSLog(@"[MicrophoneStream] Error activating session on start: %@", error);
        return;
    }
    
    OSStatus status = AudioQueueStart(_queue, NULL);
    if (status != noErr) {
        NSLog(@"[MicrophoneStream] Error starting audio queue: %d", (int)status);
    }
}

RCT_EXPORT_METHOD(pause) {
    AudioQueuePause(_queue);
    AudioQueueFlush(_queue);
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:_category
                   error:nil];
    [session setMode:_mode
               error:nil];
}

RCT_EXPORT_METHOD(stop) {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:_category
                   error:nil];
    [session setMode:_mode
               error:nil];
    AudioQueueStop(_queue, YES);
}

- (void)processInputBuffer:(AudioQueueBufferRef)inBuffer queue:(AudioQueueRef)queue {
    NSLog(@"[MicrophoneStream] Processing input buffer of size: %d bytes", (int)inBuffer->mAudioDataByteSize);
    
    // Get 16-bit PCM data
    SInt16 *audioData = inBuffer->mAudioData;
    UInt32 count = inBuffer->mAudioDataByteSize / sizeof(SInt16);
    NSLog(@"[MicrophoneStream] Converting %d samples", (int)count);

    NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];
    
    // Send raw 16-bit PCM values
    for (int i = 0; i < count; ++i) {
        [array addObject:[NSNumber numberWithInteger:audioData[i]]];
    }
    
    NSLog(@"[MicrophoneStream] Sending array of size: %lu", (unsigned long)array.count);
    [self sendEventWithName:@"audioData" body:array];
    
    OSStatus status = AudioQueueEnqueueBuffer(queue, inBuffer, 0, NULL);
    if (status != noErr) {
        NSLog(@"[MicrophoneStream] Error re-enqueueing buffer: %d", (int)status);
    }
}

- (NSArray<NSString *> *)supportedEvents {
    return @[@"audioData"];
}

- (void)dealloc {
    AudioQueueStop(_queue, YES);
}

@end
