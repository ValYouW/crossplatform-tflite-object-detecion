package com.vyw.nativeobjectdetection

import android.content.res.AssetManager
import android.graphics.*
import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import com.otaliastudios.cameraview.CameraView
import com.otaliastudios.cameraview.frame.Frame
import kotlinx.android.synthetic.main.activity_main.*
import java.io.BufferedReader
import java.io.InputStreamReader

class MainActivity : AppCompatActivity() {
	private val TAG = "MainActivity"
	private var detectorAddr = 0L
	private var frameWidth = 0
	private var frameHeight = 0
	private val _paint = Paint()
	val labelsMap = arrayListOf<String>()

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		setContentView(R.layout.activity_main)

		val cameraView = this.findViewById<CameraView>(R.id.camera)
		cameraView.setLifecycleOwner(this)

		cameraView.addFrameProcessor { frame -> detectObjectNative(frame) }

		// init the paint for drawing the detections
		_paint.color = Color.RED
		_paint.style = Paint.Style.STROKE
		_paint.strokeWidth = 3f
		_paint.textSize = 50f
		_paint.textAlign = Paint.Align.LEFT

		// Set the detections drawings surface transparent
		surfaceView.setZOrderOnTop(true)
		surfaceView.holder.setFormat(PixelFormat.TRANSPARENT)

		this.loadLabels()
	}

	private fun loadLabels() {
		val labelsInput = this.assets.open("labelmap.txt")
		val br = BufferedReader(InputStreamReader(labelsInput))
		var line = br.readLine()
		while (line != null) {
			labelsMap.add(line)
			line = br.readLine()
		}

		br.close()
	}

	private fun detectObjectNative(frame: Frame) {
		val start = System.currentTimeMillis()
		if (this.detectorAddr == 0L) {
			this.detectorAddr = initDetector(this.assets)
			this.frameWidth = frame.size.width
			this.frameHeight = frame.size.height
		}

		val res = detect(
			this.detectorAddr,
			frame.getData(),
			frame.size.width,
			frame.size.height,
			frame.rotationToUser
		)

		val span = System.currentTimeMillis() - start
		Log.i(TAG, "Detection span: ${span}ms")

		val canvas = surfaceView.holder.lockCanvas()
		if (canvas != null) {
			canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.MULTIPLY)
			// Draw the detections, in our case there are only 3
			this.drawDetection(canvas, frame.rotationToUser, res, 0)
			this.drawDetection(canvas, frame.rotationToUser, res, 1)
			this.drawDetection(canvas, frame.rotationToUser, res, 2)
			surfaceView.holder.unlockCanvasAndPost(canvas)
		}
	}

	private fun drawDetection(
		canvas: Canvas,
		rotation: Int,
		detectionsArr: FloatArray,
		detectionIdx: Int
	) {
		// Filter by score
		val score = detectionsArr[detectionIdx * 6 + 1]
		if (score < 0.6) return

		// Get the frame dimensions
		val w = if (rotation == 0 || rotation == 180) this.frameWidth else this.frameHeight
		val h = if (rotation == 0 || rotation == 180) this.frameHeight else this.frameWidth

		// detection coords are in frame coord system, convert to screen coords
		val scaleX = camera.width.toFloat() / w
		val scaleY = camera.height.toFloat() / h

		// The camera view offset on screen
		val xoff = camera.left.toFloat()
		val yoff = camera.top.toFloat()

		val classId = detectionsArr[detectionIdx * 6 + 0]
		val xmin = xoff + detectionsArr[detectionIdx * 6 + 2] * scaleX
		val xmax = xoff + detectionsArr[detectionIdx * 6 + 3] * scaleX
		val ymin = yoff + detectionsArr[detectionIdx * 6 + 4] * scaleY
		val ymax = yoff + detectionsArr[detectionIdx * 6 + 5] * scaleY


		// Draw the rect
		val p = Path()
		p.moveTo(xmin, ymin)
		p.lineTo(xmax, ymin)
		p.lineTo(xmax, ymax)
		p.lineTo(xmin, ymax)
		p.lineTo(xmin, ymin)

		canvas.drawPath(p, _paint)

		// SSD Mobilenet Model assumes class 0 is background class and detection result class
		// are zero-based (meaning class id 0 is class 1)
		val label = labelsMap[classId.toInt() + 1]

		val txt = "%s (%.2f)".format(label, score)
		canvas.drawText(txt, xmin, ymin, _paint)
	}

	/**
	 * A native method that is implemented by the 'native-lib' native library,
	 * which is packaged with this application.
	 */
	private external fun initDetector(assetManager: AssetManager): Long

	private external fun detect(
		detectorAddr: Long,
		srcAddr: ByteArray,
		width: Int,
		height: Int,
		rotation: Int
	): FloatArray

	companion object {

		// Used to load the 'native-lib' library on application startup.
		init {
			System.loadLibrary("native-lib")
		}
	}
}
