package com.audiophile.dsd_player

import android.content.Context
import io.flutter.plugin.common.MethodChannel
import jcifs.CIFSContext
import jcifs.context.SingletonContext
import jcifs.smb.NtlmPasswordAuthenticator
import jcifs.smb.SmbFile
import jcifs.smb.SmbFileInputStream
import java.io.File
import java.io.FileOutputStream

/**
 * SMB 网盘插件：通过 jcifs-ng 实现连接、列举目录、下载到本地缓存。
 * 由 Flutter 侧 SmbChannelClient 通过 MethodChannel 调用。
 */
class SmbPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    private var ctx: CIFSContext? = null
    private var baseUrl: String = ""

    override fun onMethodCall(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "connect" -> {
                    val conn = call.argument<Map<String, Any>>("connection")
                    result.success(connect(conn))
                }
                "list" -> {
                    val conn = call.argument<Map<String, Any>>("connection")
                    val path = call.argument<String>("path") ?: "/"
                    result.success(list(conn, path))
                }
                "download" -> {
                    val conn = call.argument<Map<String, Any>>("connection")
                    val path = call.argument<String>("path") ?: ""
                    result.success(download(conn, path))
                }
                "disconnect" -> {
                    ctx = null
                    baseUrl = ""
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("SMB_ERROR", e.message, null)
        }
    }

    private fun connect(conn: Map<String, Any>?): Boolean {
        if (conn == null) return false
        val host = conn["host"] as? String ?: return false
        val port = (conn["port"] as? Number)?.toInt() ?: 445
        val share = conn["share"] as? String ?: return false
        val user = conn["username"] as? String ?: ""
        val pass = conn["password"] as? String ?: ""
        val domain = conn["domain"] as? String ?: ""

        val auth = NtlmPasswordAuthenticator(domain, user, pass)
        val base = SingletonContext.getInstance().withCredentials(auth)
        baseUrl = "smb://$host:$port/$share/"
        // 校验：尝试列举根目录
        val root = SmbFile(baseUrl, base)
        root.listFiles()
        ctx = base
        return true
    }

    private fun contextWith(conn: Map<String, Any>?): CIFSContext {
        if (ctx != null && baseUrl.isNotEmpty()) return ctx!!
        connect(conn)
        return ctx!!
    }

    private fun list(conn: Map<String, Any>?, path: String): List<Map<String, Any>> {
        val c = contextWith(conn)
        val url = baseUrl + path.removePrefix("/").let { if (it.isEmpty()) "" else "$it/" }
        val dir = SmbFile(url, c)
        return dir.listFiles().map { f ->
            mapOf(
                "name" to (f.name?.removeSuffix("/") ?: ""),
                "path" to ("/${path.removePrefix("/")}/${f.name}".replace("//", "/")),
                "isDirectory" to f.isDirectory,
                "sizeBytes" to f.length(),
                "lastModified" to f.lastModified()
            )
        }
    }

    private fun download(conn: Map<String, Any>?, path: String): String {
        val c = contextWith(conn)
        val url = baseUrl + path.removePrefix("/")
        val remote = SmbFile(url, c)
        val outFile = File(context.cacheDir, "smb_${path.hashCode()}_${remote.name}")
        SmbFileInputStream(remote).use { input ->
            FileOutputStream(outFile).use { output ->
                val buf = ByteArray(8192)
                var n: Int
                while (input.read(buf).also { n = it } > 0) {
                    output.write(buf, 0, n)
                }
            }
        }
        return outFile.absolutePath
    }
}
