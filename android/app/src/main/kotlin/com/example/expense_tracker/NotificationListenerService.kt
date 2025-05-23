package com.example.expense_tracker

import android.app.Notification
import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.util.regex.Pattern

class NotificationListenerService : NotificationListenerService() {
    companion object {
        private const val TAG = "SamsungWalletListener"
        private const val SAMSUNG_WALLET_PACKAGE = "com.samsung.android.spay"
        private val AMOUNT_PATTERN = Pattern.compile("""\$\d+(\.\d{2})?""")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName == SAMSUNG_WALLET_PACKAGE) {
            val notification = sbn.notification
            val extras = notification.extras
            
            // Get notification text
            val title = extras.getString(Notification.EXTRA_TITLE) ?: return
            val text = extras.getString(Notification.EXTRA_TEXT) ?: return
            
            Log.d(TAG, "Samsung Wallet notification: $title - $text")
            
            // Check if this is a transaction notification
            if (!title.contains("Payment", ignoreCase = true) && 
                !title.contains("Transaction", ignoreCase = true)) {
                return
            }
            
            // Extract amount
            val amountMatcher = AMOUNT_PATTERN.matcher(text)
            if (!amountMatcher.find()) {
                Log.d(TAG, "No amount found in notification")
                return
            }
            
            val amountStr = amountMatcher.group().replace("$", "")
            val amount = amountStr.toDoubleOrNull() ?: return
            
            // Create intent to send data to Flutter
            val intent = Intent("com.example.expense_tracker.TRANSACTION_DETECTED").apply {
                putExtra("amount", amount)
                putExtra("description", text)
                putExtra("date", System.currentTimeMillis())
            }
            sendBroadcast(intent)
            
            Log.d(TAG, "Transaction detected: Amount=$amount, Description=$text")
        }
    }
} 