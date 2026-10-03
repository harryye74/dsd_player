package com.audiophile.dsd_player

import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.audiophile.dsd_player.audio.DsdAudioEngine

/**
 * DSD 播放插件：管理单个 DsdAudioEngine 实例，
 * 通过 MethodChannel 接收指令，通过 EventChannel 回传播放状态。
 */
class DsdPlugin : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val engine = DsdAudioEngine()
    private var sink: EventChannel.EventSink? = null

    init {
        engine.onState = { state, positionMs, dsdMode, message ->
            val m = HashMap<String, Any?>()
            m["state"] = state
            m["positionMs"] = positionMs
            m["dsdMode"] = dsdMode
            m["message"] = message
            sink?.success(m)
        }
    }

    override fun onMethodCall(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(engine.isSupported())
            "load" -> {
                val path = call.argument<String>("path") ?: ""
                val bitPerfect = call.argument<Boolean>("bitPerfect") ?: true
                val doP = call.argument<Boolean>("doP") ?: true
                result.success(engine.load(path, bitPerfect, doP))
            }
            "play" -> { engine.play(); result.success(null) }
            "pause" -> { engine.pause(); result.success(null) }
            "stop" -> { engine.stop(); result.success(null) }
            "seek" -> {
                val ms = call.argument<Int>("ms") ?: 0
                engine.seek(ms)
                result.success(null)
            }
            "setVolume" -> {
                val v = call.argument<Double>("volume")?.toFloat() ?: 1f
                engine.setVolume(v)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }
}
