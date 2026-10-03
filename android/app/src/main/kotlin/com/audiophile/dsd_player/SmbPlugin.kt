package com.audiophile.dsd_player

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import jcifs.CIFSContext
import jcifs.config.PropertyConfiguration
import jcifs.context.BaseContext
import jcifs.smb.NtlmPasswordAuthenticator
import jcifs.smb.SmbAuthException
import jcifs.smb.SmbException as JcifsSmbException
import jcifs.smb.SmbFile
import jcifs.smb.SmbFileInputStream
import java.io.File
import java.io.FileOutputStream
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.util.Properties

/**
 * SMB 网盘插件：通过 jcifs-ng 实现连接、列举目录、下载到本地缓存。
 * 由 Flutter 侧 SmbChannelClient 通过 MethodChannel 调用。
 *
 * 说明：jcifs-ng 2.1.10 的默认协议范围只有 SMB1..SMB2.1（maxVersion 默认 SMB210），
 * 且默认解析顺序含 WINS/LMHOSTS（Android 上容易长时间卡住）。
 * 这里显式构造 PropertyConfiguration，打开到 SMB3.1.1 并缩短超时。
 */
class SmbPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    private var ctx: CIFSContext? = null
    private var baseUrl: String = ""

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
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
            result.error("SMB_ERROR", describe(e), null)
        }
    }

    /** 构造 jcifs 上下文：限定 SMB2~SMB3.0.2，只用 DNS/广播解析，缩短超时 */
    private fun newContext(): CIFSContext {
        val p = Properties()
        // 协议版本：下限 SMB202、上限 SMB302，刻意避开两端，理由如下——
        //  · SMB1 用 OEM(Cp850) 编码，中文共享名（如"家庭共享")在 SMB1 下会乱码导致找不到共享；
        //  · SMB3.1.1 要求客户端带 negotiate contexts，一旦把 3.1.1 放进方言列表，
        //    部分 NAS（实测联想 MemoSpace）直接返回 0xC000000D 而不是降级到 3.0.2，整条连接失败。
        // SMB2/SMB3 全程 UTF-16，中文共享名安全。
        p.setProperty("jcifs.smb.client.minVersion", "SMB202")
        p.setProperty("jcifs.smb.client.maxVersion", "SMB302")
        // 名称解析：WINS / LMHOSTS 在 Android 上基本不可用，只留 DNS + 广播
        p.setProperty("jcifs.resolveOrder", "DNS,BCAST")
        // 超时（毫秒）：默认 30s 太长，手机上等不起
        p.setProperty("jcifs.smb.client.connTimeout", "8000")
        p.setProperty("jcifs.smb.client.soTimeout", "15000")
        p.setProperty("jcifs.smb.client.responseTimeout", "8000")
        // 匿名 / guest 共享兜底
        p.setProperty("jcifs.smb.client.allowGuestFallback", "true")
        p.setProperty("jcifs.smb.client.guestUsername", "guest")
        p.setProperty("jcifs.smb.client.guestPassword", "")
        return BaseContext(PropertyConfiguration(p))
    }

    private fun connect(conn: Map<String, Any>?): Boolean {
        if (conn == null) return false
        val host = (conn["host"] as? String)?.trim()?.trimStart('\\', '/') ?: return false
        if (host.isEmpty()) return false
        // 端口留空 / 0 / 负数 -> 使用 SMB 默认 445（jcifs 会省略 :port）
        val port = (conn["port"] as? Number)?.toInt() ?: 0
        // 共享名允许带子目录，例如 "家庭共享/Music"，直接定位到音乐目录
        val shareRaw = (conn["share"] as? String)?.trim()?.trim('/', '\\') ?: ""
        if (shareRaw.isEmpty()) return false
        val parts = shareRaw.split('/').filter { it.isNotBlank() }
        val share = parts.first()
        val subPath = parts.drop(1).joinToString("/")
        val user = conn["username"] as? String ?: ""
        val pass = conn["password"] as? String ?: ""
        val domain = conn["domain"] as? String ?: ""

        val auth = NtlmPasswordAuthenticator(domain, user, pass)
        val base = newContext().withCredentials(auth)
        val hostPart = if (port > 0) "$host:$port" else host
        baseUrl = "smb://$hostPart/$share/" +
            (if (subPath.isEmpty()) "" else "$subPath/")
        // 校验：尝试列举共享根目录
        val root = SmbFile(baseUrl, base)
        root.listFiles()
        ctx = base
        return true
    }

    private fun contextWith(conn: Map<String, Any>?): CIFSContext {
        ctx?.let { if (baseUrl.isNotEmpty()) return it }
        connect(conn)
        return ctx ?: throw IllegalStateException("SMB 尚未连接成功")
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
                val buf = ByteArray(65536)
                var n: Int
                while (input.read(buf).also { n = it } > 0) {
                    output.write(buf, 0, n)
                }
            }
        }
        return outFile.absolutePath
    }

    /** 把底层异常翻译成人能看懂的中文提示，便于排查 */
    private fun describe(e: Throwable): String {
        val raw = e.message?.takeIf { it.isNotBlank() } ?: "（无详细信息）"
        return when (e) {
            is UnknownHostException ->
                "找不到主机：$raw。建议直接填 NAS 的 IP，不要填 \\\\NAS 这种 NetBIOS 名。"
            is SocketTimeoutException ->
                "连接超时：$raw。请确认手机与 NAS 在同一局域网、路由器没开「AP 隔离」、手机没走 VPN。"
            is ConnectException ->
                "连接被拒：$raw。主机可达但端口没开，确认 SMB 服务已启用、端口（默认 445）正确。"
            is SmbAuthException ->
                "登录被拒：$raw。检查用户名 / 密码 / 域；匿名共享请把用户名留空或填 guest。"
            is JcifsSmbException ->
                "SMB 错误：$raw。最常见是共享名填错：应填 NAS 上真实的共享名，可用「共享名/子目录」（如 家庭共享/Music）。"
            else -> "${e.javaClass.simpleName}: $raw"
        }
    }
}
