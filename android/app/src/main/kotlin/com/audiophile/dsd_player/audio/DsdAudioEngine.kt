package com.audiophile.dsd_player.audio

import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.util.Log
import java.io.RandomAccessFile

/**
 * DSD 播放引擎（DoP over AudioTrack）。
 *
 * 说明：
 *  - 该实现把 DSD 经 DoP 封装为 24bit PCM，通过 Android AudioTrack 输出，
 *    在支持 DoP 的 USB DAC 上即可识别为 DSD 信号。
 *  - AudioTrack 走系统混音器，部分设备/ DAC 路径可能重采样，未必“比特完美”。
 *  - 若要真正独占 / 比特完美直出，请用 README 中提供的 AAudio（C++）引擎替换本类。
 */
class DsdAudioEngine {

    private var raf: RandomAccessFile? = null
    private var track: AudioTrack? = null
    private var thread: Thread? = null
    private var running = false
    private var paused = false
    private val lock = Object()

    // 解析出的文件信息
    private var dsdRate: Int = 2822400      // DSD64 默认
    private var channels: Int = 2
    private var dataOffset: Long = 0
    private var dataSize: Long = 0
    private var pcmRate: Int = 176400

    // 播放进度（已播放的 DSD 字节数，用于 seek/position）
    @Volatile private var playedBytes: Long = 0

    var onState: ((state: Int, positionMs: Long, dsdMode: String?, message: String?) -> Unit)? = null

    companion object {
        const val STATE_IDLE = 0
        const val STATE_BUFFERING = 1
        const val STATE_PLAYING = 2
        const val STATE_PAUSED = 3
        const val STATE_STOPPED = 4
        const val STATE_ERROR = 5
        private const val TAG = "DsdAudioEngine"
        private const val READ_BLOCK = 8192 // 每次读取的 DSD 字节数（偶数、2 的倍数）
    }

    fun isSupported(): Boolean = true

    fun load(path: String, bitPerfect: Boolean, doP: Boolean): Boolean {
        try {
            raf = RandomAccessFile(path, "r")
            if (!parseDsf(raf!!)) {
                emit(STATE_ERROR, 0, null, "不是有效的 DSF 文件")
                return false
            }
            pcmRate = dsdRate / 16
            val channelMask = if (channels >= 2)
                AudioFormat.CHANNEL_OUT_STEREO else AudioFormat.CHANNEL_OUT_MONO
            val minBuf = AudioTrack.getMinBufferSize(
                pcmRate,
                channelMask,
                AudioFormat.ENCODING_PCM_24BIT_PACKED
            )
            val bufferSize = maxOf(minBuf, READ_BLOCK * 3 * 4)
            track = AudioTrack(
                AudioManager.STREAM_MUSIC,
                pcmRate,
                channelMask,
                AudioFormat.ENCODING_PCM_24BIT_PACKED,
                bufferSize,
                AudioTrack.MODE_STREAM
            )
            playedBytes = 0
            emit(STATE_BUFFERING, 0, dsdModeText(bitPerfect, doP), null)
            return true
        } catch (e: Exception) {
            Log.e(TAG, "load failed", e)
            emit(STATE_ERROR, 0, null, e.message)
            return false
        }
    }

    fun play() {
        if (track == null) return
        if (thread?.isAlive == true) {
            // 已在线程中，仅恢复
            synchronized(lock) {
                paused = false
                lock.notifyAll()
            }
            track?.play()
            emit(STATE_PLAYING, currentMs(), dsdModeCached, null)
            return
        }
        running = true
        paused = false
        track?.play()
        thread = Thread { pump() }.also { it.start() }
    }

    fun pause() {
        paused = true
        track?.pause()
        emit(STATE_PAUSED, currentMs(), dsdModeCached, null)
    }

    fun stop() {
        running = false
        try { track?.stop() } catch (_: Exception) {}
        thread?.interrupt()
        thread = null
        try { raf?.close() } catch (_: Exception) {}
        raf = null
        track?.release()
        track = null
        emit(STATE_STOPPED, 0, dsdModeCached, null)
    }

    fun seek(ms: Int) {
        val targetBytes = (ms.toLong() * dsdRate / 8 * channels) / 1000
        val clamped = targetBytes.coerceIn(0, dataSize)
        raf?.seek(dataOffset + clamped)
        playedBytes = clamped
        emit(STATE_PLAYING, currentMs(), dsdModeCached, null)
    }

    fun setVolume(v: Float) {
        track?.setVolume(v.coerceIn(0f, 1f))
    }

    private var dsdModeCached: String? = null
    private fun dsdModeText(bitPerfect: Boolean, doP: Boolean): String {
        dsdModeCached = if (doP) "DSD${dsdRateLabel()} DoP" else "DSD${dsdRateLabel()} Native"
        return dsdModeCached!!
    }

    private fun dsdRateLabel(): String = when (dsdRate) {
        in 11289600..Int.MAX_VALUE -> "256"
        in 5644800..11289599 -> "128"
        else -> "64"
    }

    private fun currentMs(): Long =
        (playedBytes * 1000 / (dsdRate.toLong() / 8) / channels).coerceAtLeast(0)

    /** 后台读取 DSD -> DoP 编码 -> 写入 AudioTrack */
    private fun pump() {
        val raf = this.raf ?: return
        val track = this.track ?: return
        val dsdBuf = ByteArray(READ_BLOCK)
        val pcmBuf = ByteArray(READ_BLOCK * 3)
        var frameNo: Long = 0
        try {
            raf.seek(dataOffset + playedBytes)
            emit(STATE_PLAYING, currentMs(), dsdModeCached, null)
            while (running) {
                synchronized(lock) {
                    while (paused && running) lock.wait()
                }
                if (!running) break
                val n = raf.read(dsdBuf)
                if (n <= 0) {
                    // 播放完毕
                    emit(STATE_STOPPED, currentMs(), dsdModeCached, null)
                    running = false
                    break
                }
                val used = if (n % 2 == 0) n else n - 1 // 保持立体声成对
                val written = DopEncoder.encode(dsdBuf.copyOf(used), pcmBuf, frameNo)
                frameNo += used / 2
                track.write(pcmBuf, 0, written)
                playedBytes += used
            }
        } catch (e: InterruptedException) {
            // 被 stop 中断
        } catch (e: Exception) {
            Log.e(TAG, "pump error", e)
            emit(STATE_ERROR, currentMs(), dsdModeCached, e.message)
        }
    }

    /** 解析 DSF 头：定位采样率、声道数、数据区偏移 */
    private fun parseDsf(f: RandomAccessFile): Boolean {
        val header = ByteArray(4096)
        val read = f.read(header)
        if (read < 28) return false
        if (!(header[0] == 'D'.code.toByte() && header[1] == 'S'.code.toByte()
                    && header[2] == 'D'.code.toByte() && header[3] == ' '.code.toByte()))
            return false

        // 查找 "fmt " 与 "data" 块
        var fmtRate = -1
        var fmtCh = -1
        var dataOff = -1L
        var dataLen = -1L
        var i = 20
        while (i + 12 < read) {
            val id = String(header, i, 4, Charsets.US_ASCII)
            val size = le32(header, i + 4)
            when (id) {
                "fmt " -> {
                    fmtCh = le32(header, i + 20)
                    fmtRate = le32(header, i + 24)
                }
                "data" -> {
                    dataLen = le32(header, i + 4).toLong() and 0xFFFFFFFFL
                    dataOff = (i + 12).toLong()
                }
            }
            if (id == "data") break
            i += (size + 8).toInt()
        }
        if (fmtRate > 0) dsdRate = fmtRate
        if (fmtCh > 0) channels = fmtCh
        if (dataOff > 0) {
            dataOffset = dataOff
            val fileLen = f.length()
            dataSize = if (dataLen > 0) (dataLen - 12) else (fileLen - dataOffset)
            return true
        }
        return false
    }

    private fun le32(b: ByteArray, off: Int): Int =
        (b[off].toInt() and 0xFF) or
        ((b[off + 1].toInt() and 0xFF) shl 8) or
        ((b[off + 2].toInt() and 0xFF) shl 16) or
        ((b[off + 3].toInt() and 0xFF) shl 24)

    private fun emit(state: Int, positionMs: Long, dsdMode: String?, message: String?) {
        onState?.invoke(state, positionMs, dsdMode, message)
    }
}
