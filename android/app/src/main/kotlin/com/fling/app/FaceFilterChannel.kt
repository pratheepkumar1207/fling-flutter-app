package com.fling.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.net.Uri
import android.os.Handler
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.OverlaySettings
import androidx.media3.effect.TextureOverlay
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import com.google.common.collect.ImmutableList
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.max

// Finds the face and bakes stickers into photos and clips, all on the phone.
// The model is android/app/src/main/assets/face_landmarker.task. Dart side:
// core/face_tracker.dart. A pose is [x, y, width, angle]: see FacePose there.
@OptIn(UnstableApi::class)
class FaceFilterChannel(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "com.fling.app/face_filter")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(context.mainLooper)
    private var live: FaceLandmarker? = null
    private var still: FaceLandmarker? = null
    private var lastTime = 0L

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "detect" -> background(result) { detect(call.arguments as Map<*, *>) }
                "bakePhoto" -> background(result) { bakePhoto(call.arguments as Map<*, *>) }
                "bakeVideo" -> bakeVideo(call.arguments as Map<*, *>, result)
                "release" -> background(result) {
                    live?.close()
                    still?.close()
                    live = null
                    still = null
                    null
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        worker.execute {
            try {
                val out = work()
                main.post { result.success(out) }
            } catch (e: Throwable) {
                // Includes a library failing to load: filters stop, not the app.
                main.post { result.error("face", e.message, null) }
            }
        }
    }

    private fun landmarker(mode: RunningMode): FaceLandmarker = FaceLandmarker.createFromOptions(
        context,
        FaceLandmarker.FaceLandmarkerOptions.builder()
            .setBaseOptions(BaseOptions.builder().setModelAssetPath("face_landmarker.task").build())
            .setRunningMode(mode)
            .setNumFaces(1)
            .build(),
    )

    private fun detect(args: Map<*, *>): List<Double>? {
        val tracker = live ?: landmarker(RunningMode.VIDEO).also { live = it }
        val bitmap = uprightFromLuma(
            args["luma"] as ByteArray,
            args["width"] as Int,
            args["height"] as Int,
            args["rowStride"] as Int,
            args["rotation"] as Int,
        )
        // MediaPipe rejects a time that doesn't move forward.
        val time = max((args["timeMs"] as Number).toLong(), lastTime + 1)
        lastTime = time
        val found = tracker.detectForVideo(BitmapImageBuilder(bitmap).build(), time)
        return poseOf(found, bitmap.width, bitmap.height)
    }

    // Shades of grey are enough to find a face, and far cheaper than colour.
    private fun uprightFromLuma(luma: ByteArray, w: Int, h: Int, stride: Int, rotation: Int): Bitmap {
        val step = max(1, max(w, h) / 480)
        val outW = w / step
        val outH = h / step
        val pixels = IntArray(outW * outH)
        for (y in 0 until outH) {
            val row = y * step * stride
            for (x in 0 until outW) {
                val v = luma[row + x * step].toInt() and 255
                pixels[y * outW + x] = (0xFF shl 24) or (v shl 16) or (v shl 8) or v
            }
        }
        val flat = Bitmap.createBitmap(pixels, outW, outH, Bitmap.Config.ARGB_8888)
        if (rotation == 0) return flat
        val turn = Matrix().apply { postRotate(rotation.toFloat()) }
        return Bitmap.createBitmap(flat, 0, 0, outW, outH, turn, false)
    }

    private fun poseOf(found: FaceLandmarkerResult, w: Int, h: Int): List<Double>? {
        val face = found.faceLandmarks().firstOrNull() ?: return null
        val eyeA = face[LEFT_EYE_CORNER]
        val eyeB = face[RIGHT_EYE_CORNER]
        val cheekA = face[LEFT_CHEEK]
        val cheekB = face[RIGHT_CHEEK]
        val width = hypot(
            ((cheekB.x() - cheekA.x()) * w).toDouble(),
            ((cheekB.y() - cheekA.y()) * h).toDouble(),
        ) / w
        val angle = atan2(
            ((eyeB.y() - eyeA.y()) * h).toDouble(),
            ((eyeB.x() - eyeA.x()) * w).toDouble(),
        )
        return listOf(
            ((eyeA.x() + eyeB.x()) / 2).toDouble(),
            ((eyeA.y() + eyeB.y()) / 2).toDouble(),
            width,
            angle,
        )
    }

    // Photos are checked on their own, so this works for any photo.
    private fun bakePhoto(args: Map<*, *>): String? {
        val input = args["input"] as String
        val decoded = BitmapFactory.decodeFile(input, BitmapFactory.Options().apply {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(input, bounds)
            var sample = 1
            while (max(bounds.outWidth, bounds.outHeight) / sample > 1440) sample *= 2
            inSampleSize = sample
        }) ?: throw IllegalArgumentException("Not a photo")
        val photo = rotatedFromExif(input, decoded)
        val tracker = still ?: landmarker(RunningMode.IMAGE).also { still = it }
        val argb = photo.copy(Bitmap.Config.ARGB_8888, false)
        val pose = poseOf(tracker.detect(BitmapImageBuilder(argb).build()), argb.width, argb.height)
            ?: return null

        val out = argb.copy(Bitmap.Config.ARGB_8888, true)
        val sticker = BitmapFactory.decodeFile(args["sticker"] as String)
            ?: throw IllegalArgumentException("No sticker")
        val scale = (pose[2] * out.width / STICKER_PIXELS_PER_UNIT).toFloat()
        val place = Matrix().apply {
            postTranslate(-sticker.width / 2f, -sticker.height / 2f)
            postScale(scale, scale)
            postRotate(Math.toDegrees(pose[3]).toFloat())
            postTranslate((pose[0] * out.width).toFloat(), (pose[1] * out.height).toFloat())
        }
        Canvas(out).drawBitmap(sticker, place, Paint(Paint.FILTER_BITMAP_FLAG))
        val file = File(context.cacheDir, "insync_face_${System.currentTimeMillis()}.jpg")
        FileOutputStream(file).use { out.compress(Bitmap.CompressFormat.JPEG, 90, it) }
        return file.absolutePath
    }

    private fun rotatedFromExif(path: String, bitmap: Bitmap): Bitmap {
        val exif = androidx.exifinterface.media.ExifInterface(path)
        val degrees = exif.rotationDegrees
        if (degrees == 0) return bitmap
        val m = Matrix().apply { postRotate(degrees.toFloat()) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, m, true)
    }

    private fun bakeVideo(args: Map<*, *>, result: MethodChannel.Result) {
        try {
            val sticker = BitmapFactory.decodeFile(args["sticker"] as String)
                ?: throw IllegalArgumentException("No sticker")
            val track = (args["track"] as List<*>).map { row ->
                (row as List<*>).map { (it as Number).toDouble() }.toDoubleArray()
            }
            val overlay: TextureOverlay = TrackedSticker(sticker, track)
            val edited = EditedMediaItem.Builder(
                MediaItem.fromUri(Uri.fromFile(File(args["input"] as String)))
            )
                .setEffects(Effects(emptyList(), listOf(OverlayEffect(ImmutableList.of(overlay)))))
                .build()
            val output = File(context.cacheDir, "insync_face_${System.currentTimeMillis()}.mp4")
            Transformer.Builder(context)
                // The edit step encodes for upload later, so keep this one clean.
                .setEncoderFactory(
                    DefaultEncoderFactory.Builder(context)
                        .setRequestedVideoEncoderSettings(
                            VideoEncoderSettings.Builder().setBitrate(8_000_000).build()
                        )
                        .build()
                )
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(c: Composition, r: ExportResult) {
                        result.success(output.absolutePath)
                    }

                    override fun onError(c: Composition, r: ExportResult, e: ExportException) {
                        result.error("face", e.message ?: "Could not add the filter", null)
                    }
                })
                .build()
                .start(edited, output.absolutePath)
        } catch (e: Exception) {
            result.error("face", e.message ?: "Could not add the filter", null)
        }
    }

    private companion object {
        const val LEFT_EYE_CORNER = 33
        const val RIGHT_EYE_CORNER = 263
        const val LEFT_CHEEK = 234
        const val RIGHT_CHEEK = 454

        // FaceFilter.stickerPixels / stickerUnits on the Dart side.
        const val STICKER_PIXELS_PER_UNIT = 256.0
    }

    // Moves one sticker image along the track recorded while filming.
    private class TrackedSticker(
        private val sticker: Bitmap,
        private val track: List<DoubleArray>,
    ) : BitmapOverlay() {
        private var frame = Size(1, 1)

        override fun configure(videoSize: Size) {
            super.configure(videoSize)
            frame = videoSize
        }

        override fun getBitmap(presentationTimeUs: Long): Bitmap = sticker

        override fun getOverlaySettings(presentationTimeUs: Long): OverlaySettings {
            val pose = poseAt(presentationTimeUs / 1000.0)
                ?: return OverlaySettings.Builder().setAlphaScale(0f).build()
            val scale = (pose[2] * frame.width / STICKER_PIXELS_PER_UNIT).toFloat()
            return OverlaySettings.Builder()
                .setScale(scale, scale)
                // OpenGL turns the other way from the screen.
                .setRotationDegrees(-Math.toDegrees(pose[3]).toFloat())
                .setBackgroundFrameAnchor(
                    (pose[0] * 2 - 1).toFloat(),
                    (1 - pose[1] * 2).toFloat(),
                )
                .build()
        }

        // Row: time, x, y, width, angle. Hidden when the face was lost.
        private fun poseAt(ms: Double): DoubleArray? {
            if (track.isEmpty()) return null
            var after = track.indexOfFirst { it[0] >= ms }
            if (after == -1) after = track.size - 1
            val b = track[after]
            val a = if (after > 0) track[after - 1] else b
            val nearest = minOf(abs(a[0] - ms), abs(b[0] - ms))
            if (nearest > LOST_AFTER_MS) return null
            val span = b[0] - a[0]
            val t = if (span <= 0) 0.0 else ((ms - a[0]) / span).coerceIn(0.0, 1.0)
            return DoubleArray(4) { a[it + 1] + (b[it + 1] - a[it + 1]) * t }
        }

        private companion object {
            const val LOST_AFTER_MS = 400.0
        }
    }
}
