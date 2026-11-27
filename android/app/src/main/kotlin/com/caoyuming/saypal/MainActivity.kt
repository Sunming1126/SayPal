package com.caoyuming.saypal

import android.content.Intent
import com.japaneseengteacher.app.TrainingSelectActivity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "saypal/oral_practice",
        ).setMethodCallHandler { call, result ->
            if (call.method == "open") {
                startActivity(Intent(this, TrainingSelectActivity::class.java))
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
