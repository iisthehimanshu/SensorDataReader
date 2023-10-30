package com.example.sensor_reader_prototype_websocket

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.content.pm.PackageManager
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.os.Handler
import androidx.core.app.ActivityCompat
import android.app.Service;

class BluetoothHandler : FlutterPlugin, MethodCallHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var applicationContext: Context

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPluginBinding) {
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "bluetooth_channel")
        methodChannel.setMethodCallHandler(this)
        applicationContext = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "getNearbyBluetoothDevices" -> {
                val devices = getNearbyBluetoothDevices()
                result.success(devices)
            }
            else -> result.notImplemented()
        }
    }

    private fun getNearbyBluetoothDevices(): List<String> {
        val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        val devices = mutableListOf<String>()

        if (bluetoothAdapter == null) {
            return devices
        }

        if (!applicationContext.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH)) {
            return devices
        }

        if (!bluetoothAdapter.isEnabled) {
            // You might prompt the user to enable Bluetooth here
            return devices
        }

        // Check for BLUETOOTH permission before accessing bonded devices
        if (applicationContext.checkSelfPermission(android.Manifest.permission.BLUETOOTH) != PackageManager.PERMISSION_GRANTED) {
            // You might request permission here
            return devices
        }

        val pairedDevices = bluetoothAdapter.bondedDevices
        for (device in pairedDevices) {
            devices.add(device.name)
        }

        return devices
    }


    override fun onDetachedFromEngine(@NonNull binding: FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
    }
}

