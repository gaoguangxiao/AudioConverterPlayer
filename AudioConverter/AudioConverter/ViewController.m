//
//  ViewController.m
//  AudioConverter
//
//  Created by gaoguangxiao on 2018/8/11.
//  Copyright © 2018年 gaoguangxiao. All rights reserved.
//

#import "ViewController.h"

#import "XBAudioTool.h"
#import "XBAudioUnitPlayer.h"
@interface ViewController ()
{
    AudioFileID audioFileID;
    AudioStreamBasicDescription audioFileFormat;
    AudioStreamPacketDescription *audioPacketFormat;
    UInt64 packetNums;
    
    SInt64 readedPacket; // 已读的packet数量
    
    AudioBufferList *buffList;
    Byte *convertBuffer;
    
    AudioConverterRef audioConverter;
    
    __weak IBOutlet UILabel *_sourceLabel;
    __weak IBOutlet UILabel *_inDestinationLabel;
    
}
@property (nonatomic,assign) BOOL isPlaying;
@property (nonatomic,strong) XBAudioUnitPlayer *player;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"周杰伦 - 晴天" ofType:@"mp3"];
    
    [XBAudioTool getAudioPropertyWithFilepath:filePath completeBlock:^(AudioFileID audioFileIDT, AudioStreamBasicDescription audioFileFormatT, UInt64 packetNumsT, UInt64 maxFramesPerPacketT) {
        
        self->audioConverter = NULL;
        
        //一、读取的
        self->audioFileID = audioFileIDT;
        self->audioFileFormat = audioFileFormatT;
        self->packetNums = packetNumsT;
        
        self->readedPacket = 0;
        
        int mFramesPerPacket = 1;//
        int mBitsPerChannel = 32;
        int mChannelsPerFrame = 1;
        //二、转换格式
        AudioStreamBasicDescription outputFormat = [XBAudioTool allocAudioStreamBasicDescriptionWithMFormatID:kAudioFormatLinearPCM mFormatFlags:(kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved) mSampleRate:44100 mFramesPerPacket:mFramesPerPacket mChannelsPerFrame:mChannelsPerFrame mBitsPerChannel:mBitsPerChannel];
        
        [XBAudioTool printAudioStreamBasicDescription:self->audioFileFormat andkit:self->_sourceLabel];
        [XBAudioTool printAudioStreamBasicDescription:outputFormat andkit:self->_inDestinationLabel];
        
        CheckError(AudioConverterNew(&self->audioFileFormat, &outputFormat, &self->audioConverter), "AudioConverterNew eror");
        //三、开始播放
        self->audioPacketFormat = malloc(sizeof(AudioStreamPacketDescription) * (CONST_BUFFER_SIZE / maxFramesPerPacketT + 1));
        
        self->buffList = [XBAudioTool allocAudioBufferListWithMDataByteSize:CONST_BUFFER_SIZE mNumberChannels:1 mNumberBuffers:1];
        
        self->convertBuffer = malloc(CONST_BUFFER_SIZE);
        
        
        self.player = [[XBAudioUnitPlayer alloc] initWithRate:outputFormat.mSampleRate bit:outputFormat.mBitsPerChannel channel:outputFormat.mChannelsPerFrame];
    } errorBlock:^(NSError *error) {
        
    }];
}
- (IBAction)PlayerSourcec:(UIButton *)sender {
    
    if (sender.tag == 0) {
        if (self.player)
        {
            if (self.player.bl_input == nil)
            {
                typeof(self) __weak weakSelf = self;
                typeof(weakSelf) __strong strongSelf = weakSelf;
                self.player.bl_inputFull = ^(XBAudioUnitPlayer *player, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
                    
                    strongSelf->buffList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
                    OSStatus status = AudioConverterFillComplexBuffer(strongSelf->audioConverter, lyInInputDataProc, (__bridge void * _Nullable)(strongSelf), &inNumberFrames, strongSelf->buffList, NULL);
                    if (status) {
                        NSLog(@"转换格式失败 %d", status);
                    }
                    
                    //                NSLog(@"out size: %d", strongSelf->buffList->mBuffers[0].mDataByteSize);
                    memcpy(ioData->mBuffers[0].mData, strongSelf->buffList->mBuffers[0].mData, strongSelf->buffList->mBuffers[0].mDataByteSize);
                    ioData->mBuffers[0].mDataByteSize = strongSelf->buffList->mBuffers[0].mDataByteSize;
                    
                    
                    if (strongSelf->buffList->mBuffers[0].mDataByteSize <= 0) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            //                        [weakSelf stop];
                        });
                    }
                    
                };
            }
            [self.player start];
//            self.isPlaying = YES;
        }
    }else{
        self.player.bl_input = nil;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kPreferredIOBufferDuration*0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.player stop];
//            self.isPlaying = NO;
        });
    }
    
}

OSStatus lyInInputDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
    ViewController *player = (__bridge ViewController *)(inUserData);
    
    UInt32 byteSize = CONST_BUFFER_SIZE;
    OSStatus status = AudioFileReadPacketData(player->audioFileID, NO, &byteSize, player->audioPacketFormat, player->readedPacket, ioNumberDataPackets, player->convertBuffer);
    
    if (outDataPacketDescription) { // 这里要设置好packetFormat，否则会转码失败
        *outDataPacketDescription = player->audioPacketFormat;
    }
    
    
    if(status) {
        NSLog(@"读取文件失败");
    }
    
    if (!status && ioNumberDataPackets > 0) {
        ioData->mBuffers[0].mDataByteSize = byteSize;
        ioData->mBuffers[0].mData = player->convertBuffer;
        player->readedPacket += *ioNumberDataPackets;
        return noErr;
    }
    else {
        return NO_MORE_DATA;
    }
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
