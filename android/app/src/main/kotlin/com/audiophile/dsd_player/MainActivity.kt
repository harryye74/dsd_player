package com.audiophile.dsd_player

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val SMB_CHANNEL = "com.audiophile.dsd_player/smb"
        private const val DSD_METHOD = "com.audiophile.dsd_player/dsd"
        private const val DSD_EVENT = "com.audiophile.dsd_player/dsd/state"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val smb = SmbPlugin(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SMB_CHANNEL
        ).setMethodCallHandler(smb)

        val dsd = DsdPlugin()
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DSD_METHOD
        ).setMethodCallHandler(dsd)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DSD_EVENT
        ).setStreamHandler(dsd)
    }

    override fun getContext(): Context = this
}
