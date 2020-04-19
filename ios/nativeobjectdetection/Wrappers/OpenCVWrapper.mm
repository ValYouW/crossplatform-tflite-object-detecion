#import <opencv2/core.hpp>
#import <opencv2/imgproc.hpp>
#import <opencv2/imgcodecs/ios.h>
#import "OpenCVWrapper.h"
#import "ObjectDetector.h"

using namespace std;
using namespace cv;

static ObjectDetector* detector = nil;

@implementation DetectionResult
@end

@implementation OpenCVWrapper

- (void) initDetector {
    if(detector != nil) {
        return;
    }

    // Load the graph config resource.
    long size = 0;
    char* model = nullptr;
    NSError* configLoadError = nil;
    NSString *modelPath = [[NSBundle mainBundle] pathForResource:@"detect" ofType:@"tflite"];
    NSData* data = [NSData dataWithContentsOfFile:modelPath options:0 error:&configLoadError];
    if (!data) {
      NSLog(@"Failed to load model: %@", configLoadError);
    } else {
        size = data.length;
        model = (char*)data.bytes;
    }

    detector = new ObjectDetector((const char*)model, size, true);
}

-(NSArray*) detect: (CMSampleBufferRef)buffer {
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(buffer);
    CVPixelBufferLockBaseAddress( pixelBuffer, 0 );

    //Processing here
    int bufferWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
    int bufferHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
    unsigned char *pixel = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);

    //put buffer in open cv, no memory copied
    Mat mat = Mat(bufferHeight, bufferWidth, CV_8UC4, pixel, CVPixelBufferGetBytesPerRow(pixelBuffer));

    //End processing
    CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );

    Mat dst;
    // In our sample we know we limit to portrait, in real-world the rotation can be a parameter to this func
    rotate(mat, dst, ROTATE_90_CLOCKWISE);
    
    [self initDetector];
    
    DetectResult* detections = detector->detect(dst);

    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity: (detector->DETECT_NUM * 6)];

//    DetectionResult* res = [DetectionResult new];
//    res.count = detector->DETECT_NUM;
//
//    NSMutableArray<NSValue*>* resArray = [NSMutableArray<NSValue*> new];
//
    for (int i = 0; i < detector->DETECT_NUM; ++i) {
        [array addObject:[NSNumber numberWithFloat:detections[i].label]];
        [array addObject:[NSNumber numberWithFloat:detections[i].score]];
        [array addObject:[NSNumber numberWithFloat:detections[i].xmin]];
        [array addObject:[NSNumber numberWithFloat:detections[i].xmax]];
        [array addObject:[NSNumber numberWithFloat:detections[i].ymin]];
        [array addObject:[NSNumber numberWithFloat:detections[i].ymax]];
        
//        [resArray addObject: [NSValue value:&detections[i] withObjCType:@encode(DetectResult)]];
    }
//
//    res.detections = (NSArray<NSValue*>*)[resArray copy];
//    return res;
    
    return array;
}

@end
