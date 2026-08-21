package com.example.piliplus

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

/**
 * 缓存导出的落盘通道。
 *
 * Android 10 (API 29) 起分区存储禁止直接用 `File` 写入公共 Download 目录，
 * 因此导出统一走两条路径：
 *  - 默认：MediaStore `Downloads` 插入，无需任何权限，文件真实落在 Download/ 下；
 *  - 覆盖：用户通过 SAF 选目录后得到的持久化 tree uri，在其中创建子文档。
 *
 * 两者都返回 `content://` uri，交由 ffmpeg-kit 的 `saf:` 协议直接写入，
 * 避免多 GB 文件的临时拷贝。
 */
class ExportChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "com.pili.super/export"

        private const val ERR_ARG = "invalid_argument"
        private const val ERR_UNSUPPORTED = "unsupported"
        private const val ERR_IO = "io_error"
    }

    /** 通知栏「取消」回传 Dart 用。由 [MainActivity] 注入。 */
    var channel: MethodChannel? = null
        set(value) {
            field = value
            ExportForegroundService.onCancelRequested = value?.let { ch ->
                { ch.invokeMethod("onNotificationCancel", null) }
            }
        }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "publicDownloadsDir" -> result.success(publicDownloadsDir())
                "createInDownloads" -> createInDownloads(call, result)
                "createInTree" -> createInTree(call, result)
                "persistTree" -> persistTree(call, result)
                "isTreeGranted" -> result.success(isTreeGranted(call.argStr("treeUri")))
                "treeDisplayPath" -> result.success(treeDisplayPath(call.argStr("treeUri")))
                "finalizePending" -> finalizePending(call, result)
                "deleteDocument" -> deleteDocument(call, result)
                "writeBytes" -> writeBytes(call, result)
                "copyFromFile" -> copyFromFile(call, result)
                "documentDisplayPath" -> result.success(documentDisplayPath(call.argStr("uri")))
                "startForegroundProgress" -> {
                    ExportForegroundService.start(
                        context,
                        call.argStr("title"),
                        call.argStr("message"),
                    )
                    result.success(null)
                }

                "updateForegroundProgress" -> {
                    ExportForegroundService.update(
                        context,
                        call.argStr("title"),
                        call.argStr("message"),
                        call.argument<Int>("progress") ?: -1,
                    )
                    result.success(null)
                }

                "stopForegroundProgress" -> {
                    ExportForegroundService.stop(context)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        } catch (e: IllegalArgumentException) {
            result.error(ERR_ARG, e.message, null)
        } catch (e: Exception) {
            result.error(ERR_IO, e.message, e.stackTraceToString())
        }
    }

    private fun MethodCall.argStr(name: String): String =
        argument<String>(name) ?: throw IllegalArgumentException("missing argument: $name")

    /** API 24~28 直写公共 Download 目录时使用。 */
    private fun publicDownloadsDir(): String? =
        @Suppress("DEPRECATION")
        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)?.absolutePath

    /**
     * 在 MediaStore Downloads 下创建条目。
     *
     * 以 `IS_PENDING=1` 插入，写完后必须调用 [finalizePending]，否则条目对其他应用
     * 不可见，且系统会在若干天后自行回收。
     */
    private fun createInDownloads(call: MethodCall, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error(ERR_UNSUPPORTED, "MediaStore Downloads requires API 29+", null)
            return
        }
        val name = call.argStr("name")
        val mime = call.argStr("mime")
        val relativePath = call.argument<String>("relativePath")
        result.success(insertDownload(name, mime, relativePath))
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun insertDownload(name: String, mime: String, relativePath: String?): String {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            if (!relativePath.isNullOrEmpty()) {
                put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            }
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = context.contentResolver.insert(collection, values)
            ?: throw IllegalStateException("MediaStore insert returned null")
        return uri.toString()
    }

    /** 在已授权的 SAF tree 下创建子文档，必要时逐级创建子目录。 */
    private fun createInTree(call: MethodCall, result: MethodChannel.Result) {
        val treeUri = Uri.parse(call.argStr("treeUri"))
        val name = call.argStr("name")
        val mime = call.argStr("mime")
        val subDir = call.argument<String>("subDir")

        var parentDocId = DocumentsContract.getTreeDocumentId(treeUri)
        var parentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, parentDocId)
        if (!subDir.isNullOrEmpty()) {
            for (segment in subDir.split('/')) {
                if (segment.isEmpty()) continue
                parentUri = findOrCreateDir(treeUri, parentUri, segment)
                parentDocId = DocumentsContract.getDocumentId(parentUri)
            }
        }

        val created = DocumentsContract.createDocument(
            context.contentResolver,
            parentUri,
            mime,
            name,
        ) ?: throw IllegalStateException("createDocument returned null")
        result.success(created.toString())
    }

    private fun findOrCreateDir(treeUri: Uri, parentUri: Uri, name: String): Uri {
        findChildByName(treeUri, parentUri, name)?.let { return it }
        return DocumentsContract.createDocument(
            context.contentResolver,
            parentUri,
            DocumentsContract.Document.MIME_TYPE_DIR,
            name,
        ) ?: throw IllegalStateException("cannot create directory: $name")
    }

    private fun findChildByName(treeUri: Uri, parentUri: Uri, name: String): Uri? {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            treeUri,
            DocumentsContract.getDocumentId(parentUri),
        )
        context.contentResolver.query(
            childrenUri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            ),
            null,
            null,
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                if (cursor.getString(1) != name) continue
                if (cursor.getString(2) != DocumentsContract.Document.MIME_TYPE_DIR) continue
                return DocumentsContract.buildDocumentUriUsingTree(treeUri, cursor.getString(0))
            }
        }
        return null
    }

    /**
     * 补一次持久化授权。
     *
     * file_picker 默认已请求持久化，这里作为兜底；重复调用无副作用。
     */
    private fun persistTree(call: MethodCall, result: MethodChannel.Result) {
        val treeUri = Uri.parse(call.argStr("treeUri"))
        val flags = android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION or
            android.content.Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        try {
            context.contentResolver.takePersistableUriPermission(treeUri, flags)
            result.success(true)
        } catch (_: SecurityException) {
            result.success(false)
        }
    }

    private fun isTreeGranted(treeUriString: String): Boolean {
        val treeUri = Uri.parse(treeUriString)
        return context.contentResolver.persistedUriPermissions.any {
            it.uri == treeUri && it.isWritePermission
        }
    }

    /** 把 tree uri 的 document id 转成便于展示的相对路径，如 `primary:Download/x`。 */
    private fun treeDisplayPath(treeUriString: String): String {
        val docId = try {
            DocumentsContract.getTreeDocumentId(Uri.parse(treeUriString))
        } catch (_: Exception) {
            return treeUriString
        }
        return prettifyDocId(docId)
    }

    private fun documentDisplayPath(uriString: String): String {
        val uri = Uri.parse(uriString)
        if (uri.authority == MediaStore.AUTHORITY) {
            return queryMediaStoreName(uri) ?: uriString
        }
        val docId = try {
            DocumentsContract.getDocumentId(uri)
        } catch (_: Exception) {
            return uriString
        }
        return prettifyDocId(docId)
    }

    private fun queryMediaStoreName(uri: Uri): String? {
        val columns = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            arrayOf(MediaStore.MediaColumns.RELATIVE_PATH, MediaStore.MediaColumns.DISPLAY_NAME)
        } else {
            arrayOf(MediaStore.MediaColumns.DISPLAY_NAME)
        }
        context.contentResolver.query(uri, columns, null, null, null)?.use { cursor ->
            if (!cursor.moveToFirst()) return null
            return if (columns.size == 2) {
                (cursor.getString(0) ?: "") + (cursor.getString(1) ?: "")
            } else {
                cursor.getString(0)
            }
        }
        return null
    }

    private fun prettifyDocId(docId: String): String {
        val parts = docId.split(':', limit = 2)
        if (parts.size != 2) return docId
        val volume = if (parts[0] == "primary") "内部存储" else parts[0]
        return if (parts[1].isEmpty()) volume else "$volume/${parts[1]}"
    }

    /** 清除 `IS_PENDING`，让 MediaStore 条目对外可见。SAF 文档无需此步。 */
    private fun finalizePending(call: MethodCall, result: MethodChannel.Result) {
        val uri = Uri.parse(call.argStr("uri"))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            uri.authority == MediaStore.AUTHORITY
        ) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            context.contentResolver.update(uri, values, null, null)
        }
        result.success(null)
    }

    private fun deleteDocument(call: MethodCall, result: MethodChannel.Result) {
        val uri = Uri.parse(call.argStr("uri"))
        val deleted = try {
            if (uri.authority == MediaStore.AUTHORITY) {
                context.contentResolver.delete(uri, null, null) > 0
            } else {
                DocumentsContract.deleteDocument(context.contentResolver, uri)
            }
        } catch (_: Exception) {
            false
        }
        result.success(deleted)
    }

    /** 小文件（ASS 等）直接写入。 */
    private fun writeBytes(call: MethodCall, result: MethodChannel.Result) {
        val uri = Uri.parse(call.argStr("uri"))
        val bytes = call.argument<ByteArray>("bytes")
            ?: throw IllegalArgumentException("missing argument: bytes")
        context.contentResolver.openOutputStream(uri, "wt").use { out ->
            if (out == null) throw IllegalStateException("cannot open output stream")
            out.write(bytes)
            out.flush()
        }
        result.success(null)
    }

    /**
     * 从本地文件流式拷贝到目标 uri。
     *
     * ffmpeg 无法写入目标时的兜底路径，也用于无需转封装的整文件搬运。
     */
    private fun copyFromFile(call: MethodCall, result: MethodChannel.Result) {
        val uri = Uri.parse(call.argStr("uri"))
        val source = File(call.argStr("path"))
        if (!source.isFile) throw IllegalArgumentException("source not found: ${source.path}")
        var copied = 0L
        context.contentResolver.openOutputStream(uri, "wt").use { out ->
            if (out == null) throw IllegalStateException("cannot open output stream")
            FileInputStream(source).use { input ->
                copied = input.copyTo(out, DEFAULT_BUFFER_SIZE * 16)
            }
            out.flush()
        }
        result.success(copied)
    }
}
