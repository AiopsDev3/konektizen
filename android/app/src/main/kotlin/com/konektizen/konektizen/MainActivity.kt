package com.konektizen.konektizen

import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "pip_channel"
    private var isPiPMode = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPiP" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val builder = PictureInPictureParams.Builder()
                            // Set aspect ratio to 3:4 (portrait) for better face visibility
                            .setAspectRatio(Rational(3, 4))
                        
                        // Remove all actions/buttons from PiP window
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            builder.setActions(emptyList())
                            builder.setAutoEnterEnabled(false)
                            builder.setSeamlessResizeEnabled(true)
                        }
                        
                        val params = builder.build()
                        enterPictureInPictureMode(params)
                        result.success(true)
                    } else {
                        result.error("UNSUPPORTED", "PiP not supported on this Android version", null)
                    }
                }
                "exitPiP" -> {
                    // PiP mode exits automatically when user taps the window
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        isPiPMode = isInPictureInPictureMode
        
        // Notify Flutter about PiP mode change
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CHANNEL).invokeMethod("onPiPModeChanged", isPiPMode)
        }
    }
}
