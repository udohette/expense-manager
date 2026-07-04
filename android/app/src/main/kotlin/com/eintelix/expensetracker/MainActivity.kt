package com.eintelix.expensetracker

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val smsChannel = "com.eintelix.expensetracker/sms_import"
    private val smsEventsChannel = "com.eintelix.expensetracker/sms_import_events"
    private val readSmsRequestCode = 4107
    private var pendingResult: MethodChannel.Result? = null
    private var pendingCall: MethodCall? = null
    private var smsEventSink: EventChannel.EventSink? = null
    private var smsReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, smsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasSmsPermission" -> result.success(hasSmsPermission())
                    "getSmsMessages" -> handleGetSmsMessages(call, result)
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, smsEventsChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    smsEventSink = events
                    registerSmsReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    smsEventSink = null
                    unregisterSmsReceiver()
                }
            })
    }

    private fun hasSmsPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_SMS
            ) == PackageManager.PERMISSION_GRANTED
    }

    private fun handleGetSmsMessages(call: MethodCall, result: MethodChannel.Result) {
        if (!hasSmsPermission()) {
            pendingResult = result
            pendingCall = call
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.READ_SMS),
                readSmsRequestCode
            )
            return
        }

        result.success(querySmsMessages(call))
    }

    private fun registerSmsReceiver() {
        if (smsReceiver != null || !hasSmsPermission()) {
            return
        }

        smsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
                    return
                }

                val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                if (messages.isNullOrEmpty()) {
                    return
                }

                val address = messages.firstOrNull()?.originatingAddress
                val timestamp = messages.firstOrNull()?.timestampMillis
                val body = messages.joinToString(separator = "") { it.messageBody ?: "" }
                if (body.isBlank()) {
                    return
                }

                val payload = mapOf(
                    "address" to address,
                    "body" to body,
                    "date" to timestamp
                )
                smsEventSink?.success(payload)
            }
        }

        val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(smsReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(smsReceiver, filter)
        }
    }

    private fun unregisterSmsReceiver() {
        val receiver = smsReceiver ?: return
        unregisterReceiver(receiver)
        smsReceiver = null
    }

    private fun querySmsMessages(call: MethodCall): List<Map<String, Any?>> {
        val sinceEpochMs = call.argument<Number>("sinceEpochMs")?.toLong() ?: 0L
        val limit = call.argument<Number>("limit")?.toInt() ?: 200
        val messages = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE
        )
        val selection = if (sinceEpochMs > 0) "${Telephony.Sms.DATE} >= ?" else null
        val selectionArgs = if (sinceEpochMs > 0) arrayOf(sinceEpochMs.toString()) else null

        contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            "${Telephony.Sms.DATE} DESC"
        )?.use { cursor ->
            val addressIndex = cursor.getColumnIndex(Telephony.Sms.ADDRESS)
            val bodyIndex = cursor.getColumnIndex(Telephony.Sms.BODY)
            val dateIndex = cursor.getColumnIndex(Telephony.Sms.DATE)

            while (cursor.moveToNext() && messages.size < limit) {
                messages.add(
                    mapOf(
                        "address" to if (addressIndex >= 0) cursor.getString(addressIndex) else null,
                        "body" to if (bodyIndex >= 0) cursor.getString(bodyIndex) else null,
                        "date" to if (dateIndex >= 0) cursor.getLong(dateIndex) else null
                    )
                )
            }
        }

        return messages
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != readSmsRequestCode) {
            return
        }

        val result = pendingResult
        val call = pendingCall
        pendingResult = null
        pendingCall = null

        if (result == null || call == null) {
            return
        }

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            result.error("permission_denied", "SMS permission denied", null)
            return
        }

        result.success(querySmsMessages(call))
    }

    override fun onDestroy() {
        unregisterSmsReceiver()
        super.onDestroy()
    }
}
