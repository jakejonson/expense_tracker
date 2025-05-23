package com.example.expense_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.expense_tracker/transactions"
    private var eventSink: EventChannel.EventSink? = null
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.example.expense_tracker.TRANSACTION_DETECTED") {
                val amount = intent.getDoubleExtra("amount", 0.0)
                val description = intent.getStringExtra("description") ?: ""
                val date = intent.getLongExtra("date", 0)
                
                val event = mapOf(
                    "amount" to amount,
                    "description" to description,
                    "date" to date
                )
                eventSink?.success(event)
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    registerReceiver(receiver, IntentFilter("com.example.expense_tracker.TRANSACTION_DETECTED"))
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    unregisterReceiver(receiver)
                }
            }
        )
    }
}
