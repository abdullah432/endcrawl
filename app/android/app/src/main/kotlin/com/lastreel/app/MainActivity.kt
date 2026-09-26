package com.lastreel.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(VideoEncoderPlugin())
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            LastReelNativeAdFactory.ID,
            LastReelNativeAdFactory(applicationContext),
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, LastReelNativeAdFactory.ID)
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
