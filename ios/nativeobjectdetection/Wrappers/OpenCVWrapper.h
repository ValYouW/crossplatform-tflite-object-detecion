#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenCVWrapper : NSObject
- (void) initDetector;
;
- (NSArray*) detect: (CMSampleBufferRef)buffer;
@end

NS_ASSUME_NONNULL_END
