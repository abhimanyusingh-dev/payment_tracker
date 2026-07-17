package com.example.payment_tracker

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.util.Log

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i("PaymentTracker", "App package name: $packageName")
    }
}
