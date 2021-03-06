//
//  v002_Media_ToolsPlugIn.m
//  v002 Media Tools
//
//  Created by vade on 7/15/12.
//  Copyright (c) 2012 v002. All rights reserved.
//

// It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering
#import <OpenGL/CGLMacro.h>
#import "v002CVPixelBufferImageProvider.h"
#import "v002_MetadataMovie_PlayerPlugIn.h"

#import <VideoToolbox/VideoToolbox.h>
#import <VideoToolbox/VTProfessionalVideoWorkflow.h>

#import "BSON/BSONSerialization.h"
#import "GZIP/GZIP.h"

#define	kQCPlugIn_Name				@"v002 Metadata Movie Player 1.0"
#define	kQCPlugIn_Description		@"AVFoundation based movie player that supports Metavisual Metadata output oh snap!"

@implementation v002_MetadataMovie_PlayerPlugIn

@synthesize movieDidEnd;

@dynamic inputPath;
@dynamic inputPlayhead;
@dynamic inputRate;
@dynamic inputPlay;
@dynamic inputLoopMode;
@dynamic inputVolume;
@dynamic inputColorCorrection;

@dynamic outputImage;
@dynamic outputSummaryMetadata;
@dynamic outputFrameMetadata;
@dynamic outputPlayheadPosition;
@dynamic outputDuration;
@dynamic outputMovieTime;
@dynamic outputMovieDidEnd;

+ (NSDictionary *)attributes
{
    return @{QCPlugInAttributeNameKey:kQCPlugIn_Name, QCPlugInAttributeDescriptionKey:kQCPlugIn_Description};
}

+ (NSDictionary *)attributesForPropertyPortWithKey:(NSString *)key
{

    if([key isEqualToString:@"inputPath"])
        return  @{QCPortAttributeNameKey : @"Movie Path"};
    
    if([key isEqualToString:@"inputPlayhead"])
        return  @{QCPortAttributeNameKey : @"Playhead",
                QCPortAttributeMinimumValueKey : [NSNumber numberWithFloat:0.0],
                QCPortAttributeDefaultValueKey : [NSNumber numberWithFloat:0.0],
                QCPortAttributeMaximumValueKey : [NSNumber numberWithFloat:1.0]};

    if([key isEqualToString:@"inputPlay"])
        return  @{QCPortAttributeNameKey:@"Play", QCPortAttributeDefaultValueKey:[NSNumber numberWithBool:YES]};

    if([key isEqualToString:@"inputRate"])
        return  @{QCPortAttributeNameKey:@"Rate", QCPortAttributeDefaultValueKey:[NSNumber numberWithFloat:1.0]};
    
    if([key isEqualToString:@"inputLoopMode"])
        return  @{QCPortAttributeNameKey : @"Playhead",
                QCPortAttributeMenuItemsKey : @[@"Loop", @"Palindrome", @"No Loop"],
                QCPortAttributeMinimumValueKey : [NSNumber numberWithUnsignedInteger:0],
                QCPortAttributeDefaultValueKey : [NSNumber numberWithUnsignedInteger:0],
                QCPortAttributeMaximumValueKey : [NSNumber numberWithUnsignedInteger:2]};

    if([key isEqualToString:@"inputVolume"])
        return  @{QCPortAttributeNameKey : @"Volume",
                QCPortAttributeMinimumValueKey : [NSNumber numberWithFloat:0.0],
                QCPortAttributeDefaultValueKey : [NSNumber numberWithFloat:1.0],
                QCPortAttributeMaximumValueKey : [NSNumber numberWithFloat:1.0]};

    if([key isEqualToString:@"inputColorCorrection"])
        return  @{QCPortAttributeNameKey:@"Color Correct", QCPortAttributeDefaultValueKey:[NSNumber numberWithBool:YES]};

    if([key isEqualToString:@"outputImage"])
        return  @{QCPortAttributeNameKey : @"Image"};

    if([key isEqualToString:@"outputSummaryMetadata"])
        return  @{QCPortAttributeNameKey : @"Summary Metadata"};

    if([key isEqualToString:@"outputFrameMetadata"])
        return  @{QCPortAttributeNameKey : @"Frame Metadata"};

    if([key isEqualToString:@"outputPlayheadPosition"])
        return  @{QCPortAttributeNameKey : @"Current Playhead Position"};

    if([key isEqualToString:@"outputDuration"])
        return  @{QCPortAttributeNameKey : @"Duration"};

    if([key isEqualToString:@"outputMovieTime"])
        return  @{QCPortAttributeNameKey : @"Current Time"};

    if([key isEqualToString:@"outputMovieDidEnd"])
        return  @{QCPortAttributeNameKey : @"Movie Finished"};

	return nil;
}

+ (NSArray*) sortedPropertyPortKeys
{
    return @[@"inputPath",
             @"inputPlayhead",
             @"inputPlay",
             @"inputRate",
             @"inputLoopMode",
             @"inputVolume",
             @"inputColorCorrection",
             @"outputImage",
             @"outputSummaryMetadata",
             @"outputFrameMetadata",
             @"outputPlayheadPosition",
             @"outputMovieTime",
             @"outputDuration",
             @"outputMovieDidEnd"];
}

+ (QCPlugInExecutionMode)executionMode
{
	return kQCPlugInExecutionModeProvider;
}

+ (QCPlugInTimeMode)timeMode
{
	return kQCPlugInTimeModeIdle;
}

- (id)init
{
	self = [super init];
	if (self)
    {
        
        VTRegisterProfessionalVideoWorkflowVideoDecoders();

//        playerVideoOutputQueue = dispatch_queue_create(NULL, NULL);

        player = [[AVPlayer alloc] init];

        // kCVPixelFormatType_32ARGB, kCVPixelFormatType_32BGRA, kCVPixelFormatType_422YpCbCr8
        playerItemVideoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_422YpCbCr8], kCVPixelBufferPixelFormatTypeKey, nil]];
 		if (playerItemVideoOutput)
		{
            playerItemVideoOutput.suppressesPlayerRendering = YES;
//			[playerItemVideoOutput setDelegate:self queue:dispatch_get_main_queue()];
		//	[playerItemVideoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:ADVANCE_INTERVAL_IN_SECONDS];
        }
        
        // nil grabs all available metadata - just do this shit for now because whatever man.
        playerItemMetadataOutput = [[AVPlayerItemMetadataOutput alloc] initWithIdentifiers:nil];
        [playerItemMetadataOutput setDelegate:self queue:dispatch_get_global_queue(DISPATCH_QUEUE_SERIAL, 0)];
//        playerItemMetadataOutput.advanceIntervalForDelegateInvocation = 
        
        self.latestMetadataDictionary = nil;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidPlayToEndTime:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];

	}
	
	return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    [player release];
    player = nil;
    
//    dispatch_sync(playerVideoOutputQueue, ^
//    {
//		[playerItemVideoOutput setDelegate:nil queue:NULL];
//	});
    
    [playerItemVideoOutput release];
    playerItemVideoOutput = nil;
    
    [super dealloc];
}

@end

@implementation v002_MetadataMovie_PlayerPlugIn (Execution)

- (BOOL)startExecution:(id <QCPlugInContext>)context
{
    if(self.inputPlay)
        [player play];

	return YES;
}

- (void)enableExecution:(id <QCPlugInContext>)context
{
}

- (BOOL)execute:(id <QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary *)arguments
{	
    
    // new file path
    if([self didValueForInputKeyChange:@"inputPath"])
    {
        NSString * path = self.inputPath;
		
		NSURL *pathURL;
		
		// relative to composition ?
		if(![path hasPrefix:@"/"] && ![path hasPrefix:@"http://"] && ![path hasPrefix:@"rtsp://"])
			path =  [NSString pathWithComponents:[NSArray arrayWithObjects:[[[context compositionURL] path]stringByDeletingLastPathComponent], path, nil]];
		
		path = [path stringByStandardizingPath];
		
		if([[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			pathURL = [NSURL fileURLWithPath:path]; // TWB no longer retained
			NSLog(@"%@", pathURL);
		}
		else
		{
			pathURL =  [NSURL URLWithString:[path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]; 
			NSLog(@"%@", pathURL);
		}
        
        AVPlayerItem* newItem = [AVPlayerItem playerItemWithURL:pathURL];
        
        [[player currentItem] removeOutput:playerItemVideoOutput];
        [[player currentItem] removeOutput:playerItemMetadataOutput];

        [player replaceCurrentItemWithPlayerItem:newItem];
        
        [[player currentItem] addOutput:playerItemVideoOutput];
        [[player currentItem] addOutput:playerItemMetadataOutput];
        
        self.outputDuration = CMTimeGetSeconds([[player currentItem] duration]);
        
        for(AVMetadataItem* metadataItem in player.currentItem.asset.metadata)
        {
            id synopsisSummaryMetadata = [self decodeSynopsisMetadata:metadataItem];
            if(synopsisSummaryMetadata != nil)
            {
                self.outputSummaryMetadata = synopsisSummaryMetadata;
                break;
            }
        }

        
        [player play];
    }
    
    if([self didValueForInputKeyChange:@"inputPlayhead"])
    {
     	[[player currentItem] seekToTime:CMTimeMultiplyByFloat64([[player currentItem] duration], (Float64) self.inputPlayhead) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    }

    if([self didValueForInputKeyChange:@"inputPlay"])
    {
        if(self.inputPlay)
            [player play];
        else
            [player pause];
    }

    
    if([self didValueForInputKeyChange:@"inputRate"])
    {
        [player setRate:self.inputRate];
    }

    if([self didValueForInputKeyChange:@"inputVolume"])
    {
        [player setVolume:self.inputVolume];
    }
    
    // check our video output for new frames
    CMTime outputItemTime = [playerItemVideoOutput itemTimeForHostTime:CACurrentMediaTime()];
	if ([playerItemVideoOutput hasNewPixelBufferForItemTime:outputItemTime])
	{
		CVPixelBufferRef pixBuff = [playerItemVideoOutput copyPixelBufferForItemTime:outputItemTime itemTimeForDisplay:NULL];
		
        // create new output image provider - retains the pixel buffer for us
        v002CVPixelBufferImageProvider *output = [[v002CVPixelBufferImageProvider alloc] initWithPixelBuffer:pixBuff isFlipped:CVImageBufferIsFlipped(pixBuff) shouldColorMatch:self.inputColorCorrection];
		        
        self.outputImage = output;
        
        [output release];
        CVBufferRelease(pixBuff);

        double currentTime = CMTimeGetSeconds([[player currentItem] currentTime]);
        double duration = CMTimeGetSeconds([[player currentItem] duration]);

        self.outputMovieTime = currentTime;
        self.outputPlayheadPosition = currentTime / duration;
	}

    // output port values
    BOOL end = self.movieDidEnd;
    
    if(end)
    {
        self.outputMovieDidEnd = YES;
        self.movieDidEnd = NO;
    }
    else
        self.outputMovieDidEnd = NO;
    
    self.outputFrameMetadata = self.latestMetadataDictionary;
    
	return YES;
}

- (void)disableExecution:(id <QCPlugInContext>)context
{
}

- (void)stopExecution:(id <QCPlugInContext>)context
{
    [player pause];
}

- (void)playerItemDidPlayToEndTime:(NSNotification *)notification
{
	if ([player currentItem] == [notification object])
	{
        self.movieDidEnd = YES;
        [player seekToTime:kCMTimeZero];
        [player play];
	}
}

- (void)outputMediaDataWillChange:(AVPlayerItemOutput *)sender NS_AVAILABLE(10_8, TBD)
{
    
}

- (void)outputSequenceWasFlushed:(AVPlayerItemOutput *)output NS_AVAILABLE(10_8, TBD);
{
    
}

#pragma mark - AVPlayerItemMetadataOutputPushDelegate

const NSString* kSynopsislMetadataIdentifier = @"mdta/info.synopsis.metadata";

- (void)metadataOutput:(AVPlayerItemMetadataOutput *)output didOutputTimedMetadataGroups:(NSArray *)groups fromPlayerItemTrack:(AVPlayerItemTrack *)track
{
    NSMutableDictionary* metadataDictionary = [NSMutableDictionary dictionary];
    
    for(AVTimedMetadataGroup* group in groups)
    {
        for(AVMetadataItem* metadataItem in group.items)
        {
            NSString* key = metadataItem.identifier;
            
            id decodedJSON = [self decodeSynopsisMetadata:metadataItem];
            if(decodedJSON)
            {
                [metadataDictionary setObject:decodedJSON forKey:key];
            }
            else
            {
                id value = metadataItem.value;
                
                [metadataDictionary setObject:value forKey:key];
            }
            
        }
    }
    
    self.latestMetadataDictionary = metadataDictionary;
}


- (id) decodeSynopsisMetadata:(AVMetadataItem*)metadataItem
{
    NSString* key = metadataItem.identifier;
    
    if([key isEqualToString:kSynopsislMetadataIdentifier])
    {
        // JSON
        //                // Decode our metadata..
        //                NSString* stringValue = (NSString*)metadataItem.value;
        //                NSData* dataValue = [stringValue dataUsingEncoding:NSUTF8StringEncoding];
        //                id decodedJSON = [NSJSONSerialization JSONObjectWithData:dataValue options:kNilOptions error:nil];
        //                if(decodedJSON)
        //                    [metadataDictionary setObject:decodedJSON forKey:key];
        
        //                // BSON:
        //                NSData* zipped = (NSData*)metadataItem.value;
        //                NSData* bsonData = [zipped gunzippedData];
        //                NSDictionary* bsonDict = [NSDictionary dictionaryWithBSON:bsonData];
        //                if(bsonDict)
        //                    [metadataDictionary setObject:bsonDict forKey:key];
        
        // GZIP + JSON
        NSData* zipped = (NSData*)metadataItem.value;
        NSData* json = [zipped gunzippedData];
        id decodedJSON = [NSJSONSerialization JSONObjectWithData:json options:kNilOptions error:nil];
        if(decodedJSON)
        {
            return decodedJSON;
        }

        return nil;
    }
    
    return nil;
}
@end
