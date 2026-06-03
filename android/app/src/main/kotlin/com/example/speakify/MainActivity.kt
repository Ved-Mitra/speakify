package com.example.speakify

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "speakify/bluetooth"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isDeviceConnected" -> {
                        val address = call.argument<String>("address")
                        if (address == null) {
                            result.error("INVALID_ARG", "MAC address is required", null)
                            return@setMethodCallHandler
                        }
                        val connected = isClassicBtConnected(address)
                        result.success(connected)
                    }
                    "getConnectedA2dpDevices" -> {
                        getConnectedA2dpDevices(result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Check if a classic Bluetooth device is currently connected.
     * Uses BluetoothDevice.isConnected() via reflection (hidden API but stable).
     */
    @SuppressLint("MissingPermission")
    private fun isClassicBtConnected(address: String): Boolean {
        return try {
            val adapter = BluetoothAdapter.getDefaultAdapter() ?: return false
            val device: BluetoothDevice = adapter.getRemoteDevice(address)
            // isConnected() is a @hide method but has been stable since Android 4.0.
            val isConnected = device.javaClass.getMethod("isConnected").invoke(device)
            isConnected as? Boolean ?: false
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Get MAC addresses of all devices currently connected via A2DP (audio output).
     * Uses BluetoothProfile proxy for the official A2DP profile.
     */
    @SuppressLint("MissingPermission")
    private fun getConnectedA2dpDevices(result: MethodChannel.Result) {
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = bluetoothManager?.adapter ?: BluetoothAdapter.getDefaultAdapter()

        if (adapter == null) {
            result.success(emptyList<Map<String, Any>>())
            return
        }

        adapter.getProfileProxy(this, object : BluetoothProfile.ServiceListener {
            override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                val connectedDevices = proxy.connectedDevices.map { device ->
                    mapOf(
                        "address" to device.address,
                        "name" to (device.name ?: "Unknown"),
                    )
                }
                result.success(connectedDevices)
                adapter.closeProfileProxy(profile, proxy)
            }

            override fun onServiceDisconnected(profile: Int) {
                // If proxy disconnects before we get results, return empty.
            }
        }, BluetoothProfile.A2DP)
    }
}
