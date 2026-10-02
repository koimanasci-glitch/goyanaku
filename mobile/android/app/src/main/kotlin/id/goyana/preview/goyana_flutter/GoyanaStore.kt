package id.goyana.preview.goyana_flutter

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.webkit.JavascriptInterface
import org.json.JSONObject

/**
 * SQLite key-value store exposed to the web app as window.GoyanaStore.
 * Replaces the WebView's ~5 MB localStorage (see web_bridge/goyana-store.js).
 *
 * Values are split into 256 KB parts because Android cannot read a single
 * row larger than ~2 MB (CursorWindow), while the orders snapshot can grow past that.
 * Calls are synchronous on the WebView's JavaBridge thread; SQLite runs in WAL mode.
 */
class GoyanaStore(context: Context) : SQLiteOpenHelper(context, "goyana.db", null, 1) {
    private val part = 256 * 1024

    override fun onConfigure(db: SQLiteDatabase) {
        db.enableWriteAheadLogging()
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE kv (k TEXT NOT NULL, part INTEGER NOT NULL, v TEXT NOT NULL, updated_at INTEGER NOT NULL, PRIMARY KEY (k, part))")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {}

    @JavascriptInterface
    @Synchronized
    fun all(): String {
        val out = LinkedHashMap<String, StringBuilder>()
        readableDatabase.rawQuery("SELECT k, v FROM kv ORDER BY k, part", null).use { c ->
            while (c.moveToNext()) out.getOrPut(c.getString(0)) { StringBuilder() }.append(c.getString(1))
        }
        val json = JSONObject()
        out.forEach { (k, v) -> json.put(k, v.toString()) }
        return json.toString()
    }

    @JavascriptInterface
    @Synchronized
    fun get(key: String): String? {
        val sb = StringBuilder()
        var found = false
        readableDatabase.rawQuery("SELECT v FROM kv WHERE k = ? ORDER BY part", arrayOf(key)).use { c ->
            while (c.moveToNext()) { sb.append(c.getString(0)); found = true }
        }
        return if (found) sb.toString() else null
    }

    private fun write(db: SQLiteDatabase, key: String, value: String) {
        db.delete("kv", "k = ?", arrayOf(key))
        val now = System.currentTimeMillis()
        var i = 0
        var index = 0
        do {
            val end = minOf(value.length, i + part)
            db.insert("kv", null, ContentValues().apply {
                put("k", key); put("part", index); put("v", value.substring(i, end)); put("updated_at", now)
            })
            i = end; index++
        } while (i < value.length)
    }

    /** Returns false when the phone storage is full, so the app can warn the user. */
    @JavascriptInterface
    @Synchronized
    fun set(key: String, value: String): Boolean {
        val db = writableDatabase
        return try {
            db.beginTransaction()
            try { write(db, key, value); db.setTransactionSuccessful() } finally { db.endTransaction() }
            true
        } catch (e: Exception) {
            false
        }
    }

    @JavascriptInterface
    @Synchronized
    fun setMany(json: String): Boolean {
        val db = writableDatabase
        return try {
            val obj = JSONObject(json)
            db.beginTransaction()
            try {
                val keys = obj.keys()
                while (keys.hasNext()) { val k = keys.next(); write(db, k, obj.getString(k)) }
                db.setTransactionSuccessful()
            } finally {
                db.endTransaction()
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    @JavascriptInterface
    @Synchronized
    fun remove(key: String) {
        writableDatabase.delete("kv", "k = ?", arrayOf(key))
    }

    @JavascriptInterface
    @Synchronized
    fun sizeBytes(): Long =
        readableDatabase.rawQuery("SELECT COALESCE(SUM(LENGTH(v)), 0) FROM kv", null).use { c ->
            if (c.moveToFirst()) c.getLong(0) else 0L
        }
}
