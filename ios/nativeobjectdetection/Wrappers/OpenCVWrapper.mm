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
