package com.example.line_theme

import android.content.pm.PackageManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku
import rikka.shizuku.ShizukuRemoteProcess
import java.io.BufferedReader
import java.io.InputStreamReader
import java.lang.reflect.Method

class MainActivity : FlutterActivity() {
	private companion object {
		const val CHANNEL_NAME = "line_theme/theme_access"
		const val REQUEST_CODE_SHIZUKU_PERMISSION = 4108
		const val THEME_ROOT = "/storage/emulated/0/Android/data/jp.naver.line.android/files/theme"
		val NEW_PROCESS_METHOD: Method by lazy {
			Shizuku::class.java.getDeclaredMethod(
				"newProcess",
				Array<String>::class.java,
				Array<String>::class.java,
				String::class.java,
			).apply {
				isAccessible = true
			}
		}
	}

	private var pendingPermissionResult: MethodChannel.Result? = null
	@Volatile
	private var binderAvailable = false
	private val binderReceivedListener = Shizuku.OnBinderReceivedListener {
		binderAvailable = true
	}
	private val binderDeadListener = Shizuku.OnBinderDeadListener {
		binderAvailable = false
	}
	private val permissionListener = Shizuku.OnRequestPermissionResultListener { requestCode, grantResult ->
		if (requestCode != REQUEST_CODE_SHIZUKU_PERMISSION) {
			return@OnRequestPermissionResultListener
		}

		val result = pendingPermissionResult ?: return@OnRequestPermissionResultListener
		pendingPermissionResult = null
		result.success(grantResult == PackageManager.PERMISSION_GRANTED)
	}

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		binderAvailable = Shizuku.pingBinder()
		Shizuku.addBinderReceivedListenerSticky(binderReceivedListener)
		Shizuku.addBinderDeadListener(binderDeadListener)
		Shizuku.addRequestPermissionResultListener(permissionListener)
	}

	override fun onDestroy() {
		Shizuku.removeBinderReceivedListener(binderReceivedListener)
		Shizuku.removeBinderDeadListener(binderDeadListener)
		Shizuku.removeRequestPermissionResultListener(permissionListener)
		super.onDestroy()
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"getShizukuStatus" -> result.success(getShizukuStatusInternal())
					"requestShizukuPermission" -> requestShizukuPermission(result)
					"listInstalledThemes" -> {
						runCatching {
							listInstalledThemesInternal()
						}.onSuccess(result::success).onFailure {
							result.error("LIST_THEMES_ERROR", it.message, null)
						}
					}
					"readThemeArchive" -> {
						val archiveUri = call.argument<String>("archiveUri")
						if (archiveUri.isNullOrBlank()) {
							result.error("INVALID_ARGUMENT", "archiveUri is required", null)
							return@setMethodCallHandler
						}

						runCatching {
							readDocumentBytes(archiveUri)
						}.onSuccess(result::success).onFailure {
							result.error("READ_ARCHIVE_ERROR", it.message, null)
						}
					}
					"writeThemeArchive" -> {
						val archiveUri = call.argument<String>("archiveUri")
						val bytes = call.argument<ByteArray>("bytes")
						if (archiveUri.isNullOrBlank() || bytes == null) {
							result.error("INVALID_ARGUMENT", "archiveUri and bytes are required", null)
							return@setMethodCallHandler
						}

						runCatching {
							writeDocumentBytes(archiveUri, bytes)
						}.onSuccess {
							result.success(null)
						}.onFailure {
							result.error("WRITE_ARCHIVE_ERROR", it.message, null)
						}
					}
					else -> result.notImplemented()
				}
			}
	}

	private fun requestShizukuPermission(result: MethodChannel.Result) {
		refreshBinderState()
		if (!binderAvailable) {
			result.success(false)
			return
		}

		if (isPermissionGranted()) {
			result.success(true)
			return
		}

		if (pendingPermissionResult != null) {
			result.error("SHIZUKU_BUSY", "Another Shizuku permission request is already in progress.", null)
			return
		}

		pendingPermissionResult = result
		Shizuku.requestPermission(REQUEST_CODE_SHIZUKU_PERMISSION)
	}

	private fun isShizukuReadyInternal(): Boolean {
		refreshBinderState()
		return binderAvailable && isPermissionGranted()
	}

	private fun getShizukuStatusInternal(): Map<String, Any> {
		refreshBinderState()
		val permissionGranted = isPermissionGranted()
		val shouldShowRationale = if (binderAvailable && !permissionGranted) {
			runCatching { Shizuku.shouldShowRequestPermissionRationale() }.getOrDefault(false)
		} else {
			false
		}
		val serviceVersion = if (binderAvailable) {
			runCatching { Shizuku.getVersion() }.getOrDefault(-1)
		} else {
			-1
		}
		val serverUid = if (binderAvailable) {
			runCatching { Shizuku.getUid() }.getOrDefault(-1)
		} else {
			-1
		}

		return mapOf(
			"binderAvailable" to binderAvailable,
			"permissionGranted" to permissionGranted,
			"shouldShowRationale" to shouldShowRationale,
			"serviceVersion" to serviceVersion,
			"serverUid" to serverUid,
		)
	}

	private fun listInstalledThemesInternal(): List<Map<String, String>> {
		ensureShizukuReady()

		val command = "for dir in $THEME_ROOT/*; do [ -d \"\$dir\" ] || continue; dir_name=\$(basename \"\$dir\"); for file in \"\$dir\"/themefile.*; do [ -f \"\$file\" ] || continue; base_name=\$(basename \"\$file\"); slot=\${base_name#themefile.}; echo \"\$slot|\$dir_name|\$file\"; done; done"
		val lines = executeShizukuCommand(command)

		return lines.mapNotNull { line ->
			val parts = line.split("|", limit = 3)
			if (parts.size != 3) {
				return@mapNotNull null
			}

			mapOf(
				"slot" to parts[0],
				"directoryName" to parts[1],
				"archiveUri" to parts[2],
			)
		}.sortedBy { it["slot"]?.toIntOrNull() ?: Int.MAX_VALUE }
	}

	private fun readDocumentBytes(path: String): ByteArray {
		ensureShizukuReady()
		val process = createRemoteProcess(arrayOf("/system/bin/cat", path))
		val output = process.inputStream.use { it.readBytes() }
		val error = process.errorStream.use { it.readBytes().toString(Charsets.UTF_8).trim() }
		val exitCode = process.waitFor()

		if (exitCode != 0) {
			throw IllegalStateException(if (error.isNotEmpty()) error else "Failed to read themefile: $path")
		}

		return output
	}

	private fun writeDocumentBytes(path: String, bytes: ByteArray) {
		ensureShizukuReady()
		val process = createRemoteProcess(arrayOf("/system/bin/sh", "-c", "cat > '$path'"))
		process.outputStream.use { output ->
			output.write(bytes)
			output.flush()
		}
		val error = process.errorStream.use { it.readBytes().toString(Charsets.UTF_8).trim() }
		val exitCode = process.waitFor()

		if (exitCode != 0) {
			throw IllegalStateException(if (error.isNotEmpty()) error else "Failed to write themefile: $path")
		}
	}

	private fun executeShizukuCommand(command: String): List<String> {
		ensureShizukuReady()
		val process = createRemoteProcess(arrayOf("/system/bin/sh", "-c", command))
		val output = BufferedReader(InputStreamReader(process.inputStream)).use { reader ->
			reader.readLines()
		}
		val error = process.errorStream.use { it.readBytes().toString(Charsets.UTF_8).trim() }
		val exitCode = process.waitFor()

		if (exitCode != 0) {
			throw IllegalStateException(if (error.isNotEmpty()) error else "Shizuku command failed.")
		}

		return output.filter { it.isNotBlank() }
	}

	private fun ensureShizukuReady() {
		if (!isShizukuReadyInternal()) {
			throw IllegalStateException("Shizuku is not running or permission has not been granted.")
		}
	}

	private fun refreshBinderState() {
		binderAvailable = runCatching { Shizuku.pingBinder() }.getOrDefault(false)
	}

	private fun isPermissionGranted(): Boolean {
		if (!binderAvailable) {
			return false
		}

		return runCatching {
			Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
		}.getOrDefault(false)
	}

	private fun createRemoteProcess(command: Array<String>): ShizukuRemoteProcess {
		@Suppress("UNCHECKED_CAST")
		return NEW_PROCESS_METHOD.invoke(null, command, null, null) as ShizukuRemoteProcess
	}
}
