package com.audiophile.dsd_player.audio

/**
 * DSD over PCM (DoP v1.1) 封装器。
 *
 * 把原始 DSD 字节流转换为 24bit 小端 PCM 帧：
 *  - 每个 DSD 字节（含 8 个 DSD 样本）占用一个 24bit PCM 样本的低 16bit
 *  - 高 8bit 写入 DoP 标记：偶帧 0xFA / 奇帧 0xF5
 *  - 立体声 DSF：左右声道逐字节交错（L0,R0,L1,R1,...）
 *
 * 输出 PCM 采样率 = DSD 倍速 / 16（DSD64 -> 176400Hz，DSD128 -> 352800Hz）。
 */
object DopEncoder {
    private const val MARKER_EVEN = 0xFA
    private const val MARKER_ODD = 0xF5

    /**
     * @param dsd        原始 DSD 数据
     * @param pcm        输出缓冲（24bit 小端，长度应 >= dsd.size * 3）
     * @param startFrame 起始帧序号（用于标记奇偶交替）
     * @return 写入 pcm 的字节数
     */
    fun encode(dsd: ByteArray, pcm: ByteArray, startFrame: Long): Int {
        var p = 0
        var frame = startFrame
        var i = 0
        while (i + 1 < dsd.size && p + 5 < pcm.size) {
            val marker = if (frame % 2 == 0L) MARKER_EVEN else MARKER_ODD
            // 左声道
            val left = dsd[i].toInt() and 0xFF
            pcm[p++] = (left and 0xFF).toByte()
            pcm[p++] = 0
            pcm[p++] = marker.toByte()
            // 右声道
            val right = dsd[i + 1].toInt() and 0xFF
            pcm[p++] = (right and 0xFF).toByte()
            pcm[p++] = 0
            pcm[p++] = marker.toByte()
            i += 2
            frame++
        }
        return p
    }
}
