package id.goyana.preview.goyana_flutter

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationManager
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ClipboardManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.print.PrintAttributes
import android.print.PrintManager
import android.provider.ContactsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import android.util.Base64
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi
import java.io.File
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Native side of the GOYANA hybrid app. Ports the old Capacitor plugin
 * (native/GoyanaDevice.java) and adds what a bare WebView lacks.
 * Every call arrives from lib/hybrid/bridge.dart on channel id.goyana/device.
 */
class MainActivity : FlutterActivity() {
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private val permissionCalls = HashMap<Int, Pair<String, MethodChannel.Result>>()
    private var nextRequest = 100
    private var pickResult: MethodChannel.Result? = null
    private var printer: BluetoothSocket? = null
    private var printerName = ""
    private var printView: WebView? = null
    private val store by lazy { GoyanaStore(applicationContext) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "id.goyana/device")
            .setMethodCallHandler { call, result ->
                try {
                    handle(call, result)
                } catch (e: Exception) {
                    result.error("failed", e.message ?: "Perintah perangkat gagal", null)
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ReminderReceiver.ensureChannel(this)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "GoyanaDevice.requestAccess" -> requestAccess(call.argument<String>("alias") ?: "", result)
            "GoyanaDevice.permissions" -> result.success(
                ALIASES.associateWith { if (allowed(it)) "granted" else "prompt" })
            "GoyanaDevice.openSettings" -> {
                startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                result.success(null)
            }
            "GoyanaDevice.bluetoothSettings" -> {
                startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                result.success(null)
            }
            "GoyanaDevice.contacts" -> contacts(result)
            "GoyanaDevice.pairedPrinters" -> pairedPrinters(result)
            "GoyanaDevice.connectPrinter" -> connectPrinter(call.argument<String>("address") ?: "", result)
            "GoyanaDevice.testPrint" -> printBytes("GOYANA\nTes printer berhasil\n\n\n".toByteArray(Charsets.UTF_8), result)
            "GoyanaDevice.printText" -> printBytes(((call.argument<String>("text") ?: "") + "\n\n\n").toByteArray(Charsets.UTF_8), result)
            "GoyanaDevice.printerStatus" -> result.success(
                mapOf("connected" to (printer?.isConnected == true), "name" to printerName))
            "GoyanaDevice.disconnectPrinter" -> {
                closePrinter()
                result.success(null)
            }

            "Geolocation.checkPermissions" -> result.success(geoStatus())
            "Geolocation.requestPermissions" -> requestAccess("location", result, geoFormat = true)
            "Geolocation.getCurrentPosition" -> currentPosition(call, result)

            "LocalNotifications.checkPermissions" -> result.success(mapOf("display" to notifyStatus()))
            "LocalNotifications.requestPermissions" -> requestAccess("notifications", result, notifyFormat = true)
            "LocalNotifications.schedule" -> scheduleNotifications(call, result)
            "LocalNotifications.cancel" -> cancelNotifications(call, result)
            "LocalNotifications.getPending" -> result.success(mapOf("notifications" to
                ReminderReceiver.pending(this).map { mapOf("id" to it) }))

            "Files.save" -> saveFile(call, result)
            "Files.share" -> shareFiles(call, result)
            "Files.pick" -> pickFiles(call, result)
            "Files.read" -> readFile(call.argument<String>("uri") ?: "", result, call.argument<Int>("maxSide") ?: 0)

            "Clipboard.write" -> {
                val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                cm.setPrimaryClip(ClipData.newPlainText("GOYANA", call.argument<String>("text") ?: ""))
                result.success(null)
            }
            "Clipboard.read" -> {
                val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                val text = cm.primaryClip?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.coerceToText(this)?.toString() ?: ""
                result.success(mapOf("text" to text))
            }

            "Print.html" -> printHtml(call.argument<String>("html") ?: "", call.argument<String>("title") ?: "GOYANA", result)
            "App.openUrl" -> openUrl(call.argument<String>("url") ?: "", result)
            "Store.attach" -> attachStore(call, result)
            // Dart (logika murni Flutter) membaca & menulis database yang sama dengan aplikasi HTML.
            "Store.get" -> io.execute { val v = store.get(call.argument<String>("key") ?: ""); main.post { result.success(v) } }
            "Store.set" -> io.execute {
                val ok = store.set(call.argument<String>("key") ?: "", call.argument<String>("value") ?: "")
                main.post { result.success(ok) }
            }
            "Store.remove" -> io.execute { store.remove(call.argument<String>("key") ?: ""); main.post { result.success(true) } }
            else -> result.notImplemented()
        }
    }

    // ---------- permissions ----------
    private fun permissionsFor(alias: String): Array<String> = when (alias) {
        "camera" -> arrayOf(Manifest.permission.CAMERA)
        "contacts" -> arrayOf(Manifest.permission.READ_CONTACTS)
        "location" -> arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
        "bluetooth" -> if (Build.VERSION.SDK_INT >= 31)
            arrayOf(Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_SCAN) else emptyArray()
        "notifications" -> if (Build.VERSION.SDK_INT >= 33)
            arrayOf(Manifest.permission.POST_NOTIFICATIONS) else emptyArray()
        else -> emptyArray()
    }

    private fun granted(p: String) = checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

    private fun allowed(alias: String): Boolean {
        val list = permissionsFor(alias)
        if (alias == "location") return list.any { granted(it) }
        return list.all { granted(it) }
    }

    private fun geoStatus(): Map<String, String> {
        val s = if (allowed("location")) "granted" else "prompt"
        return mapOf("location" to s, "coarseLocation" to s)
    }

    private fun notifyStatus(): String {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return if (allowed("notifications") && nm.areNotificationsEnabled()) "granted" else "prompt"
    }

    private fun requestAccess(
        alias: String,
        result: MethodChannel.Result,
        geoFormat: Boolean = false,
        notifyFormat: Boolean = false,
    ) {
        if (alias !in ALIASES) {
            result.error("denied", "Izin tidak dikenal", null)
            return
        }
        val wrapped = object : MethodChannel.Result {
            override fun success(value: Any?) {
                when {
                    geoFormat -> result.success(geoStatus())
                    notifyFormat -> result.success(mapOf("display" to notifyStatus()))
                    else -> result.success(mapOf("granted" to allowed(alias)))
                }
            }
            override fun error(code: String, message: String?, details: Any?) = result.error(code, message, details)
            override fun notImplemented() = result.notImplemented()
        }
        if (allowed(alias)) {
            wrapped.success(null)
            return
        }
        val code = nextRequest++
        permissionCalls[code] = alias to wrapped
        requestPermissions(permissionsFor(alias), code)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        permissionCalls.remove(requestCode)?.second?.success(null)
    }

    // ---------- contacts ----------
    private fun contacts(result: MethodChannel.Result) {
        if (!allowed("contacts")) {
            result.error("denied", "Izin kontak diperlukan", null)
            return
        }
        io.execute {
            try {
                val list = ArrayList<Map<String, String>>()
                contentResolver.query(
                    ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                    arrayOf(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME, ContactsContract.CommonDataKinds.Phone.NUMBER),
                    null, null,
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC",
                )?.use { c ->
                    while (c.moveToNext()) list.add(mapOf("name" to (c.getString(0) ?: ""), "phone" to (c.getString(1) ?: "")))
                }
                main.post { result.success(mapOf("contacts" to list)) }
            } catch (e: Exception) {
                main.post { result.error("failed", "Kontak tidak dapat dibaca", null) }
            }
        }
    }

    // ---------- bluetooth printer ----------
    private fun adapter(): BluetoothAdapter? =
        (getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    @SuppressLint("MissingPermission")
    private fun pairedPrinters(result: MethodChannel.Result) {
        if (!allowed("bluetooth")) {
            result.error("denied", "Izin perangkat sekitar diperlukan", null)
            return
        }
        val a = adapter()
        if (a == null || !a.isEnabled) {
            result.error("off", "Aktifkan Bluetooth HP", null)
            return
        }
        val list = a.bondedDevices.map {
            mapOf("name" to (it.name ?: "Perangkat Bluetooth"), "address" to it.address)
        }
        result.success(mapOf("devices" to list))
    }

    @SuppressLint("MissingPermission")
    private fun connectPrinter(address: String, result: MethodChannel.Result) {
        if (!allowed("bluetooth")) {
            result.error("denied", "Izin perangkat sekitar diperlukan", null)
            return
        }
        io.execute {
            var candidate: BluetoothSocket? = null
            try {
                closePrinter()
                val a = adapter() ?: throw IllegalStateException("Bluetooth tidak tersedia")
                val device = a.getRemoteDevice(address)
                a.cancelDiscovery()
                candidate = device.createRfcommSocketToServiceRecord(SPP)
                candidate.connect()
                printer = candidate
                printerName = device.name ?: "Printer"
                main.post { result.success(mapOf("name" to printerName)) }
            } catch (e: Exception) {
                try { candidate?.close() } catch (_: Exception) {}
                main.post {
                    result.error("failed", "Gagal menghubungkan printer. Pastikan printer aktif dan sudah dipasangkan di Bluetooth HP.", null)
                }
            }
        }
    }

    private fun printBytes(text: ByteArray, result: MethodChannel.Result) {
        io.execute {
            try {
                val socket = printer
                if (socket == null || !socket.isConnected) {
                    main.post { result.error("offline", "Hubungkan printer terlebih dahulu", null) }
                    return@execute
                }
                socket.outputStream.write(byteArrayOf(27, 64))
                socket.outputStream.write(text)
                socket.outputStream.flush()
                main.post { result.success(null) }
            } catch (e: Exception) {
                main.post { result.error("failed", "Gagal mengirim ke printer", null) }
            }
        }
    }

    private fun closePrinter() {
        try { printer?.close() } catch (_: Exception) {}
        printer = null
    }

    // ---------- location ----------
    @SuppressLint("MissingPermission")
    private fun currentPosition(call: MethodCall, result: MethodChannel.Result) {
        if (!allowed("location")) {
            // Ask once, then continue; before this fix "Lokasi saya" failed silently on a fresh install.
            val code = nextRequest++
            permissionCalls[code] = "location" to object : MethodChannel.Result {
                override fun success(value: Any?) {
                    if (allowed("location")) currentPosition(call, result)
                    else result.error("denied", "Izin lokasi ditolak. Buka Pengaturan HP > Aplikasi > GOYANA > Izin > Lokasi.", null)
                }
                override fun error(code: String, message: String?, details: Any?) = result.error(code, message, details)
                override fun notImplemented() = result.notImplemented()
            }
            requestPermissions(permissionsFor("location"), code)
            return
        }
        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
            .filter { runCatching { lm.isProviderEnabled(it) }.getOrDefault(false) }
        if (providers.isEmpty()) {
            result.error("off", "Aktifkan GPS / lokasi HP", null)
            return
        }
        val timeout = (call.argument<Number>("timeout"))?.toLong() ?: 10000L
        var done = false
        val listeners = ArrayList<LocationListener>()
        fun finish(loc: Location?) {
            if (done) return
            done = true
            listeners.forEach { runCatching { lm.removeUpdates(it) } }
            if (loc == null) {
                result.error("timeout", "Lokasi tidak didapat. Aktifkan GPS dan coba lagi.", null)
            } else {
                result.success(mapOf(
                    "timestamp" to loc.time,
                    "coords" to mapOf(
                        "latitude" to loc.latitude,
                        "longitude" to loc.longitude,
                        "accuracy" to loc.accuracy.toDouble(),
                        "altitude" to (if (loc.hasAltitude()) loc.altitude else null),
                        "speed" to (if (loc.hasSpeed()) loc.speed.toDouble() else null),
                        "heading" to (if (loc.hasBearing()) loc.bearing.toDouble() else null),
                    ),
                ))
            }
        }
        main.postDelayed({
            val last = providers.mapNotNull { runCatching { lm.getLastKnownLocation(it) }.getOrNull() }
                .maxByOrNull { it.time }
            finish(last)
        }, timeout)
        for (p in providers) {
            if (Build.VERSION.SDK_INT >= 30) {
                lm.getCurrentLocation(p, null, mainExecutor) { loc -> if (loc != null) finish(loc) }
            } else {
                val l = LocationListener { loc -> finish(loc) }
                listeners.add(l)
                @Suppress("DEPRECATION")
                lm.requestSingleUpdate(p, l, Looper.getMainLooper())
            }
        }
    }

    // ---------- reminders ----------
    private fun parseTime(value: Any?): Long? = when (value) {
        is Number -> value.toLong()
        is String -> runCatching {
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSX", Locale.US).parse(value)?.time
        }.getOrNull() ?: runCatching {
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssX", Locale.US).parse(value)?.time
        }.getOrNull()
        else -> null
    }

    private fun scheduleNotifications(call: MethodCall, result: MethodChannel.Result) {
        val list = call.argument<List<Map<String, Any?>>>("notifications") ?: emptyList()
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val ids = ArrayList<Map<String, Int>>()
        for (n in list) {
            val id = (n["id"] as? Number)?.toInt() ?: continue
            val at = parseTime((n["schedule"] as? Map<*, *>)?.get("at")) ?: System.currentTimeMillis()
            val pi = ReminderReceiver.intent(this, id, n["title"]?.toString() ?: "GOYANA", n["body"]?.toString() ?: "")
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            ReminderReceiver.remember(this, id, true)
            ids.add(mapOf("id" to id))
        }
        result.success(mapOf("notifications" to ids))
    }

    private fun cancelNotifications(call: MethodCall, result: MethodChannel.Result) {
        val list = call.argument<List<Map<String, Any?>>>("notifications") ?: emptyList()
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        for (n in list) {
            val id = (n["id"] as? Number)?.toInt() ?: continue
            am.cancel(ReminderReceiver.intent(this, id, "", ""))
            nm.cancel(id)
            ReminderReceiver.remember(this, id, false)
        }
        result.success(null)
    }

    // ---------- files ----------
    private fun safeName(name: String) = name.replace(Regex("[\\\\/:*?\"<>|]"), "_").ifBlank { "goyana-file" }

    private fun saveFile(call: MethodCall, result: MethodChannel.Result) {
        val name = safeName(call.argument<String>("name") ?: "goyana-file")
        val mime = call.argument<String>("mime") ?: "application/octet-stream"
        val bytes = Base64.decode(call.argument<String>("data") ?: "", Base64.DEFAULT)
        io.execute {
            try {
                val where: String
                if (Build.VERSION.SDK_INT >= 29) {
                    val values = ContentValues().apply {
                        put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                        put(MediaStore.MediaColumns.MIME_TYPE, mime)
                        put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/GOYANA")
                    }
                    val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                        ?: throw IllegalStateException("Penyimpanan tidak tersedia")
                    contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                    where = "Download/GOYANA"
                } else {
                    val dir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: filesDir
                    File(dir, name).writeBytes(bytes)
                    where = dir.absolutePath
                }
                main.post {
                    Toast.makeText(this, "Tersimpan di $where/$name", Toast.LENGTH_LONG).show()
                    result.success(mapOf("path" to "$where/$name"))
                }
            } catch (e: Exception) {
                main.post { result.error("failed", "File gagal disimpan", null) }
            }
        }
    }

    private fun shareFiles(call: MethodCall, result: MethodChannel.Result) {
        val files = call.argument<List<Map<String, Any?>>>("files") ?: emptyList()
        val text = listOfNotNull(
            call.argument<String>("text")?.takeIf { it.isNotBlank() },
            call.argument<String>("url")?.takeIf { it.isNotBlank() },
        ).joinToString("\n")
        val title = call.argument<String>("title")?.takeIf { it.isNotBlank() } ?: "Bagikan"
        io.execute {
            try {
                val dir = File(cacheDir, "share").apply { mkdirs() }
                val uris = ArrayList<Uri>()
                var mime = "text/plain"
                for (f in files) {
                    val file = File(dir, safeName(f["name"]?.toString() ?: "goyana-file"))
                    file.writeBytes(Base64.decode(f["data"]?.toString() ?: "", Base64.DEFAULT))
                    uris.add(FileProvider.getUriForFile(this, "$packageName.files", file))
                    mime = f["mime"]?.toString() ?: "*/*"
                }
                val intent = when {
                    uris.size > 1 -> Intent(Intent.ACTION_SEND_MULTIPLE).putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris).setType("*/*")
                    uris.size == 1 -> Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_STREAM, uris[0]).setType(mime)
                    else -> Intent(Intent.ACTION_SEND).setType("text/plain")
                }
                if (text.isNotEmpty()) intent.putExtra(Intent.EXTRA_TEXT, text)
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                // Opsional (Mode Murni): "whatsapp" = nomor tujuan (62…) → langsung ke chat WhatsApp pelanggan.
                // Bila WhatsApp tidak terpasang / menolak, jatuh ke menu bagikan biasa.
                val wa = call.argument<String>("whatsapp")?.filter { it.isDigit() } ?: ""
                main.post {
                    var sent = false
                    if (wa.isNotEmpty()) {
                        for (pkg in listOf("com.whatsapp", "com.whatsapp.w4b")) {
                            if (sent) break
                            try {
                                startActivity(Intent(intent).setPackage(pkg).putExtra("jid", "$wa@s.whatsapp.net"))
                                sent = true
                            } catch (e: Exception) {
                            }
                        }
                    }
                    if (!sent) startActivity(Intent.createChooser(intent, title))
                    result.success(mapOf("direct" to sent))
                }
            } catch (e: Exception) {
                main.post { result.error("failed", "Gagal membagikan", null) }
            }
        }
    }

    private var captureFile: File? = null

    private fun pickFiles(call: MethodCall, result: MethodChannel.Result) {
        pickResult?.success(emptyList<String>())
        val accept = (call.argument<List<String>>("accept") ?: emptyList())
            .flatMap { it.split(",") }.map { it.trim().lowercase(Locale.US) }.filter { it.isNotEmpty() }
            .map { EXTENSIONS[it] ?: it }.distinct()
        val intent = Intent(Intent.ACTION_GET_CONTENT).addCategory(Intent.CATEGORY_OPENABLE)
        when {
            accept.isEmpty() -> intent.type = "*/*"
            accept.size == 1 -> intent.type = accept[0]
            else -> {
                intent.type = "*/*"
                intent.putExtra(Intent.EXTRA_MIME_TYPES, accept.toTypedArray())
            }
        }
        intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, call.argument<Boolean>("multiple") == true)
        pickResult = result
        val chooser = Intent.createChooser(intent, "Pilih file")
        // Foto cucian: kamera ikut ditawarkan di pemilih (izin kamera diminta aplikasi lebih dulu).
        captureFile = null
        if (call.argument<Boolean>("capture") == true && allowed("camera")) {
            try {
                val dir = File(cacheDir, "share").apply { mkdirs() }
                val f = File(dir, "foto-${System.currentTimeMillis()}.jpg")
                val out = FileProvider.getUriForFile(this, "$packageName.files", f)
                val cam = Intent(MediaStore.ACTION_IMAGE_CAPTURE).putExtra(MediaStore.EXTRA_OUTPUT, out)
                    .addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
                cam.clipData = ClipData.newRawUri("", out)
                chooser.putExtra(Intent.EXTRA_INITIAL_INTENTS, arrayOf(cam))
                captureFile = f
            } catch (e: Exception) {
                captureFile = null
            }
        }
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(chooser, REQ_PICK)
        } catch (e: ActivityNotFoundException) {
            pickResult = null
            result.success(emptyList<String>())
        }
    }

    /** Reads a picked file (content URI) for the native pages' upload buttons; max 8 MB. */
    private fun readFile(uri: String, result: MethodChannel.Result, maxSide: Int = 0) {
        io.execute {
            try {
                val u = Uri.parse(uri)
                var name = "upload"
                contentResolver.query(u, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c -> if (c.moveToFirst()) name = c.getString(0) ?: name }
                val bytes = contentResolver.openInputStream(u)?.use { it.readBytes() } ?: ByteArray(0)
                // Foto cucian: diperkecil (sisi terpanjang maxSide, JPEG) dan diputar sesuai EXIF, supaya ringan disimpan & disinkronkan.
                if (maxSide > 0) {
                    val small = shrinkImage(bytes, maxSide)
                    if (small != null) {
                        val data = Base64.encodeToString(small, Base64.NO_WRAP)
                        main.post { result.success(mapOf("name" to name, "mime" to "image/jpeg", "data" to data)) }
                        return@execute
                    }
                }
                if (bytes.size > 8 * 1024 * 1024) {
                    main.post { result.error("large", "File terlalu besar", null) }
                    return@execute
                }
                val mime = contentResolver.getType(u) ?: "application/octet-stream"
                val data = Base64.encodeToString(bytes, Base64.NO_WRAP)
                main.post { result.success(mapOf("name" to name, "mime" to mime, "data" to data)) }
            } catch (e: Exception) {
                main.post { result.error("failed", "File tidak dapat dibaca", null) }
            }
        }
    }

    private fun shrinkImage(bytes: ByteArray, maxSide: Int): ByteArray? {
        val bounds = android.graphics.BitmapFactory.Options().apply { inJustDecodeBounds = true }
        android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxSide) sample *= 2
        val opts = android.graphics.BitmapFactory.Options().apply { inSampleSize = sample }
        var bmp = android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts) ?: return null
        val longest = maxOf(bmp.width, bmp.height)
        if (longest > maxSide) {
            val f = maxSide.toFloat() / longest
            bmp = android.graphics.Bitmap.createScaledBitmap(bmp, (bmp.width * f).toInt().coerceAtLeast(1), (bmp.height * f).toInt().coerceAtLeast(1), true)
        }
        val turn = if (Build.VERSION.SDK_INT < 24) 0f else try {
            when (android.media.ExifInterface(java.io.ByteArrayInputStream(bytes)).getAttributeInt(android.media.ExifInterface.TAG_ORIENTATION, 1)) {
                6 -> 90f
                3 -> 180f
                8 -> 270f
                else -> 0f
            }
        } catch (e: Exception) { 0f }
        if (turn != 0f) {
            val m = android.graphics.Matrix().apply { postRotate(turn) }
            bmp = android.graphics.Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, m, true)
        }
        val out = java.io.ByteArrayOutputStream()
        bmp.compress(android.graphics.Bitmap.CompressFormat.JPEG, 70, out)
        return out.toByteArray()
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_PICK) return
        val result = pickResult ?: return
        pickResult = null
        val uris = ArrayList<String>()
        if (resultCode == Activity.RESULT_OK && data != null) {
            val clip = data.clipData
            if (clip != null) for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri.toString())
            else data.data?.let { uris.add(it.toString()) }
        }
        val shot = captureFile
        captureFile = null
        if (resultCode == Activity.RESULT_OK && uris.isEmpty() && shot != null && shot.length() > 0) {
            uris.add(FileProvider.getUriForFile(this, "$packageName.files", shot).toString())
        }
        result.success(uris)
    }

    // ---------- printing ----------
    private fun printHtml(html: String, title: String, result: MethodChannel.Result) {
        val view = WebView(this)
        printView = view
        view.webViewClient = object : WebViewClient() {
            override fun onPageFinished(v: WebView, url: String?) {
                val pm = getSystemService(Context.PRINT_SERVICE) as PrintManager
                pm.print(title, v.createPrintDocumentAdapter(title), PrintAttributes.Builder().build())
            }
        }
        view.loadDataWithBaseURL("file:///android_asset/flutter_assets/assets/web/", html, "text/html", "utf-8", null)
        result.success(null)
    }

    // ---------- SQLite storage for the web app ----------
    /** Exposes [GoyanaStore] to the app WebView as window.GoyanaStore (must run before the page loads). */
    @Suppress("DEPRECATION")
    private fun attachStore(call: MethodCall, result: MethodChannel.Result) {
        val id = (call.argument<Number>("id"))?.toLong()
        val engine = flutterEngine
        val view = if (id != null && engine != null) WebViewFlutterAndroidExternalApi.getWebView(engine, id) else null
        if (view == null) {
            result.success(false)
            return
        }
        view.addJavascriptInterface(store, "GoyanaStore")
        result.success(true)
    }

    // ---------- external links ----------
    private fun openUrl(url: String, result: MethodChannel.Result) {
        try {
            val intent = if (url.startsWith("intent:")) Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
            else Intent(Intent.ACTION_VIEW, Uri.parse(url))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success(null)
        } catch (e: Exception) {
            Toast.makeText(this, "Tidak ada aplikasi untuk membuka tautan ini", Toast.LENGTH_SHORT).show()
            result.error("failed", "Tidak ada aplikasi untuk membuka tautan ini", null)
        }
    }

    override fun onDestroy() {
        closePrinter()
        printView = null
        io.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val REQ_PICK = 7301
        private val ALIASES = listOf("camera", "contacts", "bluetooth", "location", "notifications")
        private val SPP: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
        private val EXTENSIONS = mapOf(
            ".png" to "image/png", ".jpg" to "image/jpeg", ".jpeg" to "image/jpeg", ".webp" to "image/webp",
            ".gif" to "image/gif", ".pdf" to "application/pdf", ".csv" to "text/csv", ".txt" to "text/plain",
            ".json" to "application/json", ".xlsx" to "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
    }
}
