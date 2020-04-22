cmake_minimum_required(VERSION 3.4.1)

# opencv
set(OpenCV_STATIC ON)
set(OpenCV_DIR $ENV{OPENCV_ANDROID}/sdk/native/jni)
find_package(OpenCV REQUIRED)

# Add tensorflowlite lib
set(Tensorflowlite_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../tflite-dist)
add_library(libtensorflowlite SHARED IMPORTED)
set_target_properties(libtensorflowlite PROPERTIES IMPORTED_LOCATION ${Tensorflowlite_DIR}/libs/android/${ANDROID_ABI}/libtensorflowlite.so)

# Add our native-lib library and specify the source(s)
add_library(
	# Sets the name of the library.
	native-lib

	# Sets the library as a shared library.
	SHARED

	# Provides a relative path to your source file(s).
	../../native-detector/ObjectDetector.cpp
	src/main/cpp/native-lib.cpp
)

# add extra include directories
target_include_directories(
	native-lib PRIVATE
	../../native-detector
	${Tensorflowlite_DIR}/include
)

# For logging to logcat
find_library(log-lib log)

# jnigraphics lib from NDK is used for Bitmap manipulation in native code
find_library(jnigraphics-lib jnigraphics)

# android for AssetManager functionality
find_library(android-lib android)

# Finally specify the target library to build and its dependencies
target_link_libraries(
	native-lib
	libtensorflowlite
	${OpenCV_LIBS}
	${android-lib}
	${jnigraphics-lib}
	${log-lib}
)
