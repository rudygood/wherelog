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
                "describeClip" -> {
                    try {
                        result.success(describeClipboard())
                    } catch (e: Exception) {
                        result.success("describe failed: " + e.message)
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
            // The button's promise is "paste will succeed", so
            // judge by the ground truth: some clip item carries
            // a link whose bytes actually begin as an image.
            // Declared MIME types and the mere presence of a
            // link proved unreliable — a copied Maps place LINK
            // (plain text) lit the button although no image
            // existed to paste.
            for (i in 0 until clip.itemCount) {
                val uri = clip.getItemAt(i).uri ?: continue
                try {
                    contentResolver.openInputStream(uri)?.use { input ->
                        val head = ByteArray(12)
                        var read = 0
                        while (read < head.size) {
                            val n = input.read(head, read, head.size - read)
                            if (n < 0) break
                            read += n
                        }
                        if (read >= 4 && isImageHeader(head)) return true
                    }
                } catch (_: Exception) {
                    // try the next item
                }
            }
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun isImageHeader(b: ByteArray): Boolean {
        fun u(i: Int) = b[i].toInt() and 0xFF
        if (b.size >= 3 && u(0) == 0xFF && u(1) == 0xD8 && u(2) == 0xFF) return true // JPEG
        if (b.size >= 4 && u(0) == 0x89 && u(1) == 0x50 && u(2) == 0x4E && u(3) == 0x47) return true // PNG
        if (b.size >= 4 && u(0) == 0x47 && u(1) == 0x49 && u(2) == 0x46 && u(3) == 0x38) return true // GIF8
        if (b.size >= 2 && u(0) == 0x42 && u(1) == 0x4D) return true // BMP "BM"
        if (b.size >= 12 && u(0) == 0x52 && u(1) == 0x49 && u(2) == 0x46 && u(3) == 0x46 &&
            u(8) == 0x57 && u(9) == 0x45 && u(10) == 0x42 && u(11) == 0x50) return true // RIFF....WEBP
        return false
    }

    // Diagnostic: what the clipboard claims to hold — label,
    // declared MIME types, and the shape of each item (link,
    // text, HTML, intent) — without reading any image content.
    // Used to learn how another app packaged a copied image
    // when hasClipboardImage() does not recognise the wrapper.
    private fun describeClipboard(): String {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        if (!cm.hasPrimaryClip()) return "Clipboard is empty (no primary clip)."
        val clip = cm.primaryClip ?: return "Clipboard is empty (primary clip null)."
        val sb = StringBuilder()
        val desc = clip.description
        sb.append("label: ").append(desc.label?.toString() ?: "(none)").append('\n')
        sb.append("mime types: ")
        for (i in 0 until desc.mimeTypeCount) {
            if (i > 0) sb.append(", ")
            sb.append(desc.getMimeType(i))
        }
        sb.append("\nitems: ").append(clip.itemCount)
        for (i in 0 until clip.itemCount) {
            val item = clip.getItemAt(i)
            sb.append("\n#").append(i).append(" ")
            val uri = item.uri
            if (uri != null) {
                sb.append("link(").append(uri.scheme).append("://").append(uri.authority).append(") ")
                // Probe the link the way hasImage and getImage
                // do: can it be opened, what comes out, and do
                // the first bytes read as an image?
                try {
                    val stream = contentResolver.openInputStream(uri)
                    if (stream == null) {
                        sb.append("[stream: none] ")
                    } else {
                        stream.use { input ->
                            val buf = ByteArray(8192)
                            val head = ByteArray(12)
                            var headLen = 0
                            var total = 0
                            var capped = false
                            while (true) {
                                val n = input.read(buf)
                                if (n < 0) break
                                if (headLen < head.size) {
                                    val take = minOf(n, head.size - headLen)
                                    System.arraycopy(buf, 0, head, headLen, take)
                                    headLen += take
                                }
                                total += n
                                if (total > 2_000_000) { capped = true; break }
                            }
                            sb.append("[stream ok, ").append(total).append(if (capped) "+" else "").append(" bytes, head:")
                            for (j in 0 until headLen) sb.append(" %02X".format(head[j]))
                            sb.append(", image: ").append(if (headLen >= 4 && isImageHeader(head)) "YES" else "no").append("] ")
                        }
                    }
                } catch (e: Exception) {
                    sb.append("[stream failed: ").append(e.javaClass.simpleName).append(": ").append(e.message).append("] ")
                }
            }
            val text = item.text
            if (text != null) {
                val t = text.toString()
                sb.append("text(\"").append(if (t.length > 60) t.substring(0, 60) + "..." else t).append("\") ")
            }
            if (item.htmlText != null) sb.append("html ")
            if (item.intent != null) sb.append("intent ")
            if (uri == null && text == null && item.htmlText == null && item.intent == null) sb.append("(empty item)")
        }
        // The two verdicts the button and the paste stand on,
        // computed live on this same clip.
        sb.append("\nhasImage verdict: ").append(hasClipboardImage())
        val imgBytes = try { getClipboardImageBytes() } catch (_: Exception) { null }
        sb.append("\ngetImage result: ").append(imgBytes?.let { it.size.toString() + " bytes" } ?: "null")
        return sb.toString()
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
