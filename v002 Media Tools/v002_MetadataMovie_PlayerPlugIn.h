//
//  v002_Media_ToolsPlugIn.h
//  v002 Media Tools
//
//  Created by vade on 7/15/12.
//  Copyright (c) 2012 v002. All rights reserved.
//

#import <Quartz/Quartz.h>
#import <CoreVideo/CoreVideo.h>
#import <AVFoundation/AVFoundation.h>

@interface v002_MetadataMovie_PlayerPlugIn : QCPlugIn <AVPlayerItemOutputPullDelegate, AVPlayerItemMetadataOutputPushDelegate>
{
    AVPlayer* player;
    AVPlayerItemVideoOutput* playerItemVideoOutput;
    AVPlayerItemMetadataOutput* playerItemMetadataOutput;
    
    dispatch_queue_t playerVideoOutputQueue;
    
    BOOL movieDidEnd;
}
@property (copy) NSDictionary* latestMetadataDictionary;
@property BOOL movieDidEnd;

// output ports
@property (strong) NSString* inputPath;
@property (assign) double inputPlayhead;
@property (assign) double inputRate;
@property (assign) BOOL inputPlay;
@property (assign) NSUInteger inputLoopMode;
@property (assign) double inputVolume;
@property (assign) BOOL inputColorCorrection;

@property (assign) id <QCPlugInOutputImageProvider> outputImage;
@property (copy) NSDictionary* outputSummaryMetadata;
@property (copy) NSDictionary* outputFrameMetadata;
@property (assign) double outputPlayheadPosition;
@property (assign) double outputDuration;
@property (assign) double outputMovieTime;
@property (assign) BOOL  outputMovieDidEnd;

@end
