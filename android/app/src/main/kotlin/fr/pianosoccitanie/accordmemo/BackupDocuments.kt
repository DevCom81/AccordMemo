package fr.pianosoccitanie.accordmemo

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/** SAF reste ici : Dart ne reçoit que des fichiers privés et des identifiants opaques. */
class BackupDocuments(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "accordmemo/backup_documents")
    private val executor = Executors.newSingleThreadExecutor()
    private val root = File(activity.cacheDir, "backup_documents")
    private data class Selection(
        val directory: File,
        val uri: Uri,
        val export: Boolean,
        var committed: Boolean = false,
    ) {
        val file: File get() = File(directory, "backup.db")
    }
    private val selections = mutableMapOf<String, Selection>()
    private var pending: MethodChannel.Result? = null
    private var exporting = false

    init {
        // Nettoie les copies privées abandonnées par une mort du processus.
        executor.execute {
            try {
                root.deleteRecursively()
                root.mkdirs()
            } catch (_: Exception) {
                // Une erreur de stockage sera signalée lors de la sélection.
            }
        }
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "create", "open" -> {
                    if (pending != null) {
                        result.error("busy", "Sélection déjà en cours", null)
                    } else {
                        exporting = call.method == "create"
                        val intent = Intent(if (exporting) Intent.ACTION_CREATE_DOCUMENT
                            else Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = if (exporting) "application/octet-stream" else "*/*"
                            if (exporting) {
                                val name = call.argument<String>("name") ?: "AccordMemo_backup.db"
                                putExtra(Intent.EXTRA_TITLE, File(name).name)
                            }
                        }
                        pending = result
                        try {
                            activity.startActivityForResult(intent, REQUEST_CODE)
                        } catch (_: Exception) {
                            pending = null
                            result.error("picker_failed", "Sélecteur indisponible", null)
                        }
                    }
                }
                "commit", "dispose" -> {
                    val id = call.argument<String>("id") ?: ""
                    val selection = selections[id]
                    if (selection == null) {
                        result.error("selection_missing", "Sélection indisponible", null)
                    } else if (call.method == "dispose") {
                        selections.remove(id)
                        executor.execute {
                            cleanup(selection)
                            activity.runOnUiThread { result.success(null) }
                        }
                    } else {
                        executor.execute {
                            try {
                                check(selection.export && !selection.committed)
                                activity.contentResolver.openOutputStream(selection.uri, "w")
                                    .use { output ->
                                        checkNotNull(output)
                                        selection.file.inputStream().use { it.copyTo(output) }
                                        output.flush()
                                    }
                                activity.runOnUiThread {
                                    selection.committed = true
                                    result.success(null)
                                }
                            } catch (_: Exception) {
                                activity.runOnUiThread {
                                    result.error("write_failed", "Copie impossible", null)
                                }
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pending ?: return true
        pending = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return true
        }
        val uri = data?.data
        if (uri == null) {
            result.error("selection_missing", "Document indisponible", null)
            return true
        }
        val id = UUID.randomUUID().toString()
        val selection = Selection(File(root, id), uri, exporting)
        executor.execute {
            try {
                check(selection.directory.mkdirs())
                if (!selection.export) {
                    activity.contentResolver.openInputStream(uri).use { input ->
                        checkNotNull(input)
                        selection.file.outputStream().use { input.copyTo(it) }
                    }
                }
                activity.runOnUiThread {
                    selections[id] = selection
                    result.success(mapOf("id" to id, "path" to selection.file.path))
                }
            } catch (_: Exception) {
                cleanup(selection)
                activity.runOnUiThread {
                    result.error("read_failed", "Document illisible", null)
                }
            }
        }
        return true
    }

    private fun cleanup(selection: Selection) {
        if (selection.export && !selection.committed) {
            try {
                // CREATE_DOCUMENT crée un nouveau document, jamais un fichier existant.
                DocumentsContract.deleteDocument(activity.contentResolver, selection.uri)
            } catch (_: Exception) {
                // Certains fournisseurs refusent la suppression du document incomplet.
            }
        }
        try {
            selection.directory.deleteRecursively()
        } catch (_: Exception) {
            // Un résidu privé sera nettoyé au prochain démarrage.
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        pending?.error("activity_closed", "Sélection interrompue", null)
        pending = null
        executor.shutdown()
    }

    companion object {
        private const val REQUEST_CODE = 16501
    }
}
