package com.fling.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.opengl.GLES20
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.util.GlProgram
import androidx.media3.common.util.GlUtil
import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BaseGlShaderProgram
import androidx.media3.effect.GlEffect
import androidx.media3.effect.GlShaderProgram
import androidx.media3.effect.Presentation
import androidx.media3.effect.RgbMatrix
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

// Trims, filters and cartoons clips and photos on the phone itself, with
// Android's own Media3 library and no outside service. Dart side:
// core/video_edit.dart.
@OptIn(UnstableApi::class)
class VideoEditChannel(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "com.fling.app/video_edit")

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "processVideo" -> processVideo(call.arguments as Map<*, *>, result)
                "processPhoto" -> Thread {
                    val out = try {
                        processPhoto(call.arguments as Map<*, *>)
                    } catch (e: Exception) {
                        null
                    }
                    android.os.Handler(context.mainLooper).post {
                        if (out != null) result.success(out)
                        else result.error("photo", "Could not edit this photo", null)
                    }
                }.start()
                else -> result.notImplemented()
            }
        }
    }

    private fun outFile(ext: String) =
        File(context.cacheDir, "insync_edit_${System.currentTimeMillis()}.$ext")

    private fun matrixOf(args: Map<*, *>): FloatArray? =
        (args["matrix"] as? List<*>)?.map { (it as Number).toFloat() }?.toFloatArray()

    private fun processVideo(args: Map<*, *>, result: MethodChannel.Result) {
        try {
            val input = args["input"] as String
            val start = (args["startMs"] as Number).toLong()
            val end = (args["endMs"] as Number).toLong()
            val matrix = matrixOf(args)
            val cartoon = args["cartoon"] == true
            val mute = args["mute"] == true

            val effects = ArrayList<androidx.media3.common.Effect>()
            matrix?.let { m ->
                // Rows from Dart, columns for OpenGL.
                val gl = floatArrayOf(
                    m[0], m[3], m[6], 0f,
                    m[1], m[4], m[7], 0f,
                    m[2], m[5], m[8], 0f,
                    0f, 0f, 0f, 1f,
                )
                effects.add(RgbMatrix { _, _ -> gl })
            }
            if (cartoon) effects.add(CartoonEffect())
            // Always re-encodes, so every clip fits the upload limit.
            effects.add(Presentation.createForHeight(targetHeight(input)))

            val item = MediaItem.Builder()
                .setUri(Uri.fromFile(File(input)))
                .setClippingConfiguration(
                    MediaItem.ClippingConfiguration.Builder()
                        .setStartPositionMs(start)
                        .setEndPositionMs(end)
                        .build()
                )
                .build()
            val edited = EditedMediaItem.Builder(item)
                .setRemoveAudio(mute)
                .setEffects(Effects(emptyList(), effects))
                .build()

            val output = outFile("mp4")
            val transformer = Transformer.Builder(context)
                .setEncoderFactory(
                    DefaultEncoderFactory.Builder(context)
                        .setRequestedVideoEncoderSettings(
                            VideoEncoderSettings.Builder().setBitrate(1_800_000).build()
                        )
                        .build()
                )
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(c: Composition, r: ExportResult) {
                        result.success(output.absolutePath)
                    }

                    override fun onError(c: Composition, r: ExportResult, e: ExportException) {
                        result.error("video", e.message ?: "Could not edit this clip", null)
                    }
                })
                .build()
            transformer.start(edited, output.absolutePath)
        } catch (e: Exception) {
            result.error("video", e.message ?: "Could not edit this clip", null)
        }
    }

    // Keeps the short side at 720, whichever way round the clip is.
    private fun targetHeight(path: String): Int {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(path)
            var w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 720
            var h = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 1280
            val rotation = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            if (rotation == 90 || rotation == 270) { val t = w; w = h; h = t }
            val shortSide = min(w, h).coerceAtLeast(1)
            val scale = min(1f, 720f / shortSide)
            (h * scale).roundToInt() / 2 * 2
        } catch (e: Exception) {
            1280
        } finally {
            r.release()
        }
    }

    private fun processPhoto(args: Map<*, *>): String {
        val input = args["input"] as String
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(input, bounds)
        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / sample > 1440) sample *= 2
        val decoded = BitmapFactory.decodeFile(input, BitmapFactory.Options().apply { inSampleSize = sample })
            ?: throw IllegalArgumentException("Not a photo")
        val rotated = rotateFromExif(input, decoded)
        val out = Bitmap.createBitmap(rotated.width, rotated.height, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.FILTER_BITMAP_FLAG)
        matrixOf(args)?.let { m ->
            paint.colorFilter = ColorMatrixColorFilter(
                ColorMatrix(
                    floatArrayOf(
                        m[0], m[1], m[2], 0f, 0f,
                        m[3], m[4], m[5], 0f, 0f,
                        m[6], m[7], m[8], 0f, 0f,
                        0f, 0f, 0f, 1f, 0f,
                    )
                )
            )
        }
        Canvas(out).drawBitmap(rotated, 0f, 0f, paint)
        if (args["cartoon"] == true) cartoonise(out)
        val file = outFile("jpg")
        FileOutputStream(file).use { out.compress(Bitmap.CompressFormat.JPEG, 80, it) }
        return file.absolutePath
    }

    private fun rotateFromExif(path: String, bitmap: Bitmap): Bitmap {
        val degrees = try {
            when (androidx.exifinterface.media.ExifInterface(path).getAttributeInt(
                androidx.exifinterface.media.ExifInterface.TAG_ORIENTATION, 1
            )) {
                androidx.exifinterface.media.ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                androidx.exifinterface.media.ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                androidx.exifinterface.media.ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
        } catch (e: Exception) {
            0f
        }
        if (degrees == 0f) return bitmap
        val m = android.graphics.Matrix().apply { postRotate(degrees) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, m, true)
    }

    // Flat colour bands plus dark outlines: the same look as CartoonEffect.
    private fun cartoonise(b: Bitmap) {
        val w = b.width
        val h = b.height
        val src = IntArray(w * h)
        b.getPixels(src, 0, w, 0, 0, w, h)
        val dst = IntArray(w * h)
        fun luma(c: Int) =
            (((c shr 16) and 255) * 299 + ((c shr 8) and 255) * 587 + (c and 255) * 114) / 1000
        fun band(v: Int) = (((v / 255f * 6f).roundToInt() / 6f) * 255f).roundToInt().coerceIn(0, 255)
        for (y in 0 until h) for (x in 0 until w) {
            val i = y * w + x
            val c = src[i]
            val l = if (x > 0) src[i - 1] else c
            val r = if (x < w - 1) src[i + 1] else c
            val u = if (y > 0) src[i - w] else c
            val d = if (y < h - 1) src[i + w] else c
            val edge = abs(luma(r) - luma(l)) + abs(luma(d) - luma(u))
            dst[i] = if (edge > 70) {
                0xFF141014.toInt()
            } else {
                (0xFF shl 24) or (band((c shr 16) and 255) shl 16) or
                    (band((c shr 8) and 255) shl 8) or band(c and 255)
            }
        }
        b.setPixels(dst, 0, w, 0, 0, w, h)
    }
}

@OptIn(UnstableApi::class)
private class CartoonEffect : GlEffect {
    override fun toGlShaderProgram(context: Context, useHdr: Boolean): GlShaderProgram =
        CartoonProgram(useHdr)
}

@OptIn(UnstableApi::class)
private class CartoonProgram(useHdr: Boolean) : BaseGlShaderProgram(useHdr, 1) {
    private val program = GlProgram(VERTEX, FRAGMENT)
    private var size = Size(1, 1)

    init {
        program.setBufferAttribute(
            "aFramePosition",
            GlUtil.getNormalizedCoordinateBounds(),
            GlUtil.HOMOGENEOUS_COORDINATE_VECTOR_SIZE,
        )
    }

    override fun configure(inputWidth: Int, inputHeight: Int): Size {
        size = Size(inputWidth, inputHeight)
        return size
    }

    override fun drawFrame(inputTexId: Int, presentationTimeUs: Long) {
        program.use()
        program.setSamplerTexIdUniform("uTexSampler", inputTexId, 0)
        program.setFloatsUniform(
            "uTexel",
            floatArrayOf(1f / size.width, 1f / size.height),
        )
        program.bindAttributesAndUniforms()
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
    }

    override fun release() {
        super.release()
        program.delete()
    }

    private companion object {
        const val VERTEX = """
            attribute vec4 aFramePosition;
            varying vec2 vTexCoords;
            void main() {
              gl_Position = aFramePosition;
              vTexCoords = (aFramePosition.xy + 1.0) * 0.5;
            }
        """
        const val FRAGMENT = """
            precision mediump float;
            uniform sampler2D uTexSampler;
            uniform vec2 uTexel;
            varying vec2 vTexCoords;
            float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
            void main() {
              vec3 c = texture2D(uTexSampler, vTexCoords).rgb;
              float l = luma(texture2D(uTexSampler, vTexCoords - vec2(uTexel.x, 0.0)).rgb);
              float r = luma(texture2D(uTexSampler, vTexCoords + vec2(uTexel.x, 0.0)).rgb);
              float u = luma(texture2D(uTexSampler, vTexCoords - vec2(0.0, uTexel.y)).rgb);
              float d = luma(texture2D(uTexSampler, vTexCoords + vec2(0.0, uTexel.y)).rgb);
              float edge = abs(r - l) + abs(d - u);
              vec3 band = floor(c * 6.0 + 0.5) / 6.0;
              gl_FragColor = vec4(edge > 0.27 ? vec3(0.08, 0.06, 0.08) : band, 1.0);
            }
        """
    }
}
