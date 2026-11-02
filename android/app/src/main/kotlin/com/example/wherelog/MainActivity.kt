package com.example.wherelog

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ClipboardManager
import android.content.Context
import android.content.ClipDescription

class MainActivity : FlutterActivity() {
    private val channelName = "com.wherelog/clipboard_image"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasImage" -> {
                    result.success(hasClipboardImage())
                }
                "getImage" -> {
                    try {
                        val bytes = getClipboardImageBytes()
                        result.success(bytes)
                    } catch (e: Exception) {
                        result.error("CLIPBOARD_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasClipboardImage(): Boolean {
        return try {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            if (!cm.hasPrimaryClip()) return false
            val clip = cm.primaryClip ?: return false
            val desc = clip.description
            // Check mime types or URI
            if (desc.hasMimeType(ClipDescription.MIMETYPE_TEXT_URILIST) || desc.hasMimeType("image/*") || desc.hasMimeType("image/png") || desc.hasMimeType("image/jpeg") || desc.hasMimeType("image/jpg")) {
                return true
            }
            // Fallback: check items for uri
            for (i in 0 until clip.itemCount) {
                val item = clip.getItemAt(i)
                if (item.uri != null) return true
            }
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun getClipboardImageBytes(): ByteArray? {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        if (!cm.hasPrimaryClip()) return null
        val clip = cm.primaryClip ?: return null
        for (i in 0 until clip.itemCount) {
            val item = clip.getItemAt(i)
            val uri = item.uri
            if (uri != null) {
                try {
                    contentResolver.openInputStream(uri)?.use { input ->
                        return input.readBytes()
                    }
                } catch (_: Exception) {
                    // try next
                }
            }
            // Some apps put image as file path in text
            // Try coerce to text that is content uri?
        }
        return null
    }
}
