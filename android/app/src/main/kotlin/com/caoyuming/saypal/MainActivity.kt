package com.caoyuming.saypal

import android.content.Intent
import com.japaneseengteacher.app.LoginActivity
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
                startActivity(Intent(this, LoginActivity::class.java))
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
