package com.denissamp.launcher.data.manifest

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ManifestFile(
    val url: String,
    val dest: String,
    val sha256: String,
    val size: Long,
    val type: FileType = FileType.RAW,
    val unpackTo: String? = null
) {
    val isZip: Boolean get() = type == FileType.ZIP

    @Serializable
    enum class FileType {
        @SerialName("raw") RAW,
        @SerialName("zip") ZIP
    }
}

@Serializable
data class ManifestPayload(
    val version: String,
    val minClient: String? = null,
    val files: List<ManifestFile>
)

@Serializable
data class InstalledIndex(
    val version: String,
    val files: Map<String, String>
)
