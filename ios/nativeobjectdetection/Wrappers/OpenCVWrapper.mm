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
        // ios might release the memory of "data" (NSData) and we don't want that to happen, so we copy and take responsibility for that memory
        size = data.length;
        model = (char*)malloc(sizeof(char) * size);
        memcpy(model, (char*)data.bytes, sizeof(char) * size);
    }

    detector = new ObjectDetector((const char*)model, size);
}

-(DetectionResult*) dect: (CMSampleBufferRef)buffer {
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

    Mat src;
    rotate(mat, src, ROTATE_90_CLOCKWISE);
    
    return nil;
}

-(DetectionResult*) detect: (UIImage *)image {
    if (image == nil) {
        return nil;
    }

    Mat dst;
    UIImageToMat(image, dst);
    cvtColor(dst, dst, COLOR_RGBA2BGRA);
    
    [self initDetector];
    
    DetectResult* detections = detector->detect(dst);
    
    DetectionResult* res = [DetectionResult new];
    res.count = detector->DETECT_NUM;

    NSMutableArray<NSValue*>* resArray = [NSMutableArray<NSValue*> new];

    for (int i = 0; i < detector->DETECT_NUM; ++i) {
        [resArray addObject: [NSValue value:&detections[i] withObjCType:@encode(DetectResult)]];
    }
    
    res.detections = (NSArray<NSValue*>*)[resArray copy];
    return res;
}

@end
