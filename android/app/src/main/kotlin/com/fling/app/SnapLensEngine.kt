package com.fling.app

import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Log
import androidx.lifecycle.LifecycleOwner
import com.snap.camerakit.ImageProcessor
import com.snap.camerakit.Session
import com.snap.camerakit.invoke
import com.snap.camerakit.newBuilder
import com.snap.camerakit.lenses.LensesComponent
import com.snap.camerakit.support.camerax.CameraXImageProcessorSource
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.BinaryCodec
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.Closeable
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer

/**
 * Snap Camera Kit lenses inside InSync's own screens (lib/core/snap_lens_engine.dart).
 *
 * One Camera Kit session at a time, fed by the phone camera (CameraX). What
 * it draws goes to:
 * - a Flutter texture, so Dart shows it with a Texture widget under our
 *   own buttons (the create camera, the lens row in calls and live rooms);
 * - when asked, an ImageReader whose frames go to Dart over
 *   "com.fling.app/snap_frames" (RGBA bytes) to be sent into the Agora call
 *   as a custom video track.
 *
 * Lens list, apply/clear, flip, flash, photo and video are method calls on
 * "com.fling.app/snap_engine".
 */
class SnapLensEngine(
    private val activity: Activity,
    messenger: BinaryMessenger,
    private val textures: TextureRegistry,
) {
    private val main = Handler(Looper.getMainLooper())
    private val frames = BasicMessageChannel(messenger, "com.fling.app/snap_frames", BinaryCodec.INSTANCE)

    private var session: Session? = null
    private var source: CameraXImageProcessorSource? = null
    private var texture: TextureRegistry.SurfaceTextureEntry? = null
    private var textureOut: Closeable? = null
    private var front = true
    private var lenses: List<LensesComponent.Lens> = emptyList()
    private var recording: Closeable? = null
    private var flash: Closeable? = null

    private var reader: ImageReader? = null
    private var readerOut: Closeable? = null
    private var readerThread: HandlerThread? = null
    private var frameGapMs = 66L
    private var lastFrameAt = 0L
    private var frameBusy = false

    private val channel = MethodChannel(messenger, "com.fling.app/snap_engine")

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "supported" -> result.success(apiToken().isNotBlank())
                    "start" -> start(
                        call.argument<Boolean>("front") ?: true,
                        call.argument<Int>("width") ?: 720,
                        call.argument<Int>("height") ?: 1280,
                        result,
                    )
                    "lenses" -> loadLenses(call.argument<List<String>>("groupIds").orEmpty(), result)
                    "apply" -> apply(call.argument<String>("id"), result)
                    "flip" -> {
                        front = !front
                        source?.startPreview(front)
                        result.success(front)
                    }
                    "flash" -> {
                        flash?.close()
                        flash = if (call.argument<Boolean>("on") == true) source?.enableCameraFlash() else null
                        result.success(null)
                    }
                    "takePhoto" -> takePhoto(result)
                    "startVideo" -> startVideo(result)
                    "stopVideo" -> {
                        recording?.close()
                        recording = null
                        result.success(null)
                    }
                    "startFrames" -> {
                        startFrames(
                            call.argument<Int>("width") ?: 480,
                            call.argument<Int>("height") ?: 640,
                            call.argument<Int>("fps") ?: 15,
                        )
                        result.success(null)
                    }
                    "stopFrames" -> {
                        stopFrames()
                        result.success(null)
                    }
                    "stop" -> {
                        stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.w(TAG, "${call.method} failed", e)
                result.error("snap_engine", e.message, null)
            }
        }
    }

    // ---- session

    private fun start(front: Boolean, width: Int, height: Int, result: MethodChannel.Result) {
        val token = apiToken()
        if (token.isBlank()) {
            result.error("not_configured", "Snap Camera Kit token missing", null)
            return
        }
        this.front = front
        if (session == null) {
            val src = CameraXImageProcessorSource(activity, activity as LifecycleOwner)
            source = src
            session = Session.newBuilder(activity)
                .apiToken(token)
                .imageProcessorSource(src)
                .handleErrorsWith { e: Throwable -> Log.w(TAG, "Camera Kit error", e) }
                .build()
        }
        val s = session!!
        textureOut?.close()
        texture?.release()
        val entry = textures.createSurfaceTexture()
        entry.surfaceTexture().setDefaultBufferSize(width, height)
        texture = entry
        textureOut = s.processor.connectOutput(
            ImageProcessor.Output(entry.surfaceTexture(), ImageProcessor.Output.Purpose.PREVIEW, 0)
        )
        source?.startPreview(front)
        result.success(mapOf("textureId" to entry.id(), "width" to width, "height" to height))
    }

    private fun stop() {
        stopFrames()
        recording?.close()
        recording = null
        flash?.close()
        flash = null
        textureOut?.close()
        textureOut = null
        try {
            source?.stopPreview()
        } catch (_: Exception) {
        }
        session?.close()
        session = null
        source = null
        texture?.release()
        texture = null
    }

    // ---- lenses

    private fun loadLenses(groupIds: List<String>, result: MethodChannel.Result) {
        if (groupIds.isEmpty() || apiToken().isBlank()) {
            result.success(emptyList<Map<String, Any?>>())
            return
        }
        // Without a running camera, a short-lived session just for the list.
        val temp = if (session == null) Session.newBuilder(activity).apiToken(apiToken()).build() else null
        val s = session ?: temp!!
        s.lenses.repository.get(
            LensesComponent.Repository.QueryCriteria.Available(groupIds.toSet())
        ) { found ->
            val list = (found as? LensesComponent.Repository.Result.Some)?.lenses.orEmpty()
            lenses = list
            val out = list.map {
                mapOf(
                    "id" to it.id,
                    "groupId" to it.groupId,
                    "name" to it.name,
                    "icon" to it.iconUri,
                )
            }
            main.post {
                result.success(out)
                temp?.close()
            }
        }
    }

    private fun apply(id: String?, result: MethodChannel.Result) {
        val s = session
        if (s == null) {
            result.success(false)
            return
        }
        if (id == null) {
            s.lenses.processor.clear { ok -> main.post { result.success(ok) } }
            return
        }
        val lens = lenses.firstOrNull { it.id == id }
        if (lens == null) {
            result.success(false)
            return
        }
        s.lenses.processor.apply(lens) { ok -> main.post { result.success(ok) } }
    }

    // ---- photo and video (with the lens on)

    private fun takePhoto(result: MethodChannel.Result) {
        val src = source
        if (src == null) {
            result.error("not_started", "Camera not started", null)
            return
        }
        src.takePhoto { bitmap: Bitmap ->
            try {
                val file = File(activity.cacheDir, "snap_${System.currentTimeMillis()}.jpg")
                FileOutputStream(file).use { bitmap.compress(Bitmap.CompressFormat.JPEG, 92, it) }
                main.post { result.success(file.absolutePath) }
            } catch (e: Exception) {
                main.post { result.error("photo_failed", e.message, null) }
            }
        }
    }

    private fun startVideo(result: MethodChannel.Result) {
        val src = source
        if (src == null || recording != null) {
            result.error("not_started", "Camera not started or already recording", null)
            return
        }
        // The file arrives once recording stops (stopVideo); Dart waits on
        // the "videoDone" call for it.
        recording = src.takeVideo { file: File ->
            main.post { channel.invokeMethod("videoDone", file.absolutePath) }
        }
        result.success(null)
    }

    // ---- frames for calls (RGBA, throttled)

    private fun startFrames(width: Int, height: Int, fps: Int) {
        val s = session ?: return
        stopFrames()
        frameGapMs = (1000L / fps.coerceIn(5, 30))
        val thread = HandlerThread("snap-frames").also { it.start() }
        readerThread = thread
        val r = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 3)
        reader = r
        r.setOnImageAvailableListener({ ir ->
            val image = ir.acquireLatestImage() ?: return@setOnImageAvailableListener
            try {
                val now = System.currentTimeMillis()
                if (frameBusy || now - lastFrameAt < frameGapMs) {
                    return@setOnImageAvailableListener
                }
                lastFrameAt = now
                val plane = image.planes[0]
                val w = image.width
                val h = image.height
                val rowBytes = w * 4
                // 8-byte header (width, height as big-endian ints), then the pixels.
                val out = ByteBuffer.allocateDirect(8 + rowBytes * h)
                out.putInt(w).putInt(h)
                val src = plane.buffer
                if (plane.rowStride == rowBytes) {
                    src.limit(rowBytes * h)
                    out.put(src)
                } else {
                    val row = ByteArray(rowBytes)
                    for (y in 0 until h) {
                        src.position(y * plane.rowStride)
                        src.get(row, 0, rowBytes)
                        out.put(row)
                    }
                }
                out.flip()
                frameBusy = true
                main.post {
                    frames.send(out) { frameBusy = false }
                }
            } finally {
                image.close()
            }
        }, Handler(thread.looper))
        readerOut = s.processor.connectOutput(
            ImageProcessor.Output(r.surface, ImageProcessor.Output.Purpose.RECORDING, 0)
        )
    }

    private fun stopFrames() {
        readerOut?.close()
        readerOut = null
        reader?.close()
        reader = null
        readerThread?.quitSafely()
        readerThread = null
        frameBusy = false
    }

    private fun apiToken(): String {
        val info = activity.packageManager.getApplicationInfo(activity.packageName, PackageManager.GET_META_DATA)
        return info.metaData?.getString("com.snap.camerakit.api.token").orEmpty()
    }

    private companion object {
        const val TAG = "SnapLensEngine"
    }
}
