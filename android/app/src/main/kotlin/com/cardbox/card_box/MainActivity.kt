package com.cardbox.card_box

import android.content.ClipData
import android.content.Intent
import android.provider.Settings
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val fileShareChannel = "card_box/file_share"
    private val deviceSettingsChannel = "card_box/device_settings"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, fileShareChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareFile" -> {
                        val path = call.argument<String>("path")
                        val subject = call.argument<String>("subject").orEmpty()
                        val text = call.argument<String>("text")
                        if (path.isNullOrBlank()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        result.success(shareFile(path = path, subject = subject, text = text))
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceSettingsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNfcSettings" -> result.success(openNfcSettings())
                    "openAppSettings" -> result.success(openAppSettings())
                    else -> result.notImplemented()
                }
            }
    }

    private fun shareFile(path: String, subject: String, text: String?): Boolean {
        val source = File(path)
        if (!source.exists()) {
            return false
        }

        val sharedDirectory = File(cacheDir, "shared_exports").apply { mkdirs() }
        val sharedFile = File(sharedDirectory, source.name)
        source.copyTo(sharedFile, overwrite = true)

        val authority = "${applicationContext.packageName}.card_box.share_provider"
        val uri = FileProvider.getUriForFile(this, authority, sharedFile)
        val mimeType = when (sharedFile.extension.lowercase()) {
            "json" -> "application/json"
            "vcf" -> "text/vcard"
            else -> contentResolver.getType(uri) ?: "*/*"
        }

        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newRawUri(sharedFile.name, uri)
            if (subject.isNotBlank()) {
                putExtra(Intent.EXTRA_SUBJECT, subject)
            }
            if (!text.isNullOrBlank()) {
                putExtra(Intent.EXTRA_TEXT, text)
            }
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        startActivity(Intent.createChooser(shareIntent, subject.ifBlank { "Share file" }))
        return true
    }

    private fun openNfcSettings(): Boolean {
        val intents = listOf(
            Intent(Settings.Panel.ACTION_NFC).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            Intent(Settings.ACTION_NFC_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            Intent(Settings.ACTION_WIRELESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        for (candidate in intents) {
            if (candidate.resolveActivity(packageManager) != null) {
                startActivity(candidate)
                return true
            }
        }
        return false
    }

    private fun openAppSettings(): Boolean {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", packageName, null),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return if (intent.resolveActivity(packageManager) != null) {
            startActivity(intent)
            true
        } else {
            false
        }
    }
}
