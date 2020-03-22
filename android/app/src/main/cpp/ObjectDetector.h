#pragma once

#include <opencv2/core.hpp>
#include "tensorflow/lite/model.h"

using namespace cv;

struct DetectResult {
	int label = -1;
	float score = 0;
	float ymin = 0.0;
	float xmin = 0.0;
	float ymax = 0.0;
	float xmax = 0.0;
};

class ObjectDetector {
public:
	ObjectDetector(const char *tfliteModel, long modelSize, bool quantized = false);
	~ObjectDetector();
	DetectResult *detect(Mat src);
	const int DETECT_NUM = 3;
private:
	// members
	const int DETECTION_MODEL_SIZE = 300;
	const int DETECTION_MODEL_CNLS = 3;
	const float IMAGE_MEAN = 128.0;
	const float IMAGE_STD = 128.0;
	bool m_modelQuantized = false;
	bool m_hasDetectionModel = false;
	char *m_modelBytes = nullptr;
	std::unique_ptr<tflite::FlatBufferModel> m_model;
	std::unique_ptr<tflite::Interpreter> m_interpreter;
	TfLiteTensor *m_input_tensor = nullptr;
	TfLiteTensor *m_output_locations = nullptr;
	TfLiteTensor *m_output_classes = nullptr;
	TfLiteTensor *m_output_scores = nullptr;
	TfLiteTensor *m_num_detections = nullptr;

	// Methods
	void initDetectionModel(const char *tfliteModel, long modelSize);
};