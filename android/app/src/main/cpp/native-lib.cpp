#include <jni.h>
#include <string>
#include <android/log.h>
#include <android/bitmap.h>
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>
#include <opencv2/core.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#include "ObjectDetector.h"

using namespace cv;

#define LOG_E(...) __android_log_write(ANDROID_LOG_ERROR, "JNI_LOGS", __VA_ARGS__);

void rotateMat(cv::Mat &matImage, int rotation) {
	if (rotation == 90) {
		transpose(matImage, matImage);
		flip(matImage, matImage, 1); //transpose+flip(1)=CW
	} else if (rotation == 270) {
		transpose(matImage, matImage);
		flip(matImage, matImage, 0); //transpose+flip(0)=CCW
	} else if (rotation == 180) {
		flip(matImage, matImage, -1);    //flip(-1)=180
	}
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_vyw_nativeobjectdetection_MainActivity_initDetector(JNIEnv *env, jobject p_this, jobject assetManager) {
	char *buffer = nullptr;
	long size = 0;

	if (!(env->IsSameObject(assetManager, NULL))) {
		AAssetManager *mgr = AAssetManager_fromJava(env, assetManager);
		AAsset *asset = AAssetManager_open(mgr, "detect.tflite", AASSET_MODE_UNKNOWN);
		assert(asset != nullptr);

		size = AAsset_getLength(asset);
		buffer = (char *) malloc(sizeof(char) * size);
		AAsset_read(asset, buffer, size);
		AAsset_close(asset);
	}

	jlong res = (jlong) new ObjectDetector(buffer, size, true);
	free(buffer); // ObjectDetector duplicate it and responsible to free it
	return res;
}

extern "C" JNIEXPORT jfloatArray JNICALL
Java_com_vyw_nativeobjectdetection_MainActivity_detect(JNIEnv *env, jobject p_this, jlong detectorAddr, jbyteArray src, int width, int height, int rotation) {
	// Frame bytes to Mat
	jbyte *_yuv = env->GetByteArrayElements(src, 0);
	Mat myyuv(height + height / 2, width, CV_8UC1, _yuv);
	Mat frame(height, width, CV_8UC4);
	cvtColor(myyuv, frame, COLOR_YUV2BGRA_NV21);
	rotateMat(frame, rotation);
	// frame = frame(Rect(0, 0, frame.cols, frame.cols));
	env->ReleaseByteArrayElements(src, _yuv, 0);

	// Detect
	ObjectDetector *detector = (ObjectDetector *) detectorAddr;
	DetectResult *res = detector->detect(frame);

	// Encode each detection as 6 numbers (label,score,xmin,xmax,ymin,ymax)
	int resArrLen = detector->DETECT_NUM * 6;
	jfloat jres[resArrLen];
	for (int i = 0; i < detector->DETECT_NUM; ++i) {
		jres[i * 6] = res[i].label;
		jres[i * 6 + 1] = res[i].score;
		jres[i * 6 + 2] = res[i].xmin;
		jres[i * 6 + 3] = res[i].xmax;
		jres[i * 6 + 4] = res[i].ymin;
		jres[i * 6 + 5] = res[i].ymax;
	}

	jfloatArray detections = env->NewFloatArray(resArrLen);
	env->SetFloatArrayRegion(detections, 0, resArrLen, jres);

	return detections;
}
