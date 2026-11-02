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
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.GlEffect
import androidx.media3.effect.GlShaderProgram
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.common.audio.ChannelMixingAudioProcessor
import androidx.media3.common.audio.ChannelMixingMatrix
import androidx.media3.common.audio.SonicAudioProcessor
import androidx.media3.effect.RgbMatrix
import androidx.media3.effect.SpeedChangeEffect
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
                "videoFrame" -> Thread {
                    val out = try {
                        videoFrame(call.arguments as Map<*, *>)
                    } catch (e: Exception) {
                        null
                    }
                    android.os.Handler(context.mainLooper).post {
                        if (out != null) result.success(out)
                        else result.error("frame", "Could not read this clip", null)
                    }
                }.start()
                "saveToGallery" -> saveToGallery(call.arguments as Map<*, *>, result)
                else -> result.notImplemented()
            }
        }
    }

    // One small frame, for choosing a reel's cover.
    private fun videoFrame(args: Map<*, *>): String {
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(args["input"] as String)
            val atUs = (args["atMs"] as Number).toLong() * 1000
            val frame = r.getFrameAtTime(atUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                ?: throw IllegalStateException("No frame")
            val scale = min(1f, 480f / frame.width)
            val small = Bitmap.createScaledBitmap(
                frame, (frame.width * scale).roundToInt(), (frame.height * scale).roundToInt(), true,
            )
            val file = outFile("jpg")
            FileOutputStream(file).use { small.compress(Bitmap.CompressFormat.JPEG, 70, it) }
            return file.absolutePath
        } finally {
            r.release()
        }
    }

    private fun saveToGallery(args: Map<*, *>, result: MethodChannel.Result) {
        val input = args["input"] as String
        val overlay = args["overlay"] as? String
        val storyShape = args["storyShape"] == true
        fun finish(done: () -> Unit) = Thread {
            val error = try {
                done()
                null
            } catch (e: Exception) {
                e.message ?: "Could not save"
            }
            android.os.Handler(context.mainLooper).post {
                if (error == null) result.success(null) else result.error("save", error, null)
            }
        }.start()

        if (args["isVideo"] != true) {
            finish { publish(storyPhoto(input, overlay, storyShape), "image/jpeg") }
            return
        }
        if (overlay == null && !storyShape) {
            finish { publish(File(input), "video/mp4") }
            return
        }
        try {
            val effects = ArrayList<androidx.media3.common.Effect>()
            effects.add(
                Presentation.createForWidthAndHeight(
                    STORY_WIDTH, STORY_HEIGHT, Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP,
                )
            )
            overlay?.let { path ->
                val bitmap = BitmapFactory.decodeFile(path)
                    ?: throw IllegalArgumentException("No overlay")
                val scaled = Bitmap.createScaledBitmap(bitmap, STORY_WIDTH, STORY_HEIGHT, true)
                effects.add(
                    OverlayEffect(ImmutableList.of<TextureOverlay>(BitmapOverlay.createStaticBitmapOverlay(scaled)))
                )
            }
            val edited = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(input))))
                .setEffects(Effects(emptyList(), effects))
                .build()
            val output = outFile("mp4")
            Transformer.Builder(context)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(c: Composition, r: ExportResult) {
                        finish { publish(output, "video/mp4") }
                    }

                    override fun onError(c: Composition, r: ExportResult, e: ExportException) {
                        result.error("save", e.message ?: "Could not save", null)
                    }
                })
                .build()
                .start(edited, output.absolutePath)
        } catch (e: Exception) {
            result.error("save", e.message ?: "Could not save", null)
        }
    }

    private fun storyPhoto(input: String, overlay: String?, storyShape: Boolean): File {
        val decoded = BitmapFactory.decodeFile(input)
            ?: throw IllegalArgumentException("Not a photo")
        val photo = rotateFromExif(input, decoded)
        val out: Bitmap
        if (storyShape) {
            out = Bitmap.createBitmap(STORY_WIDTH, STORY_HEIGHT, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(out)
            // Fills the frame and crops the rest, as the editor shows it.
            val scale = max(
                STORY_WIDTH.toFloat() / photo.width,
                STORY_HEIGHT.toFloat() / photo.height,
            )
            val w = photo.width * scale
            val h = photo.height * scale
            val left = (STORY_WIDTH - w) / 2
            val top = (STORY_HEIGHT - h) / 2
            val paint = Paint(Paint.FILTER_BITMAP_FLAG)
            canvas.drawBitmap(photo, null, android.graphics.RectF(left, top, left + w, top + h), paint)
            overlay?.let { path ->
                BitmapFactory.decodeFile(path)?.let {
                    canvas.drawBitmap(it, null, android.graphics.Rect(0, 0, STORY_WIDTH, STORY_HEIGHT), paint)
                }
            }
        } else {
            out = photo
        }
        val file = outFile("jpg")
        FileOutputStream(file).use { out.compress(Bitmap.CompressFormat.JPEG, 92, it) }
        return file
    }

    // Android 10 and later need no storage permission to add to the gallery.
    private fun publish(file: File, mime: String) {
        val video = mime.startsWith("video")
        val values = android.content.ContentValues().apply {
            put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, "Insync_${System.currentTimeMillis()}")
            put(android.provider.MediaStore.MediaColumns.MIME_TYPE, mime)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                put(
                    android.provider.MediaStore.MediaColumns.RELATIVE_PATH,
                    (if (video) android.os.Environment.DIRECTORY_MOVIES else android.os.Environment.DIRECTORY_PICTURES) + "/Insync",
                )
            } else {
                throw IllegalStateException("Saving needs Android 10 or later")
            }
        }
        val collection = if (video) {
            android.provider.MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        } else {
            android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }
        val uri = context.contentResolver.insert(collection, values)
            ?: throw IllegalStateException("Gallery unavailable")
        context.contentResolver.openOutputStream(uri)?.use { sink ->
            file.inputStream().use { it.copyTo(sink) }
        } ?: throw IllegalStateException("Gallery unavailable")
    }

    private companion object {
        const val STORY_WIDTH = 720
        const val STORY_HEIGHT = 1280
    }

    private fun outFile(ext: String) =
        File(context.cacheDir, "insync_edit_${System.currentTimeMillis()}.$ext")

    private fun matrixOf(args: Map<*, *>): FloatArray? =
        (args["matrix"] as? List<*>)?.map { (it as Number).toFloat() }?.toFloatArray()

    // Added to every colour channel, as a share of full brightness.
    private fun offsetOf(args: Map<*, *>): Float = (args["offset"] as? Number)?.toFloat() ?: 0f

    private fun processVideo(args: Map<*, *>, result: MethodChannel.Result) {
        try {
            val input = args["input"] as String
            val start = (args["startMs"] as Number).toLong()
            val end = (args["endMs"] as Number).toLong()
            val matrix = matrixOf(args)
            val cartoon = args["cartoon"] == true
            val mute = args["mute"] == true
            val speed = (args["speed"] as? Number)?.toFloat() ?: 1f

            val effects = ArrayList<androidx.media3.common.Effect>()
            matrix?.let { m ->
                // Rows from Dart, columns for OpenGL.
                val gl = floatArrayOf(
                    m[0], m[3], m[6], 0f,
                    m[1], m[4], m[7], 0f,
                    m[2], m[5], m[8], 0f,
                    offsetOf(args), offsetOf(args), offsetOf(args), 1f,
                )
                effects.add(RgbMatrix { _, _ -> gl })
            }
            if (cartoon) effects.add(CartoonEffect())
            val audioEffects = ArrayList<androidx.media3.common.audio.AudioProcessor>()
            val volume = (args["volume"] as? Number)?.toFloat() ?: 1f
            if (volume != 1f) {
                audioEffects.add(ChannelMixingAudioProcessor().apply {
                    putChannelMixingMatrix(ChannelMixingMatrix.create(1, 1).scaleBy(volume))
                    putChannelMixingMatrix(ChannelMixingMatrix.create(2, 2).scaleBy(volume))
                })
            }
            if (speed != 1f) {
                effects.add(SpeedChangeEffect(speed))
                audioEffects.add(SonicAudioProcessor().apply { setSpeed(speed) })
            }
            // Always re-encodes, so every clip fits the upload limit.
            val height = targetHeight(input)
            effects.add(Presentation.createForHeight(height))
            // Text on the clip: a transparent picture the clip's own size.
            (args["overlay"] as? String)?.let { path ->
                val bitmap = BitmapFactory.decodeFile(path)
                    ?: throw IllegalArgumentException("No overlay")
                val width = (height * clipAspect(input)).roundToInt() / 2 * 2
                effects.add(
                    OverlayEffect(
                        ImmutableList.of<TextureOverlay>(
                            BitmapOverlay.createStaticBitmapOverlay(
                                Bitmap.createScaledBitmap(bitmap, width, height, true)
                            )
                        )
                    )
                )
            }

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
                .setEffects(Effects(audioEffects, effects))
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

    // Width over height, as the clip is watched.
    private fun clipAspect(path: String): Float {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(path)
            val w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toFloatOrNull() ?: 720f
            val h = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toFloatOrNull() ?: 1280f
            val rotation = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            if (rotation == 90 || rotation == 270) h / w else w / h
        } finally {
            r.release()
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
        val rotated = cropAndTurn(rotateFromExif(input, decoded), args)
        val out = Bitmap.createBitmap(rotated.width, rotated.height, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.FILTER_BITMAP_FLAG)
        matrixOf(args)?.let { m ->
            paint.colorFilter = ColorMatrixColorFilter(
                ColorMatrix(
                    floatArrayOf(
                        m[0], m[1], m[2], 0f, offsetOf(args) * 255f,
                        m[3], m[4], m[5], 0f, offsetOf(args) * 255f,
                        m[6], m[7], m[8], 0f, offsetOf(args) * 255f,
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

    // Quarter turns, then the middle of the picture at the chosen shape.
    private fun cropAndTurn(source: Bitmap, args: Map<*, *>): Bitmap {
        val turns = (args["turns"] as? Number)?.toInt() ?: 0
        val turned = if (turns % 4 == 0) source else {
            val m = android.graphics.Matrix().apply { postRotate(90f * turns) }
            Bitmap.createBitmap(source, 0, 0, source.width, source.height, m, true)
        }
        val aspect = (args["aspect"] as? Number)?.toFloat() ?: return turned
        val w = turned.width
        val h = turned.height
        val cropW = min(w.toFloat(), h * aspect).roundToInt().coerceAtLeast(1)
        val cropH = min(h.toFloat(), w / aspect).roundToInt().coerceAtLeast(1)
        return Bitmap.createBitmap(turned, (w - cropW) / 2, (h - cropH) / 2, cropW, cropH)
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
